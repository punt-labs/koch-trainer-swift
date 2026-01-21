# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

iOS app implementing the Koch method for learning Morse code. Single-user, supports 26 letters (Koch order: K M R S U A P T L O W I N J E F Y V G Q Z H B C D X) plus digits 0-9 for callsigns and RST reports.

## Build & Run

Uses XcodeGen for project configuration. The `project.yml` file defines the project structure.

```bash
# Regenerate Xcode project, build, and test
make generate  # Regenerate xcodeproj from project.yml
make build     # Build the app
make test      # Run all tests
make clean     # Clean build artifacts

# Or manually
xcodegen generate
xcodebuild -scheme KochTrainer -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Architecture

### Project Structure

```
KochTrainer/
├── Models/
│   ├── StudentProgress.swift    # Levels, stats, session history, schedule
│   ├── PracticeSchedule.swift   # Intervals, streaks, review dates
│   ├── NotificationSettings.swift
│   ├── SessionResult.swift
│   ├── CharacterStat.swift
│   ├── MorseCode.swift          # 26 letters + 10 digits
│   └── QSO/
│       ├── QSOState.swift       # QSO phase state machine
│       ├── QSOTemplate.swift    # Message templates by style
│       └── VirtualStation.swift # AI station generation
├── ViewModels/
│   ├── ReceiveTrainingViewModel.swift
│   ├── SendTrainingViewModel.swift
│   └── MorseQSOViewModel.swift  # QSO training with keying
├── Views/
│   ├── Home/         # HomeView with streak card, practice due indicators
│   ├── Training/
│   │   ├── CharacterIntroductionView.swift
│   │   ├── Receive/  # ReceiveTrainingView
│   │   └── Send/     # SendTrainingView
│   ├── QSO/          # MorseQSOView, QSOView
│   ├── Results/
│   └── Settings/     # SettingsView, SessionHistoryView, AcknowledgmentsView
├── Services/
│   ├── AudioEngine/  # MorseAudioEngine, ToneGenerator
│   ├── QSO/
│   │   └── QSOEngine.swift      # QSO state machine + AI responses
│   ├── ProgressStore.swift
│   ├── IntervalCalculator.swift  # Spaced repetition intervals
│   ├── StreakCalculator.swift    # Consecutive day tracking
│   ├── NotificationManager.swift # Local notification scheduling
│   ├── MorseDecoder.swift
│   └── GroupGenerator.swift
└── Resources/
    └── Assets.xcassets/
```

### Training Flow

Both receive and send training follow the same phase pattern:

1. **Introduction** - Shows each unlocked character with pattern, auto-plays sound
2. **Training** - Call-and-response with timeout, tracks accuracy
3. **Paused** - Optional pause state
4. **Completed** - Shows results, level-up celebration if advanced

Auto-advance triggers when: `totalAttempts >= 20 && accuracy >= 90%`

### Separate Levels

Progress is tracked independently for receive and send:

```swift
struct StudentProgress {
    var receiveLevel: Int  // 1-26
    var sendLevel: Int     // 1-26
    var schedule: PracticeSchedule  // Intervals, streaks, review dates

