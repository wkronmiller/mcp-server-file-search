# mcp-file-search (macOS)

Spotlight-backed MCP server that searches files on macOS over stdio. It exposes a single tool, `file-search`, to find files by name, contents, or extension, with optional directory scoping, date filtering, sorting, and limits.

## Requirements
- macOS 13+
- Swift 6 toolchain
- Spotlight indexing enabled for the locations you want to search

## Build and Run

### Standard Commands (recommended)
Use the Makefile for consistent builds with strict concurrency checking:
```bash
# Full development workflow (clean, build, test, integration test)
make all

# Individual commands
make build           # Build with strict concurrency checking
make test            # Run all tests with strict concurrency checking  
make integration-test# Run integration test script
make clean           # Clean build artifacts

# Binary location after build
.build/debug/mcp-file-search
```

### Direct Swift Commands (advanced)
For development that doesn't require strict concurrency checking:
```bash
swift build          # Standard build
swift test           # Standard tests
```

## What It Implements
- MCP server name: `mac-file-search`
- Transport: stdio
- Tools advertised: `file-search`
- Logs: `~/.local/share/mcp-file-search/log/<pid>.log`

## Tool: file-search
Input schema (fields are optional unless noted):
- query: Search text (string). For `extension` use extension without dot. Wildcards `*` are supported for name/content searches.
- queryType: One of `extension | contents | filename | all` (default: `all`).
- extensions: Array of extensions (no dots). Used with `queryType = extension`.
- onlyIn: Array of absolute directory paths to scope the search.
- dateFilter: Object with ISO 8601 `from` and `to` timestamps, applied to modification date.
- sortBy: One of `name | dateModified | dateCreated | size` (default: `name`).
- sortOrder: `ascending | descending` (default: `ascending`).
- limit: Max results to return (default: 200).
- filenameOnly: Boolean. Back-compat shortcut for `queryType = filename`.

Response content is a JSON array of objects:
- path: Full path (string)
- name: Filename (string)
- kind: File type description (string, optional)
- size: Size in bytes (number, optional)
- created: ISO 8601 creation date (string, optional)
- modified: ISO 8601 modification date (string, optional)

### Examples (JSON-RPC over stdio)
Filename-only search, limited to a directory:
```json
{"jsonrpc":"2.0","method":"tools/call","params":{
  "name":"file-search",
  "arguments":{
    "query":".swift",
    "filenameOnly":true,
    "onlyIn":["/absolute/path/to/project"],
    "limit":10
  }
},"id":1}
```

Search by extension across the whole machine:
```json
{"jsonrpc":"2.0","method":"tools/call","params":{
  "name":"file-search",
  "arguments":{
    "queryType":"extension",
    "extensions":["pdf","docx"],
    "limit":50
  }
},"id":2}
```

Content search with date filter and sorting:
```json
{"jsonrpc":"2.0","method":"tools/call","params":{
  "name":"file-search",
  "arguments":{
    "query":"invoice",
    "queryType":"contents",
    "dateFilter":{"from":"2024-01-01T00:00:00Z","to":"2024-12-31T23:59:59Z"},
    "sortBy":"dateModified",
    "sortOrder":"descending",
    "limit":25
  }
},"id":3}
```

Notes:
- Searches time out after ~10s by default (configurable via `timeoutSeconds`); partial results may be returned.
- Results are Spotlight-based; files excluded from indexing will not appear.

## Client Configuration Examples

### Claude Desktop (claude_desktop_config.json)
```json
{
  "mcpServers": {
    "mac-file-search": {
      "command": "/absolute/path/to/repo/.build/debug/mcp-file-search",
      "args": []
    }
  }
}
```

### Generic MCP client entry
Add an MCP server with a stdio command pointing to the built binary:
```json
{
  "mcpServers": {
    "mac-file-search": {
      "command": "/absolute/path/to/repo/.build/debug/mcp-file-search",
      "args": [],
      "env": {}
    }
  }
}
```

## Development

### Standard Workflow
The Makefile provides the standard development workflow that matches CI:
```bash
make all             # Full workflow: clean, build, test, integration test
make build           # Build with strict concurrency checking (matches CI)
make test            # Run tests with strict concurrency checking (matches CI)
make integration-test# Run integration test script
```

### Integration Test Examples
The integration test script can be run standalone:
```bash
# Basic integration test
./test_mcp.sh --query Package.swift --filename-only --limit 5

# Directory-scoped search
./test_mcp.sh --query .swift --filename-only --only-in "$(pwd)" --limit 10
```

**Note**: Both local development and CI use the same `make` commands with identical strict concurrency checking settings. This ensures no CI surprises.

## License
MIT. See `LICENSE`.
