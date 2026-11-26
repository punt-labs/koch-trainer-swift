import argparse
from collections import Counter
import json
import os
from pathlib import Path
import select
import subprocess
import tempfile
import time

from replay import HERE, finish_watch, git_path, key, read_watcher_line, through_cutoff, verdict
from vnode_guard import VnodeGuard


def mutation(kind, root, git_dir, scratch):
    if kind == "transient":
        parent = root / "KochTrainer"
        path = parent / "LiveVerifiedTransientProbe.txt"
        with path.open("xb") as file:
            file.write(b"transient nonignored file\n")
        path.unlink()
        return parent, select.KQ_NOTE_WRITE
    if kind == "keyed":
        path = root / "README.md"
        with path.open("r+b", buffering=0) as file:
            file.seek(0, os.SEEK_END)
            size = file.tell()
            try:
                file.write(b"transient keyed write\n")
            finally:
                file.truncate(size)
        return path, select.KQ_NOTE_WRITE

    path = git_dir / kind
    original, replacement = scratch / "original", scratch / "replacement"
    replacement.write_bytes(path.read_bytes())
    path.rename(original)
    try:
        replacement.replace(path)
    finally:
        original.replace(path)
    return path, select.KQ_NOTE_RENAME


def trial(root, git_dir, scratch, kind):
    with VnodeGuard(root, git_dir) as guard, tempfile.TemporaryFile(mode="w+t", dir=HERE) as raw:
        guard.arm()
        before = key(root)
        guard.check_opening_paths(before["paths"])
        since = subprocess.check_output([HERE / "watch", "id"], text=True).strip()
        with subprocess.Popen(
            [HERE / "watch", "run", since, root, git_dir],
            stdin=subprocess.PIPE, stdout=raw, stderr=subprocess.PIPE, text=True
        ) as watcher:
            try:
                assert read_watcher_line(watcher) == "READY"
                after = key(root)
                assert before == after, "fixture changed before the closing key"
                path, note = mutation(kind, root, git_dir, scratch)
                cutoff = finish_watch(watcher)
                vnode_events = guard.events()
            finally:
                if watcher.poll() is None:
                    watcher.kill()
        raw.seek(0)
        events = through_cutoff([json.loads(line) for line in raw], cutoff)
    paths = {root / name for name in after["paths"]}
    fsevents_only, relevant = verdict(events, True, 0, paths, git_dir)
    guarded, _ = verdict(events, True, 0, paths, git_dir, vnode_events)
    assert guarded and any(event["path"] == str(path) and event["notes"] & note
                           for event in vnode_events), (kind, vnode_events)
    return {"kind": kind, "cutoff": cutoff, "fsevents_only_deferred": fsevents_only,
            "guarded_deferred": guarded, "relevant_fsevents": relevant,
            "vnode_events": vnode_events, "vnode_fds": len(guard.descriptors)}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("receipt", type=Path)
    parser.add_argument("--trials", type=int, default=20)
    args = parser.parse_args()
    root = args.root.resolve()
    git_dir = git_path(root, "--git-dir")
    assert git_dir != root / ".git", "use a disposable linked worktree"
    assert not subprocess.check_output(["git", "--no-optional-locks", "status", "--porcelain"], cwd=root)
    baseline = key(root)
    start = time.monotonic()
    with tempfile.TemporaryDirectory(dir=HERE, prefix="vnode-race-") as scratch:
        for kind in ["keyed", "HEAD", "index", "transient"]:
            start_kind = time.monotonic()
            count = args.trials if kind != "transient" else 1
            with args.receipt.open("a") as receipt:
                rows = []
                for _ in range(count):
                    row = trial(root, git_dir, Path(scratch), kind)
                    rows.append(row)
                    print(json.dumps(row), file=receipt, flush=True)
            assert key(root) == baseline, f"{kind} failed to restore the fixture"
            hits = Counter(row["fsevents_only_deferred"] for row in rows)
            print(f"{kind}: FSEvents only deferred {hits[True]}/{count}; "
                  f"vnode guarded {sum(row['guarded_deferred'] for row in rows)}/{count}; "
                  f"{rows[0]['vnode_fds']} vnode FDs; {time.monotonic() - start_kind:.2f} s", flush=True)
    print(f"total: {time.monotonic() - start:.2f} s", flush=True)