    func level(for sessionType: SessionType) -> Int
    func unlockedCharacters(for sessionType: SessionType) -> [Character]
}
```

### Streak & Spaced Repetition

`PracticeSchedule` tracks practice intervals and streaks:

```swift
struct PracticeSchedule {
    var receiveInterval: Double     // Days until next practice (1.0 - 30.0)
    var sendInterval: Double
    var receiveNextDate: Date?      // Calculated: lastPractice + interval
    var sendNextDate: Date?
    var currentStreak: Int          // Consecutive calendar days practiced
    var longestStreak: Int
    var lastStreakDate: Date?
    var levelReviewDates: [Int: Date]  // Level -> review date (7 days after advancing)
}
```

**Interval Algorithm** (`IntervalCalculator`):
| Accuracy | Interval Change |
|----------|-----------------|
| ≥90% | Double (max 30 days) |
| 70-89% | Unchanged |
| <70% | Reset to 1 day |

- First 14 days: capped at 2 days (habit formation)
- Missed >2× interval: reset to 1 day

**Streak Rules** (`StreakCalculator`):
- Consecutive calendar days with at least one session
- Same-day practice: streak unchanged
- Next day: streak +1
- Skipped day: streak resets to 1

### Notifications

`NotificationManager` schedules local notifications with anti-nag policy:

| Type | Trigger | Identifier |
|------|---------|------------|
| Practice Due | nextDate reached | `practice.receive` / `practice.send` |
| Streak Reminder | 8 PM, no practice today, streak ≥3 | `streak.reminder` |
| Level Review | 7 days after level-up | `level.review.\(level)` |
| Welcome Back | 7+ days inactive | `welcome.back` |

**Anti-Nag Policy**:
- Max 2 notifications/day
- 4-hour minimum gap
- Quiet hours: 10 PM - 8 AM (adjustable)

### Receive Training

- Plays Morse audio for a character
- User types the letter on keyboard (hidden TextField captures input)
- 3-second timeout with progress bar
- Immediate feedback, replays character if wrong

### Send Training

- Shows target character (no pattern hint)
- User taps dit/dah buttons or uses keyboard:
  - `.` or `F` = dit
  - `-` or `J` = dah
- Audio feedback plays for each dit/dah
- 2-second timeout after input to complete character
- Pattern decoded and compared to target

### Audio Engine

`ToneGenerator` uses a serial queue to ensure rapid key presses don't drop audio:

```swift
private let audioQueue = DispatchQueue(label: "com.kochtrainer.audioQueue")
```

Each tone request is queued and waits for the previous to finish.

### Audio Timing (20 WPM character speed)

| Element | Duration |
|---------|----------|
| Dit | 60ms |
| Dah | 180ms |
| Inter-element | 60ms |
| Inter-character (Farnsworth) | ~420ms |
| Inter-word (Farnsworth) | ~980ms |
| Tone frequency | 600 Hz (configurable 400-800) |

### Key Protocols

```swift
// Shared intro behavior for both training modes
@MainActor
protocol CharacterIntroducing: ObservableObject {
    var introCharacters: [Character] { get }
    var currentIntroCharacter: Character? { get }
    var introProgress: String { get }
    var isLastIntroCharacter: Bool { get }
    func playCurrentIntroCharacter()
    func nextIntroCharacter()
}
```

## Technical Constraints

- iOS 16+, Swift 5.9+, SwiftUI
- Portrait only
- No external dependencies
- XcodeGen for project configuration

## Testing Requirements

- **All tests must pass.** No exceptions for "pre-existing failures."
- If a test fails, fix it. Do not skip, ignore, or work around failing tests.
- Run `make test` before considering any task complete.
- Flaky tests must be fixed to be deterministic or use sufficient sample sizes for probabilistic assertions.
- Run SwiftLint and fix all warnings before considering work complete.

**Current Status:** 519 tests. Target: 80% coverage.

## SwiftFormat & SwiftLint Compliance

Both tools must pass with zero warnings. The build cycle runs them automatically: `make build` runs format → lint → compile.

### Build Commands

```bash
make format    # Run SwiftFormat
make lint      # Run SwiftLint
make build     # Format + Lint + Build (recommended)
```

### Configuration Alignment

SwiftFormat and SwiftLint must be aligned. Key settings in `.swiftformat`:

```
--voidtype void                        # Use `Void` not `()` (matches SwiftLint void_return)
--commas inline                        # No trailing commas (matches SwiftLint trailing_comma)
--allman false                         # Braces on same line (matches SwiftLint opening_brace)
--disable trailingCommas               # Don't add trailing commas
--disable wrapMultilineStatementBraces # Keep brace on same line for multi-line conditions
```

If SwiftFormat changes produce SwiftLint errors, the configs are misaligned. Fix the `.swiftformat` config, not by disabling SwiftLint rules.

### File & Type Limits

| Metric | Warning | Error |
|--------|---------|-------|
| File length | 500 lines | 1000 lines |
| Type body length | 300 lines | 500 lines |
| Function body length | 60 lines | 100 lines |
| Cyclomatic complexity | 15 | 25 |

When approaching limits, split into multiple files or extract helper types/functions.

### Force Unwrapping — NEVER Use

**Banned:**
```swift
let value = optionalValue!           // force_unwrapping
let date = Calendar.current.date(...)!
```

**Required patterns:**
```swift
// In production code - use guard/if let
guard let value = optionalValue else { return }
if let value = optionalValue { ... }

