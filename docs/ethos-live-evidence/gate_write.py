from pathlib import Path
import subprocess
import sys
import time


def wait_for_recipe(gate):
    deadline = time.monotonic() + 10
    while gate.poll() is None and time.monotonic() < deadline:
        processes = subprocess.check_output(["/bin/ps", "-axo", "pid=,ppid=,comm="], text=True)
        for line in processes.splitlines():
            fields = line.split(maxsplit=2)
            if len(fields) == 3 and fields[1] == str(gate.pid):
                return fields[0], Path(fields[2]).name
        time.sleep(0.02)
    raise RuntimeError("no make check recipe process observed before the keyed-write probe")


with subprocess.Popen(["make", "check"]) as gate:
    pid, command = wait_for_recipe(gate)
    with Path("LiveVerifiedGateProbe.txt").open("x") as probe:
        probe.write("keyed write from gate wrapper\n")
    print(f"Gate wrapper wrote LiveVerifiedGateProbe.txt after starting recipe pid={pid} command={command}",
          flush=True)
    sys.exit(gate.wait())
