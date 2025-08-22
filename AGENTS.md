# Agent Guidelines for MCP File Search Server

## Build/Test/Lint Commands
**Standard unified commands (used by both local dev and CI):**
- **Full Workflow**: `make all` - Clean, build, test, integration test (recommended)
- **Build**: `make build` - Builds with strict concurrency checking
- **Test All**: `make test` - Runs the full test suite with strict concurrency
- **Integration Test**: `make integration-test` - Tests MCP server via JSON-RPC  
- **Clean**: `make clean` - Clean build artifacts

**Individual Swift commands (for advanced use):**
- **Test Single**: `swift test --filter <TestClassName>.<testMethodName>` - Run specific test method
- **Direct Build**: `swift build` - Standard build without strict concurrency
- **Direct Test**: `swift test` - Standard tests without strict concurrency

**No linting tools configured** - Follow Swift standard formatting

## Project Structure
- **Target**: Swift Package Manager executable for macOS 13+ 
- **Main Module**: `MCPFileSearch` - MCP server implementing Spotlight-based file search
- **Dependencies**: MCP Swift SDK, CoreServices, Foundation frameworks
- **Binary Location**: `.build/debug/mcp-file-search` after build

## Integration Testing
- **Standard**: `make integration-test` - Runs the complete integration test (recommended)
- **Script**: `./test_mcp.sh` sends JSON-RPC over stdio to the built server.
- **Auto-build**: The script will build if missing using `make build`.
- **Common usage**:
  - Standard integration test: `make integration-test`
  - Initialize + list tools + call search: `./test_mcp.sh --query Package.swift --filename-only --limit 5`
  - Directory-scoped search: `./test_mcp.sh --query .swift --filename-only --only-in "$(pwd)" --limit 10`
  - Init only: `MODE=init ./test_mcp.sh --init-only`
  - Tools only: `MODE=tools ./test_mcp.sh --tools-only`
  - Call only: `MODE=call ./test_mcp.sh --call-only --query README --only-in /path/to/dir`

## Code Style Guidelines
- **Language**: Swift 5.9+ with async/await patterns
- **Imports**: Foundation first, then MCP, then platform-specific (`#if os(macOS)`)
- **Types**: Use explicit public/internal access control, prefer structs for data models
- **Naming**: CamelCase for types, camelCase for variables/functions, descriptive names
- **Error Handling**: Use throwing functions and proper error propagation with `fputs` for stderr
- **Async**: Use `async/await`, avoid completion handlers, use `Task` for async entry points
- **JSON**: Use `Codable` protocol for MCP message serialization
- **Platform**: Use conditional compilation for cross-platform compatibility

## NSMetadataQuery Reference

### Core Classes
- **NSMetadataQuery**: Main class for performing Spotlight searches
- **NSMetadataItem**: Represents metadata for a file/item
- **NSMetadataQueryDelegate**: Protocol for handling query events
- **NSMetadataQueryResultGroup**: Grouped search results

### Essential Properties
```swift
var searchScopes: [Any]           // Search directories/scopes
var predicate: NSPredicate?       // Search criteria
var sortDescriptors: [NSSortDescriptor]  // Result sorting
var valueListAttributes: [String] // Attributes to collect values for
var delegate: (any NSMetadataQueryDelegate)? // Event handler
var notificationBatchingInterval: TimeInterval // Update frequency
```

### Control Methods
```swift
func start() -> Bool              // Start the query
func stop()                       // Stop the query  
var isStarted: Bool               // Query state
var isGathering: Bool             // Initial gathering phase
var isStopped: Bool               // Query stopped
```

### Results Access
```swift
var results: [Any]               // All results array
var resultCount: Int             // Number of results
func result(at: Int) -> Any      // Get result by index
var groupedResults: [NSMetadataQueryResultGroup] // Hierarchical results
func value(ofAttribute: String, forResultAt: Int) -> Any? // Get attribute value
```

### Notifications
```swift
NSMetadataQueryDidStartGathering    // Query started
NSMetadataQueryGatheringProgress    // Progress updates
NSMetadataQueryDidFinishGathering   // Initial gathering complete
NSMetadataQueryDidUpdate           // Live updates during monitoring
```

### Common Metadata Keys
```swift
NSMetadataItemFSName               // File name
NSMetadataItemPath                 // Full file path
NSMetadataItemFSSize               // File size
NSMetadataItemFSCreationDate       // Creation date
NSMetadataItemFSContentChangeDate  // Modification date
NSMetadataItemContentType          // UTI content type
NSMetadataItemDisplayName          // Display name
NSMetadataItemTextContent          // Text content for search
```

### Example Usage Pattern
```swift
let query = NSMetadataQuery()
query.searchScopes = [NSMetadataQueryLocalComputerScope]
query.predicate = NSPredicate(format: "kMDItemFSName LIKE '*example*'")

NotificationCenter.default.addObserver(
    forName: .NSMetadataQueryDidFinishGathering,
    object: query,
    queue: .main
) { _ in
    query.disableUpdates()
    // Process results
    for i in 0..<query.resultCount {
        let item = query.result(at: i) as! NSMetadataItem
        // Access metadata
    }
    query.enableUpdates()
}

query.start()
```
