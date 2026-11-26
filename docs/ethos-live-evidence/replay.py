import argparse
import json
import os
from pathlib import Path
import select
import signal
import subprocess
import sys
import tempfile
import threading
import time

from vnode_guard import VnodeGuard


HERE = Path(__file__).resolve().parent
AMBIGUOUS = 0x1 | 0x2 | 0x4 | 0x8 | 0x20 | 0x40 | 0x80
PROBE_FLAGS = {"MustScanSubDirs": 0x1, "UserDropped": 0x2, "KernelDropped": 0x4, "RootChanged": 0x20}
HISTORY_DONE = 0x10
IS_DIR = 0x20000
INTERRUPTED = {129, 130, 137, 143}


def key(root):
    output = subprocess.check_output(
        [HERE / "ethos-key"], cwd=root, text=True, env={**os.environ, "KOCH_KEY_ROOT": str(root)}
    )
    return json.loads(output)


def git_path(root, value):
    return Path(subprocess.check_output(
        ["git", "rev-parse", "--path-format=absolute", value], cwd=root, text=True
    ).strip()).resolve()


def relevant(paths, git_dir, event):
    flags = event["flags"]
    if flags & AMBIGUOUS:
        return True
    if flags & HISTORY_DONE:
        return False
    path = Path(event["path"])
    return (path in paths or path in {git_dir / "HEAD", git_dir / "index"}
            or (flags & IS_DIR and any(item.is_relative_to(path) for item in paths)))


def real_drop_attempt(root, watcher):
    with tempfile.TemporaryDirectory(prefix="fsevents-burst-", dir=root / "DerivedData") as directory:
        watcher.send_signal(signal.SIGSTOP)
        try:
            for i in range(16384):
                (Path(directory) / str(i)).touch()
        finally:
            watcher.send_signal(signal.SIGCONT)


def verdict(events, same_key, gate_exit, paths, git_dir, vnode_events=()):
    keyed = [event for event in events if relevant(paths, git_dir, event)]
    deferred = not same_key or bool(keyed) or bool(vnode_events) or gate_exit < 0 or gate_exit in INTERRUPTED
    return deferred, keyed


def read_watcher_line(watcher):
    if not select.select([watcher.stderr], [], [], 10)[0]:
        raise RuntimeError("FSEvents watcher did not respond")
    return watcher.stderr.readline().strip()


def finish_watch(watcher):
    watcher.stdin.write("CUTOFF\n")
    watcher.stdin.flush()
    cutoff = int(read_watcher_line(watcher))
    watcher.communicate("FLUSH\n", timeout=10)
    if watcher.returncode:
        raise RuntimeError("FSEvents did not flush cleanly")
    return cutoff


def through_cutoff(events, cutoff):
    return [event for event in events if event["flags"] & AMBIGUOUS or event["id"] <= cutoff]


def run(root, name, touch, probe_drops, gate_write):
    started = time.monotonic()
    git_dir = git_path(root, "--git-dir")
    command = [sys.executable, HERE / "gate_write.py"] if gate_write else ["make", "check"]

    with VnodeGuard(root, git_dir) as guard, \
         (HERE / f"{name}.events.jsonl").open("w") as events, \
         (HERE / f"{name}.gate.log").open("w") as gate_output:
        guard.arm()
        before = key(root)
        guard.check_opening_paths(before["paths"])
        since = subprocess.check_output([HERE / "watch", "id"], text=True).strip()
        watcher = subprocess.Popen(
            [HERE / "watch", "run", since, *sorted({root, git_dir})],
            stdin=subprocess.PIPE, stdout=events, stderr=subprocess.PIPE, text=True
        )
        timer = None
        try:
            if read_watcher_line(watcher) != "READY":
                raise RuntimeError("FSEvents failed to become ready")
            gate_started = time.monotonic()
            if touch:
                timer = threading.Timer(4, os.utime, args=(root / "README.md", None))
                timer.start()
            with subprocess.Popen(command, cwd=root, stdout=gate_output, stderr=subprocess.STDOUT) as gate:
                try:
                    if probe_drops:
                        real_drop_attempt(root, watcher)
                    gate.wait(timeout=1500)
                except BaseException:
                    gate.kill()
                    raise
            gate_seconds = time.monotonic() - gate_started
            if timer:
                timer.join()
            after = key(root)
            cutoff = finish_watch(watcher)
            vnode_events = guard.events()
        finally:
            if timer:
                timer.cancel()
            if watcher.poll() is None:
                watcher.kill()
                watcher.wait()

    paths = {root / path for path in before["paths"] + after["paths"]}
    raw_events = [json.loads(line) for line in (HERE / f"{name}.events.jsonl").read_text().splitlines()]
    events = through_cutoff(raw_events, cutoff)
    same_key = all(before[part] == after[part] for part in ("state", "proof"))
    fsevents_deferred, _ = verdict(events, same_key, gate.returncode, paths, git_dir)
    deferred, keyed = verdict(events, same_key, gate.returncode, paths, git_dir, vnode_events)
    real_events_only_exit = 75 if deferred else gate.returncode
    probes = {}
    injected = []
    if probe_drops:
        for flag, bit in PROBE_FLAGS.items():
            real = next((event for event in events if event["flags"] & bit), None)
            event = real or {"id": None, "path": str(root / "DerivedData"), "flags": bit}
            fired, matched = verdict([event], same_key, gate.returncode, paths, git_dir)
            probes[flag] = {"source": "real" if real else "injected",
                            "exit": 75 if fired else gate.returncode, "event_matched": bool(matched),
                            "event": event}
            if not real:
                injected.append(event)
        deferred, keyed = verdict(events + injected, same_key, gate.returncode, paths, git_dir, vnode_events)
    result = {
        "isolation": "live-verified",
        "verdict": "deferred" if deferred else "passed" if gate.returncode == 0 else "failed",
        "gate_exit": gate.returncode,
        "gate_seconds": round(gate_seconds, 2),
        "total_seconds": round(time.monotonic() - started, 2),
        "key_before": [before["state"], before["proof"]],
        "key_after": [after["state"], after["proof"]],
        "same_key": same_key,
        "events": len(raw_events),
        "fsevents_cutoff": cutoff,
        "fsevents_and_keys_only_exit": 75 if fsevents_deferred else gate.returncode,
        "keyed_or_ambiguous_events": keyed,
        "vnode_events": vnode_events,
        "vnode_access_events": guard.access_events,
        "vnode_fds": len(guard.descriptors),
        "vnode_fd_limits": [guard.soft_limit, guard.hard_limit],
        "watched_git_dir": str(git_dir),
    }
    if probe_drops:
        result.update(real_events_only_exit=real_events_only_exit, flag_probes=probes)
    print(json.dumps(result))
    return 75 if deferred else gate.returncode


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("name")
    options = parser.add_mutually_exclusive_group()
    options.add_argument("--touch", action="store_true")
    options.add_argument("--probe-drops", action="store_true")
    options.add_argument("--gate-write", action="store_true")
    args = parser.parse_args()
    try:
        raise SystemExit(run(args.root.resolve(), args.name, args.touch, args.probe_drops, args.gate_write))
    except (OSError, ValueError, RuntimeError, StopIteration, subprocess.SubprocessError) as error:
        print(json.dumps({"isolation": "live-verified", "verdict": "deferred", "reason": str(error)}))
        raise SystemExit(75)
