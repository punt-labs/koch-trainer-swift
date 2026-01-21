# Koch Trainer - CLI Build Commands
# Usage: make <target>

SCHEME = KochTrainer
DESTINATION = platform=iOS Simulator,name=iPhone 17 Pro

.PHONY: help generate build test clean run lint format coverage version bump-patch bump-minor bump-major bump-build release archive worktree-create worktree-remove worktree-list

help:
	@echo "Available commands:"
	@echo ""
	@echo "  Development:"
	@echo "    make generate    - Regenerate Xcode project from project.yml"
	@echo "    make format      - Run SwiftFormat to auto-format code"
	@echo "    make lint        - Run SwiftLint on source files"
	@echo "    make build       - Build the app (runs format + lint first)"
	@echo "    make test        - Run all tests"
	@echo "    make coverage    - Run tests with code coverage report"
	@echo "    make clean       - Clean build artifacts"
	@echo "    make run         - Build and run in simulator"
	@echo "    make all         - Generate, format, lint, build, and test"
	@echo ""
	@echo "  Versioning:"
	@echo "    make version     - Show current version and build number"
	@echo "    make bump-patch  - Bump patch version (0.7.0 -> 0.7.1)"
	@echo "    make bump-minor  - Bump minor version (0.7.0 -> 0.8.0)"
	@echo "    make bump-major  - Bump major version (0.7.0 -> 1.0.0)"
	@echo "    make release     - Create a release (bump, tag, push, GitHub release)"
	@echo "    make archive     - Build release archive with computed build number"
	@echo ""
	@echo "  Worktrees:"
	@echo "    make worktree-create BRANCH=feature/foo       - Create worktree for branch"
	@echo "    make worktree-create BRANCH=feature/foo NEW=1 - Create worktree with new branch"
	@echo "    make worktree-remove BRANCH=feature/foo       - Remove worktree"
	@echo "    make worktree-list                            - List active worktrees"

generate:
	@echo "Generating Xcode project..."
	xcodegen generate

format:
	@echo "Running SwiftFormat..."
	@if command -v swiftformat >/dev/null 2>&1; then \
		swiftformat . --quiet; \
		echo "SwiftFormat: Complete."; \
	else \
		echo "SwiftFormat not installed. Install with: brew install swiftformat"; \
		exit 1; \
	fi

lint:
	@echo "Running SwiftLint..."
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint lint --quiet || (echo "SwiftLint found violations. Fix them before continuing." && exit 1); \
		echo "SwiftLint: No violations found."; \
	else \
		echo "SwiftLint not installed. Install with: brew install swiftlint"; \
		exit 1; \
	fi

build: generate format lint
	@echo "Building $(SCHEME)..."
	xcodebuild build \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-quiet

test: generate
	@echo "Running tests..."
	@xcodebuild test \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		2>&1 | grep -E "(Executed|TEST SUCCEEDED|TEST FAILED)" | tail -3

clean:
	@echo "Cleaning..."
	xcodebuild clean -scheme $(SCHEME) -quiet 2>/dev/null || true
	rm -rf ~/Library/Developer/Xcode/DerivedData/KochTrainer-*
	@echo "Clean complete."

run: build
	@echo "Launching simulator..."
	xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
	open -a Simulator
	@echo "Installing app..."
	xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/KochTrainer-*/Build/Products/Debug-iphonesimulator/KochTrainer.app
	@echo "Launching app..."
	xcrun simctl launch booted com.kochtrainer.app

coverage: generate
	@echo "Running tests with coverage..."
	@xcodebuild test \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-enableCodeCoverage YES \
		-resultBundlePath ./build/TestResults.xcresult \
		2>&1 | grep -E "(Executed|TEST SUCCEEDED|TEST FAILED)" | tail -3
	@echo ""
	@echo "Extracting coverage data..."
	@xcrun xccov view --report --json ./build/TestResults.xcresult 2>/dev/null | \
		python3 -c "import json,sys; d=json.load(sys.stdin); \
		targets=[t for t in d.get('targets',[]) if t.get('name')=='KochTrainer.app']; \
		cov=targets[0].get('lineCoverage',0)*100 if targets else 0; \
		print(f'Line Coverage: {cov:.1f}%')" 2>/dev/null || echo "Could not parse coverage report."

all: generate format lint build test
	@echo "All steps complete."

# =============================================================================
# Versioning
# =============================================================================

