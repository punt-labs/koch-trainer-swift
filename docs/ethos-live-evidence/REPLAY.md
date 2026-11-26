# Koch Darwin live-verified prototype

The prototype runs the existing `make check` on the real checkout
without changing the gate or claiming snapshot isolation. The
[real-runner probe](#real-runner-parity) below records the current
linked-worktree blocker.

## Setup

Use a Mac with Xcode, a supported iOS Simulator, SwiftFormat, SwiftLint, Git,
Go, and Python 3.12. Start in a clean Koch linked worktree. Set `ethos_repo` to
the absolute path of a local Ethos clone. The comparison calls Ethos's own
`worktreeSnapshotInputs` and `handoffGateInputs` at
`44f6c96c6ed3c432a4856eb7466080fdc8783673`; it does not implement a second
tree key or modify the Ethos checkout.

```sh
koch="$(git rev-parse --show-toplevel)"
evidence="$koch/docs/ethos-live-evidence"
mkdir -p "$koch/.tmp"
proof="$(mktemp -d "$koch/.tmp/koch-live-replay.XXXXXX")"
source="$proof/ethos-source"
ethos_sha=44f6c96c6ed3c432a4856eb7466080fdc8783673
: "${ethos_repo:?Set ethos_repo to your local Ethos clone}"

# The proof subtree is Git-ignored and excluded from keyed paths and vnode watches.
git -C "$koch" check-ignore -q -- "$proof/" || exit 1
cp "$evidence"/{ethos_key_test.go,replay.py,vnode_guard.py,vnode_race.py,gate_write.py} "$proof/"
git -C "$ethos_repo" worktree add --detach "$source" "$ethos_sha"
python3 -c 'import json, sys; from pathlib import Path
s, p = map(Path, sys.argv[1:])
print(json.dumps({"Replace": {str(s / "internal/hook/koch_live_key_test.go"): str(p / "ethos_key_test.go")}}))
' "$source" "$proof" >"$proof/overlay.json"
(cd "$source" && go test -vet=off -overlay "$proof/overlay.json" -c \
  -o "$proof/ethos-key" ./internal/hook)
/usr/bin/swiftc "$evidence/watch.swift" -o "$proof/watch"
git -C "$koch" --no-optional-locks status --porcelain
```

## Gate replays

The replay creates the Git-ignored `DerivedData/` directory before arming
the watches and taking the opening key. This avoids a root directory event
when Xcode first creates its output directory on a fresh checkout.
Other cold-build events still veto the verdict. For example, Xcode can
create its workspace's `swiftpm/` directory, and a busy event stream can
drop events. If a cold build passes but the replay defers on either, retry
on the warmed checkout.

```sh
python3 -B "$proof/replay.py" "$koch" clean >"$proof/clean.json"
# Exit 0.

(
  probe="$koch/KochTrainer/HandoffParityProbe.swift"
  (set -C; printf 'let handoffParityProbe    = 1\n' >"$probe") || exit
  trap 'rm -- "$probe"' EXIT
  python3 -B "$proof/replay.py" "$koch" broken >"$proof/broken.json"
)
# Exit 2 (SwiftFormat); the probe is removed.

(
  probe="$koch/LiveVerifiedGateProbe.txt"
  test ! -e "$probe" || exit 1
  trap 'rm -- "$probe"' EXIT
  python3 -B "$proof/replay.py" "$koch" gate-write --gate-write >"$proof/gate-write.json"
)
# Exit 75. The wrapper waits for a swiftformat, swiftlint, or xcodebuild
# descendant, then writes the unignored file and logs the recipe PID and
# command. Cleanup follows the closing key.

python3 -B "$proof/replay.py" "$koch" overflow --probe-drops >"$proof/overflow.json"
# Exit 75. Inspect flag_probes to distinguish real from injected events.
git -C "$koch" --no-optional-locks status --porcelain
```

The overflow attempt pauses the FSEvents watcher while creating 16,384 files
under ignored `DerivedData`, then resumes it and removes those files. For
each requested coverage flag absent from the raw stream, a test-only
single-bit event passes through the same verdict function. Synthetic events
are marked and do not enter the raw stream.

## Closing-window race

Use a disposable worktree for temporary `HEAD` and `index` replacement.
The race computes both real Ethos keys, then mutates and restores the path
after the closing key and before the FSEvents cutoff. It tests the interval
directly rather than running `make check` for every probe.

```sh
git -C "$koch" worktree add --detach "$proof/koch-race-checkout" HEAD
python3 -B "$proof/vnode_race.py" "$proof/koch-race-checkout" "$proof/vnode-race.jsonl"
# Use a new receipt filename for each run; the script appends.
git -C "$koch" worktree remove "$proof/koch-race-checkout"
```

The watcher subscribes to the checkout and its Git directory, resolved by
`git rev-parse --git-dir`, not the shared store. The FSEvents stream excludes
the Git-ignored proof subtree before delivery if it contains no keyed paths.
Replays record the active exclusions and the raw event count within them.
The verdict still filters ordinary events to the keyed paths and their
ancestors plus the worktree's `HEAD` and
`index`. Coverage flags defer regardless of the cutoff.

The kqueue guard arms `EVFILT_VNODE` before the opening key and drains
after the closing key, cutoff, and FSEvents flush. It watches the keyed files,
eligible directories, and worktree-local Git metadata. Directory events
catch a transient unignored child absent from both keys. As these events
do not name the child, a write on a watched directory is a conservative
veto; existing ignored output subtrees are not watched. An isolated
`NOTE_ATTRIB` with a changed atime and no other measured metadata changes
is recorded as a read, not a mutation. Before arming, the replay raises a
low soft descriptor limit as needed, up to the hard limit and an automatic
raise cap of 8,192. If the watched files plus descriptor headroom do not
fit, or arming or draining fails, the replay defers.

## Recorded results

The clean and keyed-write receipts use the proof exclusion on Koch
`51e81a8`. Both recorded an active exclusion and zero raw events from the
proof directory. The other receipts are from the original Mac replays at
`de2778a`, before this evidence directory and the exclusion were added.
Workstation paths are redacted.

| Scenario | Replay exit | Gate / total | Receipt |
| --- | ---: | ---: | --- |
| Guarded clean with proof exclusion; all 915 tests passed | 0 | 51.35 s / 52.53 s | [JSON](receipts/fsevents-excluded-clean.json), [gate](receipts/fsevents-excluded-clean.gate.txt) |
| Consecutive spaces; gate failed | 2 | 0.15 s / 0.47 s | [JSON](receipts/vnode-broken.json), [gate](receipts/vnode-broken.gate.txt) |
| Keyed write after the SwiftFormat recipe started with proof exclusion; key and both watchers caught it | 75 | 50.82 s / 51.85 s | [JSON](receipts/fsevents-excluded-write.json), [gate](receipts/fsevents-excluded-write.gate.txt) |
| FSEvents overflow (before adding kqueue); gate passed, key unchanged | 75 | 54.78 s / 55.89 s | [JSON](receipts/followup-drops.json), [gate](receipts/followup-drops.gate.txt), [14 real coverage records](receipts/overflow-coverage-events.jsonl) |

The overflow records contained real `MustScanSubDirs | UserDropped`.
`KernelDropped` and `RootChanged` were injected only. Race replays
watch a disposable checkout inside the proof directory, so there is no
proof subtree to exclude from that stream. The original [race
receipt](receipts/vnode-race-final.txt) records 20/20 catches by kqueue and
0/20 by FSEvents through the cutoff in each of the keyed-write, HEAD
replacement, and index replacement groups. The transient create/remove
also fired only on the parent vnode. The 61 trials took 19.32 s with 434
watched descriptors.
Per-trial events are in [vnode-race-final.jsonl](receipts/vnode-race-final.jsonl).
The controls show the [index read/chmod distinction](receipts/vnode-atime-index-control.txt)
and [sibling-worktree index isolation](receipts/watch-scope.txt).

## Real runner parity

**Blocked on linked worktrees.** On Koch `e9658b6`, the real Darwin runner
at Ethos `772a20fb067df2eb29b41f175c01c3debc73c6c7` selected
`isolation=live-verified` but deferred both runs before launching the gate:
`live-verified FSEvents unavailable: live-verified sentinel needs a local .git directory`.
In a linked worktree, `.git` is a file; the actual worktree Git directory
reported by `git rev-parse --absolute-git-dir` exists. This runner's
FSEvents sentinel checks the former and does not use the latter.

The [receipt](receipts/runner-772a20f-linked-worktree.txt) contains the
approval, hook output, timings, and manual gate results. Hook exit `0`
here means that the hook returned an advisory, not that the gate passed.
There is no clean/broken real-runner parity verdict at this SHA.

Build from a separate Ethos worktree. From the clean Koch linked worktree,
use an interactive terminal outside Claude Code and OpenCode for the
approval; the Mac VM acted as the stand-in operator and typed `yes`.
Changing the check YAML or sidecar invalidates that approval.

```sh
koch="$(git rev-parse --show-toplevel)"
mkdir -p "$koch/.tmp"
proof="$(mktemp -d "$koch/.tmp/koch-live-runner.XXXXXX")"
: "${ethos_repo:?Set ethos_repo to your local Ethos clone}"
git -C "$ethos_repo" fetch origin devin/1795658354-darwin-worktree-runner
git -C "$ethos_repo" worktree add --detach "$proof/ethos-source" \
  772a20fb067df2eb29b41f175c01c3debc73c6c7
runner="$proof/ethos"
(cd "$proof/ethos-source" && go build -o "$runner" ./cmd/ethos)

replay_stop() {
  printf '%s\n' '{"session_id":"replay","agent_id":"worker","agent_type":"implementer"}' |
    /usr/bin/time -p env ETHOS_SESSION=replay ETHOS_AGENT_ID=worker \
      CLAUDE_AGENT_TYPE=implementer "$runner" hook subagent-stop
}

replay_live_pair() (
  cd "$koch" || exit 1
  tree_status=$(git --no-optional-locks status --porcelain) || exit 1
  if [ -n "$tree_status" ]; then
    printf 'Approval left a dirty checkout; stop before replaying:\n%s\n' "$tree_status" >&2
    exit 1
  fi
  replay_stop
  (
    probe=KochTrainer/HandoffParityProbe.swift
    (set -C; printf 'let handoffParityProbe    = 1\n' >"$probe") || exit
    trap 'rm -- "$probe"' EXIT
    replay_stop
    /usr/bin/time -p make check
  )
)
```

Approve and replay in the linked worktree:

```sh
(cd "$koch" && "$runner" handoff approve-live swift-default) && replay_live_pair
```

The diagnostic log at `~/.punt-labs/ethos/logs/ethos.log` distinguishes
`outcome=deferred` from a completed gate. On the test VM, approval also
triggered a storage upgrade that removed the tracked
`.punt-labs/ethos/sessions/` entry from `.gitignore`. Inspect and undo
that specific migration delta, then run `replay_live_pair` again in the same
shell. The clean-tree guard exits only its subshell, so `koch` and `runner`
remain set. We restored the entry before both runs.

### Plain-clone replay

Ethos `772a20f` passed the Git-directory sentinel in a plain clone of Koch
`9d4caa9`, but **clean/broken parity is still blocked**. The live runner
sets `PATH=/usr/local/bin:/usr/bin:/bin` when the sidecar declares no path.
SwiftFormat and SwiftLint are installed in `/opt/homebrew/bin` on the Mac
VM. The unchanged gate failed at `make: swiftformat: No such file or directory`
on both trees; exit `2` on the broken tree did not come from SwiftFormat.
We did not change the sidecar or install tools into the runner's path.

| Case | Hook result | Hook wall time | Direct `make check` |
| --- | --- | --- | --- |
| Clean | Block: SwiftFormat not found | 0.45 s | Pass: 915 tests, 0 failures, 67.09 s |
| SwiftFormat break | Block: SwiftFormat not found | 0.44 s | Exit 2: `consecutiveSpaces`, 0.40 s |
| Keyed write after launch | Deferred: checkout input set changed | 0.53 s | Not run |

See the [plain-clone receipt](receipts/runner-772a20f-plain-clone.txt).
The mutation shows the runner discards the gate result when the input set
changes in-flight. It does not demonstrate a watcher veto or a successful
915-test run under Ethos.

Reuse the runner binary and `replay_live_pair` function from the build
block above; do not rerun the linked-worktree setup. This block enters
the plain clone and selects it for interactive approval and replay.
The Mac VM acted as the stand-in operator again because the clone has
a different Git directory. The same storage-upgrade delta was restored
before either gate was run.

```sh
clone="$HOME/repos/koch-plain-parity-9d4caa9"
if git clone https://github.com/punt-labs/koch-trainer-swift.git "$clone" &&
   cd "$clone" &&
   git switch --detach 9d4caa9dba4652198fab00d7601b8baabe6d347b &&
   test -d .git; then
  koch="$(pwd -P)"
  runner="$proof/ethos"
  "$runner" handoff approve-live swift-default && replay_live_pair
fi
```

For the keyed case, use a fresh synthetic session. Create an untracked,
unignored seed containing a UUID before the hook so there is no cached
verdict to reuse. In parallel with the hook, tail new lines in
`~/.punt-labs/ethos/logs/ethos.log` from before its invocation. When the
log records `outcome=launched` for that session, run
`(set -C; printf 'keyed probe\n' >LiveVerifiedGateProbe.txt)` in the checkout.
Leave both files present until the hook returns, then remove them and
check that the clone is clean. Do not substitute `make check` for the hook
in this probe. For the direct clean baseline, run `/usr/bin/time -p make check`
on the clean clone using the normal host PATH.

### Plain-clone replay with Homebrew tools

The sidecar now declares `path: [/opt/homebrew/bin]` and fingerprints
`swiftformat` and `swiftlint` through `system.tools`. Ethos `772a20f`
accepted both fields in live-verified mode and ran both tools. The broken
run blocked with the expected SwiftFormat exit `2`, and a write after
launch deferred because the checkout input set changed.

Reuse the `772a20f` build and `replay_live_pair` function above. In the
clean plain clone, switch to the revision that added the Homebrew fields
and approve again in an interactive terminal. The pin from the earlier
plain-clone replay does not cover this policy.

```sh
clone="$HOME/repos/koch-plain-parity-9d4caa9"
revision=549de7a1829be0478c1c4a33ac522aec1228e846
if cd "$clone" &&
   test -d .git &&
   git fetch origin "$revision" &&
   git switch --detach "$revision"; then
  koch="$(pwd -P)"
  runner="$proof/ethos"
  "$runner" handoff approve-live swift-default && replay_live_pair
fi
```

For the keyed-write case, repeat the probe above from this same checkout
after the clean and broken runs.

**Clean parity still waits for the runner to keep full Xcode selected.**
This runner set `DEVELOPER_DIR` to the Command Line Tools directory for
`make`. SwiftFormat passed, but SwiftLint could not load `sourcekitdInProc`.
The [path/tools receipt](receipts/runner-772a20f-plain-clone-path-tools.txt)
records the hook timings and the direct SwiftLint control: CLT reproduced
the crash; full Xcode passed. The hook did not reach the simulator tests.

### Darwin runner `8d5e529`: linked and plain checkout parity

Tested Koch `be5f1ca21c7dd80ae238092a3c83fd42ac3e7cd2` with the Homebrew
sidecar and Xcode 26.6 (build `17F113`) selected by `xcode-select -p`.
The Mac VM re-approved both checkouts as stand-in operator. Both trees
were clean after approval and after the probes were removed.

| Case | [Linked worktree](receipts/runner-8d5e529-linked-worktree.txt) | [Plain clone](receipts/runner-8d5e529-plain-clone.txt) |
| --- | --- | --- |
| Clean | 65.34 s: 915 XCTest tests, zero failures; FSEvents path-budget deferral | 54.81 s: 915 XCTest tests, zero failures; verdict retained |
| SwiftFormat break | 1.57 s: blocked, gate exit 2, `consecutiveSpaces` | 1.09 s: blocked, gate exit 2, `consecutiveSpaces` |
| Keyed write after launch | 54.14 s: deferred, input set changed at `LiveVerifiedGateProbe.txt` | 50.85 s: deferred, input set changed at `LiveVerifiedGateProbe.txt` |

Both checkouts reached the unchanged gate with full Xcode. In the linked
worktree, the clean run reported `FSEvents path budget exceeded` at a
file in `DerivedData/Logs/Test/`; `git check-ignore -v` confirmed that
the exact path is ignored. The runner counted paths toward its 8,192-path
budget before applying the ignore check. Plain-clone parity is demonstrated;
retaining the clean verdict in a linked worktree is not. The keyed-write
deferrals were input-set mismatches, not independent watcher vetoes.

Build the runner from its pinned ref. Set `proof` to an existing scratch
directory and `ethos_repo` to a local Ethos clone:

```sh
ref=devin/1795658354-darwin-worktree-runner
git -C "$ethos_repo" ls-remote origin "refs/heads/$ref"
git -C "$ethos_repo" fetch origin "$ref"
git -C "$ethos_repo" worktree add --detach "$proof/ethos-darwin-8d5e529" \
  8d5e529e5f1012703e775b968faabc709014acc3
runner="$proof/ethos-darwin-8d5e529-bin"
(cd "$proof/ethos-darwin-8d5e529" && go build -o "$runner" ./cmd/ethos)
```

Run this block once per checkout, setting `checkout` to its absolute path
and `layout` to `linked` or `plain`. Check out the tested Koch revision
first. Use an interactive TTY outside Claude Code and OpenCode and type
`yes` at the approval prompt:

```sh
run_8d5e529() {
  printf '{"session_id":"%s","agent_id":"worker","agent_type":"implementer"}\n' "$1" |
    /usr/bin/time -p env ETHOS_SESSION="$1" ETHOS_AGENT_ID=worker \
      CLAUDE_AGENT_TYPE=implementer "$runner" hook subagent-stop
}

(
  cd "$checkout" || exit 1
  test "$(git rev-parse HEAD)" = be5f1ca21c7dd80ae238092a3c83fd42ac3e7cd2 || exit 1
  "$runner" handoff approve-live swift-default || exit 1
  tree_status=$(git --no-optional-locks status --porcelain) || exit 1
  test -z "$tree_status" || { printf '%s\n' "$tree_status" >&2; exit 1; }
  run_8d5e529 "replay-8d5e529-$layout-clean"
  (
    probe=KochTrainer/HandoffParityProbe.swift
    (set -C; printf 'let handoffParityProbe    = 1\n' >"$probe") || exit 1
    trap 'rm -- "$probe"' EXIT
    run_8d5e529 "replay-8d5e529-$layout-broken"
  )
)
```

Record the newly created clean `.xcresult` bundle from
`DerivedData/Logs/Test/` before starting the keyed probe:

```sh
xcrun xcresulttool get test-results summary --path "$result"
xcrun xcresulttool get log --type action --path "$result"
```

For the keyed run, start tailing new lines in
`~/.punt-labs/ethos/logs/ethos.log` before running this block. When
session `replay-plain-keyed` logs `outcome=launched`, run
`(set -C; printf 'keyed probe\n' >LiveVerifiedGateProbe.txt)` in the
same checkout from a second shell. The UUID seed avoids a cache hit.
Remove only the probe you created after the hook returns, then verify
`git --no-optional-locks status --porcelain` is empty:

```sh
(
  cd "$checkout" || exit 1
  tree_status=$(git --no-optional-locks status --porcelain) || exit 1
  test -z "$tree_status" || { printf '%s\n' "$tree_status" >&2; exit 1; }
  seed=LiveVerifiedGateSeed.txt
  (set -C; uuidgen >"$seed") || exit 1
  trap 'rm -- "$seed"' EXIT
  run_8d5e529 replay-plain-keyed
)
```

### Darwin runner `4c24606`: DerivedData in runner scratch

Koch `04febee7966718ae50ab49833c72a40a2f8023bf` sets
`CHECK_DERIVED_DATA: "{scratch}/DerivedData"` in the live-verified sidecar.
Both the build and test recipes in `make check` use that directory for
`-derivedDataPath`. Without the sidecar override they still use
`./DerivedData`. The gate and its test selection are unchanged. Ethos
watches ignored paths, so ignoring `DerivedData` is not a substitute for
moving it outside the checkout. The runner creates and removes its own
scratch directory.

Build from the exact runner revision (use an existing scratch directory
outside the checkouts for `proof`):

```sh
ref=devin/1795658354-darwin-worktree-runner
git -C "$ethos_repo" ls-remote origin "refs/heads/$ref"
git -C "$ethos_repo" fetch origin "$ref"
git -C "$ethos_repo" worktree add --detach "$proof/ethos-darwin-4c24606" \
  4c246062490ab201d0666a20bd2742eb0df5bd37
runner="$proof/ethos-darwin-4c24606-bin"
(cd "$proof/ethos-darwin-4c24606" && go build -o "$runner" ./cmd/ethos)
```

Use a linked worktree and a separate ordinary clone. Set `checkout` to
each absolute path in turn and `layout` to `linked` or `plain`. Check
out the exact Koch revision above in each checkout first. Run the
following in an interactive TTY outside Claude Code and OpenCode, type
`yes` at the approval prompt, and stop if any clean-tree guard fails:

```sh
clean_checkout() {
  local tree_status
  tree_status=$(git --no-optional-locks status --porcelain) || return 1
  test -z "$tree_status" || { printf '%s\n' "$tree_status" >&2; return 1; }
}

run_4c24606() {
  printf '{"session_id":"%s","agent_id":"worker","agent_type":"implementer"}\n' "$1" |
    /usr/bin/time -p env ETHOS_SESSION="$1" ETHOS_AGENT_ID=worker \
      CLAUDE_AGENT_TYPE=implementer "$runner" hook subagent-stop
}

(
  cd "$checkout" || exit 1
  test "$(git rev-parse HEAD)" = 04febee7966718ae50ab49833c72a40a2f8023bf || exit 1
  clean_checkout || exit 1
  "$runner" handoff approve-live swift-default || exit 1
  clean_checkout || exit 1
  run_4c24606 "replay-4c24606-$layout-clean" || exit 1
  clean_checkout || exit 1
  (
    probe=KochTrainer/HandoffParityProbe.swift
    (set -C; printf 'let handoffParityProbe    = 1\n' >"$probe") || exit 1
    trap 'rm -- "$probe"' EXIT
    run_4c24606 "replay-4c24606-$layout-broken"
  ) || exit 1
  clean_checkout
)
```

For the keyed-write case, start tailing new lines in
`~/.punt-labs/ethos/logs/ethos.log` before starting the block. From a
second shell in the same checkout, run
`(set -C; printf 'keyed probe\n' >LiveVerifiedGateProbe.txt)` when the
handoff diagnostic for `replay-plain-keyed` reports `outcome=launched`.
After the hook returns, remove only the probe you created, then check
that the tree is clean:

```sh
(
  cd "$checkout" || exit 1
  clean_checkout || exit 1
  seed=LiveVerifiedGateSeed.txt
  (set -C; uuidgen >"$seed") || exit 1
  trap 'rm -- "$seed"' EXIT
  run_4c24606 replay-plain-keyed
)
```

```sh
(cd "$checkout" && clean_checkout)
```

The `stage=handoff` diagnostic distinguishes a retained `completed`
verdict from `failed` (block) or `deferred`, and records
`developer_fingerprint`. The hook process can exit zero for any of
those outcomes; inspect the verdict rather than the process exit alone.

Both checkouts retained the clean verdict with no FSEvents budget defer.
Both blocked on the deliberate SwiftFormat violation and deferred on
the keyed write with the same advisory:

> handoff checks deferred (full-gate): checkout input set changed during
> the live-verified check at "LiveVerifiedGateProbe.txt".

The runner appended the manual `make check` command for the checkout.
This was an input-set mismatch, not an independent watcher veto.
No `.gitignore` change occurred during approval or any hook run.

| Case | [Linked worktree](receipts/runner-4c24606-linked-worktree.txt) | [Plain clone](receipts/runner-4c24606-plain-clone.txt) |
| --- | --- | --- |
| Clean | 63.25 s: retained pass | 64.75 s: retained pass; 915 XCTest tests, zero failures |
| SwiftFormat break | 1.44 s: blocked, gate exit 2, `consecutiveSpaces` | 1.03 s: blocked, gate exit 2, `consecutiveSpaces` |
| Keyed write after launch | 70.63 s: deferred at `LiveVerifiedGateProbe.txt` | 58.87 s: deferred at `LiveVerifiedGateProbe.txt` |

Both clean runs invoked `xcodebuild build` and `xcodebuild test` with
the scratch path. The plain-clone test count was captured from the
scratch `.xcresult` before removal. The linked run retained its pass
but its scratch result was gone before the test count could be captured.

#### Transient tracked-file probe: matching key, watcher veto

The keyed-write case above leaves a new input in place until the hook
returns. To test the watchers independently, replay Koch
`618e9a7ea5de3ebf6805a3c49f9d476630599b88` with the same approved
`4c24606` runner. This time briefly append to tracked `README.md`
after an actual `xcodebuild` recipe starts, then restore the bytes and
mode before the gate returns.

In the first terminal run:

```sh
(
  cd "$checkout" || exit 1
  clean_checkout || exit 1
  seed=LiveVerifiedGateSeed.txt
  (set -C; uuidgen >"$seed") || exit 1
  trap 'rm -- "$seed"' EXIT
  run_4c24606 "replay-4c24606-$layout-transient"
)
```

In a second terminal, wait for `outcome=launched` for that session in
the hook diagnostics. Use `ps -axo pid=,ppid=,ucomm=` to confirm an
`xcodebuild` descendant of that hook process, not just a running
`make`. Then run this while the recipe is still running:

```sh
(
  cd "$checkout" || exit 1
  git ls-files --error-unmatch -- README.md >/dev/null || exit 1
  test "$(git --no-optional-locks status --porcelain)" = '?? LiveVerifiedGateSeed.txt' || exit 1
  python3 - <<'PY' || exit 1
import hashlib
import os
from pathlib import Path
import stat

tracked = Path("README.md")
before = tracked.stat()
raw = tracked.read_bytes()
mode = stat.S_IMODE(before.st_mode)
with tracked.open("r+b") as f:
    try:
        f.seek(0, os.SEEK_END)
        f.write(b"\ntransient live-verified probe\n")
        f.flush()
        os.fsync(f.fileno())
    finally:
        f.truncate(len(raw))
        f.flush()
        os.fsync(f.fileno())
os.utime(tracked, ns=(before.st_atime_ns, before.st_mtime_ns))
if tracked.read_bytes() != raw or stat.S_IMODE(tracked.stat().st_mode) != mode:
    raise RuntimeError("tracked input not restored")
print(f"{tracked}: opening and restored sha256={hashlib.sha256(raw).hexdigest()} mode={mode:o}", flush=True)
PY
  test "$(git --no-optional-locks status --porcelain)" = '?? LiveVerifiedGateSeed.txt'
)
```

After the first terminal finishes, require `clean_checkout` again in
the checkout. The [transient receipt](receipts/runner-4c24606-transient.txt)
records **66.94 s** for the plain clone and **71.94 s** for the linked
worktree. Both runs reported `FSEvents observed a change` and
`live-verified vetoed by vnode note 0xe` at `README.md`. Neither
reported an input-set or key mismatch. The runner checks those first,
so reaching the watcher veto also establishes that the closing key
matched.
