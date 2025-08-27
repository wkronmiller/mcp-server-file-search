# Repository Guidelines

## Project Structure & Module Organization
- `Sources/MCPFileSearch/`: Main Swift sources (entry point, server, utilities).
- `Tests/MCPFileSearchTests/`: XCTest unit and integration helpers.
- `Makefile`: Unified build/test targets used locally and in CI.
- `.build/debug/mcp-file-search`: Built executable (after `make build`).
- `test_mcp.sh`: JSON-RPC integration harness for the MCP server.

## Build, Test, and Development Commands
- `make all`: Clean, build, run unit + integration tests (recommended).
- `make build`: Strict build with concurrency checking.
- `make test`: Full test suite with strict concurrency.
- `make integration-test`: End-to-end JSON-RPC test via `test_mcp.sh`.
- `make clean`: Remove build artifacts.
- Examples: `swift test --filter SomeTests.testBehavior`, `./test_mcp.sh --query Package.swift --filename-only --limit 5`.

## Coding Style & Naming Conventions
- Language: Swift 5.9+ with `async/await`; prefer `Task` for async entry.
- Imports order: `Foundation`, `MCP`, then platform-specific blocks (`#if os(macOS)`).
- Types: Use explicit access control; prefer `struct` for data models; `enum` for namespaces.
- Naming: UpperCamelCase types; lowerCamelCase for vars/functions; descriptive names.
- JSON: Use `Codable` for MCP payloads. Handle errors with `throw` and write diagnostics to stderr (`fputs`).
- Lint/format: No linters configured—follow standard Swift formatting (4-space indent, 100–120 col soft guide).

## Testing Guidelines
- Framework: XCTest. Test files live in `Tests/MCPFileSearchTests` and end with `Tests.swift`.
- Conventions: Methods start with `test...` and are deterministic.
- Running: `make test` for unit; `make integration-test` for RPC flow. Single test: `swift test --filter ...`.
- Add tests for new tools/flags and edge cases (empty results, timeouts, scope filtering).

## Commit & Pull Request Guidelines
- History shows mixed styles; prefer Conventional Commits: `feat:`, `fix:`, `refactor:`, `chore:`, `docs:`.
- Commits: Small, focused; imperative mood; reference issues (`#123`) when relevant.
- PRs: Clear description, motivation, and scope; link issues; include usage examples/logs for behavior changes; note platform implications (Spotlight/macOS).
- CI: Ensure `make all` passes locally before requesting review.

## Security & Configuration Tips
- macOS Spotlight requires indexing and appropriate permissions; document any Full Disk Access needs when reproducing.
- Avoid traversing user-unexpected paths; respect provided scopes.
- Timeouts and limits: keep sane defaults; surface via tool params where applicable.