# Extract current version from project.yml
VERSION := $(shell grep 'MARKETING_VERSION:' project.yml | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
BUILD := $(shell grep 'CURRENT_PROJECT_VERSION:' project.yml | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

version:
	@echo "Version: $(VERSION) (build $(BUILD))"
	@echo "Git commits: $$(git rev-list --count HEAD)"

bump-patch:
	@echo "Bumping patch version..."
	@NEW_VERSION=$$(echo $(VERSION) | awk -F. '{print $$1"."$$2"."$$3+1}'); \
	sed -i '' "s/MARKETING_VERSION: \"$(VERSION)\"/MARKETING_VERSION: \"$$NEW_VERSION\"/" project.yml; \
	echo "Version: $(VERSION) -> $$NEW_VERSION"

bump-minor:
	@echo "Bumping minor version..."
	@NEW_VERSION=$$(echo $(VERSION) | awk -F. '{print $$1"."$$2+1".0"}'); \
	sed -i '' "s/MARKETING_VERSION: \"$(VERSION)\"/MARKETING_VERSION: \"$$NEW_VERSION\"/" project.yml; \
	echo "Version: $(VERSION) -> $$NEW_VERSION"

bump-major:
	@echo "Bumping major version..."
	@NEW_VERSION=$$(echo $(VERSION) | awk -F. '{print $$1+1".0.0"}'); \
	sed -i '' "s/MARKETING_VERSION: \"$(VERSION)\"/MARKETING_VERSION: \"$$NEW_VERSION\"/" project.yml; \
	echo "Version: $(VERSION) -> $$NEW_VERSION"

# Increment build number (for TestFlight - must always increase)
bump-build:
	@echo "Bumping build number..."
	@NEW_BUILD=$$(($(BUILD) + 1)); \
	sed -i '' "s/CURRENT_PROJECT_VERSION: \"$(BUILD)\"/CURRENT_PROJECT_VERSION: \"$$NEW_BUILD\"/" project.yml; \
	echo "Build: $(BUILD) -> $$NEW_BUILD"

release:
	@echo "=== Release Workflow ==="
	@# Validate clean state
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "Error: Working directory not clean. Commit or stash changes first."; \
		exit 1; \
	fi
	@# Validate on main branch
	@BRANCH=$$(git rev-parse --abbrev-ref HEAD); \
	if [ "$$BRANCH" != "main" ]; then \
		echo "Error: Must be on main branch (currently on $$BRANCH)"; \
		exit 1; \
	fi
	@# Validate version doesn't already exist as tag
	@if git tag -l | grep -q "^v$(VERSION)$$"; then \
		echo "Error: Tag v$(VERSION) already exists. Bump version first."; \
		exit 1; \
	fi
	@echo ""
	@echo "Current version: $(VERSION) (build $(BUILD))"
	@echo ""
	@read -p "Release type (patch/minor/major) or 'current' to use $(VERSION): " TYPE; \
	if [ "$$TYPE" = "patch" ]; then \
		$(MAKE) bump-patch; \
	elif [ "$$TYPE" = "minor" ]; then \
		$(MAKE) bump-minor; \
	elif [ "$$TYPE" = "major" ]; then \
		$(MAKE) bump-major; \
	elif [ "$$TYPE" != "current" ]; then \
		echo "Invalid option. Use: patch, minor, major, or current"; \
		exit 1; \
	fi
	@# Re-read version after potential bump and continue release
	@NEW_VERSION=$$(grep 'MARKETING_VERSION:' project.yml | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/'); \
	echo ""; \
	echo "Preparing release v$$NEW_VERSION..."; \
	DATE=$$(date +%Y-%m-%d); \
	PREV_VERSION=$$(grep -E '^\[[0-9]+\.[0-9]+\.[0-9]+\]:' CHANGELOG.md | head -1 | sed 's/\[\([^]]*\)\].*/\1/'); \
	python3 -c "import re; \
	content = open('CHANGELOG.md').read(); \
	content = re.sub(r'## \[Unreleased\]', '## [Unreleased]\\n\\n## [$$NEW_VERSION] - $$DATE', content, count=1); \
	content = re.sub(r'\[Unreleased\]: (.*/compare/)v[0-9.]+\.\.\.HEAD', '[Unreleased]: \\1v$$NEW_VERSION...HEAD', content); \
	if '[$$NEW_VERSION]:' not in content and '$$PREV_VERSION' != '': \
	    content = re.sub(r'(\[Unreleased\]: [^\n]+)', '\\1\\n[$$NEW_VERSION]: https://github.com/punt-labs/koch-trainer-swift/compare/v$$PREV_VERSION...v$$NEW_VERSION', content); \
	open('CHANGELOG.md', 'w').write(content)"; \
	$(MAKE) bump-build; \
	git add project.yml CHANGELOG.md; \
	git commit -m "chore(release): v$$NEW_VERSION"; \
	git tag -a "v$$NEW_VERSION" -m "Release v$$NEW_VERSION"; \
	echo ""; \
	echo "Release v$$NEW_VERSION prepared locally."; \
	echo ""; \
	read -p "Push to origin and create GitHub release? (y/n): " CONFIRM; \
	if [ "$$CONFIRM" = "y" ]; then \
		git push origin main; \
		git push origin "v$$NEW_VERSION"; \
		NOTES=$$(awk "/## \[$$NEW_VERSION\]/,/## \[/{if(/## \[/ && !/## \[$$NEW_VERSION\]/)exit; print}" CHANGELOG.md | tail -n +2); \
		gh release create "v$$NEW_VERSION" --title "v$$NEW_VERSION" --notes "$$NOTES"; \
		echo "Release v$$NEW_VERSION published!"; \
	else \
		echo "Release prepared but not pushed. Run manually:"; \
		echo "  git push origin main && git push origin v$$NEW_VERSION"; \
	fi

archive: generate
	@echo "Building release archive..."
	@# Compute build number: base + git commits (ensures always increasing)
	@COMPUTED_BUILD=$$(($(BUILD) + $$(git rev-list --count HEAD))); \
	echo "Version: $(VERSION), Build: $$COMPUTED_BUILD"; \
	xcodebuild archive \
		-scheme $(SCHEME) \
		-destination 'generic/platform=iOS' \
		-archivePath ./build/KochTrainer.xcarchive \
		MARKETING_VERSION=$(VERSION) \
		CURRENT_PROJECT_VERSION=$$COMPUTED_BUILD \
		-quiet; \
	echo "Archive created: ./build/KochTrainer.xcarchive"

# =============================================================================
# Worktrees
# =============================================================================

WORKTREE_DIR = $(HOME)/Coding/koch-trainer-worktrees

# Create a worktree for a branch
# Usage: make worktree-create BRANCH=feature/foo
#        make worktree-create BRANCH=feature/new-thing NEW=1  (creates new branch)
worktree-create:
ifndef BRANCH
	@echo "Error: BRANCH is required"
	@echo "Usage: make worktree-create BRANCH=feature/foo"
	@echo "       make worktree-create BRANCH=feature/new-thing NEW=1"
	@exit 1
endif
	@WORKTREE_NAME=$$(echo "$(BRANCH)" | sed 's|/|-|g'); \
	WORKTREE_PATH="$(WORKTREE_DIR)/$$WORKTREE_NAME"; \
	if [ -d "$$WORKTREE_PATH" ]; then \
		if git worktree list --porcelain | awk '/^worktree / {print $$2}' | grep -qx "$$WORKTREE_PATH"; then \
			echo "Error: Git worktree already exists at $$WORKTREE_PATH"; \
		else \
			echo "Error: Directory already exists at $$WORKTREE_PATH but is not a git worktree."; \
			echo "Please remove or rename this directory, or choose a different BRANCH/WORKTREE_NAME."; \
		fi; \
		exit 1; \
	fi; \
	mkdir -p "$(WORKTREE_DIR)"; \
	if [ -n "$(NEW)" ]; then \
		echo "Creating new branch $(BRANCH) from main..."; \
		git fetch origin main; \
		git worktree add -b "$(BRANCH)" "$$WORKTREE_PATH" origin/main; \
	else \
		echo "Creating worktree for existing branch $(BRANCH)..."; \
		if ! git fetch origin "$(BRANCH)"; then \
			echo "Warning: Failed to fetch origin/$(BRANCH). It may not exist on the remote, or there may be network/authentication issues."; \
			echo "Proceeding to create worktree from local branch '$(BRANCH)' if it exists."; \
		fi; \
		git worktree add "$$WORKTREE_PATH" "$(BRANCH)"; \
	fi; \
	echo ""; \
	echo "Worktree created at: $$WORKTREE_PATH"; \
	echo "cd $$WORKTREE_PATH"

# Remove a worktree
# Usage: make worktree-remove BRANCH=feature/foo
worktree-remove:
ifndef BRANCH
	@echo "Error: BRANCH is required"
	@echo "Usage: make worktree-remove BRANCH=feature/foo"
	@exit 1
endif
	@WORKTREE_NAME=$$(echo "$(BRANCH)" | sed 's|/|-|g'); \
	WORKTREE_PATH="$(WORKTREE_DIR)/$$WORKTREE_NAME"; \
	if [ ! -d "$$WORKTREE_PATH" ]; then \
		echo "Error: Worktree not found at $$WORKTREE_PATH"; \
		exit 1; \
	fi; \
	echo "Removing worktree at $$WORKTREE_PATH..."; \
	git worktree remove "$$WORKTREE_PATH" || git worktree remove --force "$$WORKTREE_PATH"; \
	echo "Worktree removed."

# List all worktrees
worktree-list:
	@echo "Active worktrees:"
	@git worktree list
