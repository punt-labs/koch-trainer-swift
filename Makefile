# Koch Trainer - CLI Build Commands
# Usage: make <target>

SCHEME = KochTrainer
DESTINATION = platform=iOS Simulator,name=iPhone 17 Pro

.PHONY: help generate build test clean run

help:
	@echo "Available commands:"
	@echo "  make generate  - Regenerate Xcode project from project.yml"
	@echo "  make build     - Build the app"
	@echo "  make test      - Run all tests"
	@echo "  make clean     - Clean build artifacts"
	@echo "  make run       - Build and run in simulator"
	@echo "  make all       - Generate, build, and test"

generate:
	@echo "Generating Xcode project..."
	xcodegen generate

build: generate
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

all: generate build test
	@echo "All steps complete."
