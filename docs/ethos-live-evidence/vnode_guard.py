import os
from pathlib import Path
import resource
import select
import subprocess


NOTES = (select.KQ_NOTE_WRITE | select.KQ_NOTE_EXTEND | select.KQ_NOTE_ATTRIB |
         select.KQ_NOTE_DELETE | select.KQ_NOTE_LINK | select.KQ_NOTE_RENAME | select.KQ_NOTE_REVOKE)
REPLACED = select.KQ_NOTE_DELETE | select.KQ_NOTE_RENAME | select.KQ_NOTE_REVOKE
NON_ACCESS_STAT = ("st_dev", "st_ino", "st_mode", "st_size", "st_mtime_ns", "st_ctime_ns",
                   "st_uid", "st_gid", "st_flags", "st_nlink")


def git_names(root, *args):
    output = subprocess.check_output(["git", "ls-files", "-z", *args], cwd=root)
    return {os.fsdecode(name) for name in output.split(b"\0") if name}


def walk_error(error):
    raise error


def watch_paths(root, git_dir):
    keyed = {root / name for name in git_names(root, "--cached", "--others", "--exclude-standard")
             if os.path.lexists(root / name) and not (root / name).is_dir()}
    excluded = {root / name for name in git_names(root, "--others", "--ignored", "--exclude-standard",
                                                  "--directory") if name.endswith("/")}
    parents = {parent for path in keyed for parent in path.parents if parent.is_relative_to(root)}
    paths = {path: NOTES for path in keyed}
    for directory, children, _ in os.walk(root, onerror=walk_error):
        parent = Path(directory)
        paths[parent] = NOTES
        children[:] = sorted(child for child in children if parent / child != root / ".git"
                             and (parent / child not in excluded or parent / child in parents))
    # Do not treat ordinary writes by other worktrees or Git lock/temp names
    # as keyed. Watch the directory itself only for loss or replacement.
    paths.update({git_dir: REPLACED, git_dir / "HEAD": NOTES, git_dir / "index": NOTES})
    if root != git_dir and (root / ".git").is_file():
        paths[root / ".git"] = NOTES
    return keyed, paths


class VnodeGuard:
    def __init__(self, root, git_dir):
        self.root = root
        self.git_dir = git_dir
        self.queue = select.kqueue()
        self.descriptors = {}
        self.open_state = {}
        self.access_events = []
        self.soft_limit, self.hard_limit = resource.getrlimit(resource.RLIMIT_NOFILE)

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.queue.close()
        for fd in self.descriptors:
            os.close(fd)

    def arm(self):
        self.keyed, paths = watch_paths(self.root, self.git_dir)
        changes = []
        for path, notes in sorted(paths.items()):
            fd = os.open(path, os.O_EVTONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
            self.descriptors[fd] = path
            changes.append(select.kevent(fd, filter=select.KQ_FILTER_VNODE,
                                         flags=select.KQ_EV_ADD | select.KQ_EV_CLEAR, fflags=notes))
        self.queue.control(changes, 0, 0)
        for fd, path in self.descriptors.items():
            current, watched = path.lstat(), os.fstat(fd)
            if (current.st_dev, current.st_ino) != (watched.st_dev, watched.st_ino):
                raise RuntimeError(f"vnode changed while arming: {path}")
            self.open_state[fd] = watched
        if watch_paths(self.root, self.git_dir) != (self.keyed, paths):
            raise RuntimeError("vnode inventory changed while arming")

    def check_opening_paths(self, paths):
        if {self.root / path for path in paths} != self.keyed:
            raise RuntimeError("opening key did not match the armed vnode inventory")

    def events(self):
        receipt = []
        while batch := self.queue.control(None, len(self.descriptors), 0):
            for event in batch:
                if event.flags & select.KQ_EV_ERROR or not event.fflags:
                    raise RuntimeError(f"incomplete vnode notification: {event}")
                fd = event.ident
                item = {"path": str(self.descriptors[fd]), "notes": event.fflags}
                if event.fflags == select.KQ_NOTE_ATTRIB:
                    before, after = self.open_state[fd], os.fstat(fd)
                    if before.st_atime_ns != after.st_atime_ns and all(
                        getattr(before, field) == getattr(after, field) for field in NON_ACCESS_STAT
                    ):
                        self.access_events.append({**item, "atime_before": before.st_atime_ns,
                                                   "atime_after": after.st_atime_ns})
                        continue
                receipt.append(item)
        return receipt