// In tests - use XCTUnwrap
let value = try XCTUnwrap(optionalValue)
```

### Implicitly Unwrapped Optionals — NEVER Use

**Banned:**
```swift
private var manager: NotificationManager!  // implicitly_unwrapped_optional
```

**Required patterns:**
```swift
// Use lazy initialization
private lazy var manager = NotificationManager()

// Or use regular optional with setUp()
private var manager: NotificationManager?
```

### Test File Patterns

Always use `throws` for tests that unwrap optionals:
```swift
func testSomething() throws {
    let value = try XCTUnwrap(optionalValue)
    // ...
}
```

For date arithmetic in tests:
```swift
// BAD
let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

// GOOD
let tomorrow = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: Date()))
```

For DateComponents manipulation:
```swift
// BAD
components.day! += 1

// GOOD
let day = try XCTUnwrap(components.day)
components.day = day + 1
```

## Issue Tracking with Beads

This project uses **beads** (`bd`) for issue tracking—a git-native, AI-friendly issue tracker that lives in the `.beads/` directory.

### When to Use Beads vs TodoWrite

| Use Beads (`bd`) | Use TodoWrite |
|------------------|---------------|
| Multi-session work | Single-session tasks |
| Work with dependencies | Simple linear execution |
| Discovered work to track | Immediate TODO items |
| Strategic planning | Tactical execution |
| Handoff to future sessions | Current session tracking |

**Rule of thumb**: If you might not finish it this session, or if it blocks/is blocked by other work, use beads.

### Essential Commands

```bash
# Finding work
bd ready                    # Show issues ready to work (no blockers)
bd list --status=open       # All open issues
bd show <id>                # View issue details with dependencies

# Working on issues
bd create --title="..." --type=task --priority=2   # Create issue (priority 0-4)
bd update <id> --status=in_progress                # Claim work
bd close <id>                                      # Mark complete
bd close <id1> <id2> ...                           # Close multiple at once

# Dependencies
bd dep add <child> <parent>  # child depends on parent (parent blocks child)
bd blocked                   # Show all blocked issues

# Sync
bd sync                      # Sync with git remote
```

### Priority Levels

| Priority | Meaning |
|----------|---------|
| P0 | Critical - drop everything |
| P1 | High - do soon |
| P2 | Medium (default) |
| P3 | Low - when time permits |
| P4 | Backlog |

### Session Close Protocol

**CRITICAL**: Before ending any session, complete this checklist:

```bash
# 1. Check for uncommitted work
git status

# 2. Stage and commit code changes
git add <files>
git commit -m "..."

# 3. Sync beads changes
bd sync

# 4. Push everything
git push

