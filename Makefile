# Koch Trainer - CLI Build Commands
# Usage: make <target>

SCHEME = KochTrainer
DESTINATION = platform=iOS Simulator,name=iPhone 17 Pro

.PHONY: help generate build test clean run lint coverage

help:
	@echo "Available commands:"
	@echo "  make generate  - Regenerate Xcode project from project.yml"
	@echo "  make lint      - Run SwiftLint on source files"
	@echo "  make build     - Build the app"
	@echo "  make test      - Run all tests"
	@echo "  make coverage  - Run tests with code coverage report"
	@echo "  make clean     - Clean build artifacts"
	@echo "  make run       - Build and run in simulator"
	@echo "  make all       - Generate, lint, build, and test"

generate:
	@echo "Generating Xcode project..."
	xcodegen generate

lint:
	@echo "Running SwiftLint..."
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint lint --quiet || (echo "SwiftLint found violations. Fix them before continuing." && exit 1); \
		echo "SwiftLint: No violations found."; \
	else \
		echo "SwiftLint not installed. Install with: brew install swiftlint"; \
		exit 1; \
	fi

build: generate lint
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

all: generate lint build test
	@echo "All steps complete."
