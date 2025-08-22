.PHONY: all build test clean integration-test help

# Default target - full build and test cycle
all: clean build test integration-test

# Help target
help:
	@echo "Standard build and test commands (used by both local dev and CI):"
	@echo "  make all             - Full build cycle: clean, build, test, integration test"
	@echo "  make build           - Build with strict concurrency checking"
	@echo "  make test            - Run all tests with strict concurrency checking"
	@echo "  make integration-test- Run integration test script"
	@echo "  make clean           - Clean build artifacts"
	@echo ""
	@echo "Note: All builds use strict concurrency checking by default"

# Build with strict concurrency as default standard
build:
	@echo "Building with strict concurrency checking..."
	swift build -Xswiftc -strict-concurrency=complete

# Test with strict concurrency as default standard
test:
	@echo "Running tests with strict concurrency checking..."
	swift test -Xswiftc -strict-concurrency=complete

# Run the integration test script
integration-test:
	@echo "Running integration test..."
	@./test_mcp.sh --query Package.swift --filename-only --limit 5

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf .build