from pathlib import Path
import subprocess
import sys


with subprocess.Popen(["make", "check"]) as gate:
    with Path("LiveVerifiedGateProbe.txt").open("x") as probe:
        probe.write("keyed write from gate wrapper\n")
    print(f"Gate wrapper wrote LiveVerifiedGateProbe.txt (make check running: {gate.poll() is None})",
          flush=True)
    sys.exit(gate.wait())
