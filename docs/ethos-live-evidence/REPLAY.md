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
(cd "$koch" && "$runner" handoff approve-live swift-default)

replay_stop() {
  printf '%s\n' '{"session_id":"replay","agent_id":"worker","agent_type":"implementer"}' |
    /usr/bin/time -p env ETHOS_SESSION=replay ETHOS_AGENT_ID=worker \
      CLAUDE_AGENT_TYPE=implementer "$runner" hook subagent-stop
}

cd "$koch"
git --no-optional-locks status --porcelain
replay_stop
(
  probe=KochTrainer/HandoffParityProbe.swift
  (set -C; printf 'let handoffParityProbe    = 1\n' >"$probe") || exit
  trap 'rm -- "$probe"' EXIT
  replay_stop
  /usr/bin/time -p make check
)
```

The diagnostic log at `~/.punt-labs/ethos/logs/ethos.log` distinguishes
`outcome=deferred` from a completed gate. On the test VM, approval also
triggered an unrelated storage upgrade that removed an obsolete
`.gitignore` line. We restored that line before both runs so the clean
replay used the committed Koch tree.