# 5. Verify
git status  # Must show "up to date with origin"
```

**Work is NOT complete until `git push` succeeds.** Never leave work stranded locally.

### Creating Issues for Discovered Work

When you discover work that needs doing but isn't part of the current task:
1. Create a beads issue immediately: `bd create --title="..." --type=task`
2. Add dependencies if relevant: `bd dep add <new-issue> <blocking-issue>`
3. Continue with current work

This prevents losing track of discovered issues across session boundaries.

## Development Workflow

### Working a Beads Issue

**1. Find and claim work:**
```bash
bd ready                              # Show available work
bd show <id>                          # Review issue details
bd update <id> --status=in_progress   # Claim it
```

**2. Create feature branch:**
```bash
git checkout main && git pull
git checkout -b feature/<short-description>   # or fix/, refactor/
```

**3. Implement:**
- Read relevant files, understand current implementation
- Write code with corresponding unit tests
- Run `make build` frequently (formats, lints, compiles)
- Run `make test` before considering work complete

**4. Update CHANGELOG.md:**
- Add entry under `[Unreleased]` section
- Use categories: Added, Changed, Deprecated, Removed, Fixed, Security
- Write user-facing descriptions, not technical jargon

**5. Commit and push branch:**
```bash
git add <files>
git commit -m "feat: description"
git push -u origin feature/<short-description>
```

**6. Create Pull Request:**
```bash
gh pr create --title "feat: description" --body "## Summary\n..."
```

**7. After PR merged:**
```bash
bd close <id>                         # Mark issue complete
git checkout main && git pull
git branch -d feature/<short-description>
bd sync                               # Sync beads state
```

### Branch Naming Convention

| Prefix | Use Case |
|--------|----------|
| `feature/` | New features |
| `fix/` | Bug fixes |
| `refactor/` | Code improvements |
| `docs/` | Documentation only |

### If Blocked or Discovering New Work

```bash
# Create issue for discovered work
bd create --title="..." --type=task --priority=2

# If current issue is blocked by another
bd update <id> --status=open          # Unclaim
bd dep add <id> <blocking-id>         # Mark dependency
```

### Release Workflow

Use `make release` for the automated workflow:

```bash
make release  # Interactive: prompts for patch/minor/major, updates CHANGELOG, tags, pushes
```

The release target:
1. Validates clean git state and main branch
2. Bumps version in `project.yml`
3. Moves `[Unreleased]` entries to new version section in CHANGELOG.md
4. Increments build number
5. Commits, tags, and optionally pushes + creates GitHub release

For TestFlight archives: `make archive` computes build number from base + git commits.

### Commit Message Convention

```
type(scope): description

feat:     New feature
fix:      Bug fix
docs:     Documentation
refactor: Code change that neither fixes a bug nor adds a feature
test:     Adding or updating tests
chore:    Build process, dependencies, CI
```

## Parallel Development with Worktrees

Git worktrees allow working on multiple branches simultaneously without stashing or switching. Each worktree is a separate checkout that shares the same `.git` directory.

### Worktree Location

All worktrees live in `~/Coding/koch-trainer-worktrees/`. The main repo stays at `~/Coding/koch-trainer-swift/`.

### Creating a Worktree

```bash
# Create worktree for existing remote branch
make worktree-create BRANCH=feature/foo

# Create worktree with new branch (based on main)
make worktree-create BRANCH=feature/new-thing NEW=1

# Or manually
git worktree add ~/Coding/koch-trainer-worktrees/feature-foo feature/foo
git worktree add -b feature/new-thing ~/Coding/koch-trainer-worktrees/new-thing main
```

### Working in a Worktree

```bash
cd ~/Coding/koch-trainer-worktrees/feature-foo
bd list    # Same issues as main repo (beads auto-redirects)
make build
make test
```

### Beads Redirect Behavior

When you create a worktree, beads automatically creates a redirect file in the worktree's `.beads/` that points to the main repo's `.beads/` database. All worktrees share the same issue database—no manual configuration needed.

### Listing Worktrees

```bash
make worktree-list
# Or: git worktree list
```

### Removing a Worktree

```bash
make worktree-remove BRANCH=feature/foo

# Or manually
git worktree remove ~/Coding/koch-trainer-worktrees/feature-foo
git worktree remove --force ~/Coding/koch-trainer-worktrees/feature-foo  # If uncommitted changes
```

### Syncing Beads Across Branches

Run `bd sync` before and after merging or switching contexts to ensure issue state is consistent across all worktrees.

### Optional: External Beads with direnv

For complete separation of beads from code history, you can use an external beads repo with direnv. See `.envrc.example` for configuration. This adds complexity and is not recommended for single-developer projects.

## Standards

- Do not suggest skipping tests, lowering coverage targets, or ignoring failures.
- Do not present "workarounds" for failing tests—fix the actual problem.
- Do not filter or cherry-pick results to make metrics look better.
- Report complete, unfiltered data. If coverage is low, report the actual numbers.
