from pathlib import Path
import subprocess
import sys


rc = subprocess.call(["make", "check"])
with Path("LiveVerifiedGateProbe.txt").open("x") as probe:
    probe.write("keyed write from gate wrapper\n")
print("Gate wrapper wrote LiveVerifiedGateProbe.txt", flush=True)
sys.exit(rc)
