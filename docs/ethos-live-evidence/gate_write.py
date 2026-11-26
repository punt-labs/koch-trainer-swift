from pathlib import Path
import subprocess
import sys
import time


RECIPE_COMMANDS = {"swiftformat", "swiftlint", "xcodebuild"}


def wait_for_recipe(gate):
    deadline = time.monotonic() + 10
    while gate.poll() is None and time.monotonic() < deadline:
        processes = subprocess.check_output(["/bin/ps", "-axo", "pid=,ppid=,ucomm="], text=True)
        children = {}
        for line in processes.splitlines():
            fields = line.strip().split(maxsplit=2)
            if len(fields) == 3:
                pid, parent, command = fields
                children.setdefault(parent, []).append((pid, command))
        descendants = [str(gate.pid)]
        for parent in descendants:
            for pid, command in children.get(parent, ()):
                if command in RECIPE_COMMANDS:
                    return pid, command
                descendants.append(pid)
        time.sleep(0.02)
    raise RuntimeError("no make check recipe process observed before the keyed-write probe")


with subprocess.Popen(["make", "check"]) as gate:
    pid, command = wait_for_recipe(gate)
    with Path("LiveVerifiedGateProbe.txt").open("x") as probe:
        probe.write("keyed write from gate wrapper\n")
    print(f"Gate wrapper wrote LiveVerifiedGateProbe.txt after starting recipe pid={pid} command={command}",
          flush=True)
    sys.exit(gate.wait())
