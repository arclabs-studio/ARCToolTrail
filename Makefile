# ARCToolTrail Makefile
# ARC Labs Studio Swift Package conventions

.PHONY: help lint format fix build build-release test clean

help:
	@echo "ARCToolTrail — Available commands:"
	@echo "  make lint           — Run SwiftLint"
	@echo "  make format         — Run SwiftFormat (dry-run)"
	@echo "  make fix            — Apply SwiftFormat"
	@echo "  make build          — Build all targets (debug)"
	@echo "  make build-release  — Build the tooltrail executable in release mode"
	@echo "  make test           — Run all tests"
	@echo "  make clean          — Clean build artifacts"

lint:
	@swiftlint lint --config .swiftlint.yml

format:
	@swiftformat Sources Tests --config .swiftformat --lint

fix:
	@swiftformat --config .swiftformat Sources Tests

build:
	@swift build

build-release:
	@swift build -c release --product tooltrail

test:
	@swift test

clean:
	@rm -rf .build DerivedData .swiftpm/xcode
	@echo "✓ Build artifacts removed"
