# MCP File Search Server Tests

This directory contains the comprehensive test suite for the MCP File Search Server, a Swift-based Model Context Protocol (MCP) server that provides Spotlight-backed file search functionality on macOS.

## Test Overview

The test suite consists of 6 test classes that cover all aspects of the server functionality:

- **ConnectionTests** - MCP protocol connection and server lifecycle
- **IntegrationTests** - End-to-end testing with real server processes
- **SearchFunctionalityTests** - Core file search capabilities
- **SortingAndFilteringTests** - Advanced search features and result processing
- **ToolTests** - MCP tool discovery and validation
- **TypeSystemTests** - Data types and serialization

## Test Execution

Run tests using the standard Swift test commands:

```bash
# Run all tests
make test

# Run specific test class
swift test --filter ConnectionTests

# Run specific test method
swift test --filter ConnectionTests.testServerConnection
```

---

## ConnectionTests

Tests for MCP client/server connection establishment and basic protocol functionality. These tests verify that the core MCP transport layer and connection lifecycle work correctly.

### testServerConnection()

**Purpose**: Verifies that our file search server can properly initialize, configure handlers, establish client connections, and advertise its capabilities through the MCP protocol.

**What it tests**:
- Server creation and configuration with file-search tool handlers
- In-memory transport creation and pairing for test isolation
- MCP protocol initialization handshake between client and server
- Server capability advertisement (tools capability should be present)
- Server metadata verification (name: "mac-file-search", version: "0.1.0")
- Clean connection teardown and resource cleanup

**Why it exists**: This is a fundamental integration test ensuring our server can participate in the MCP ecosystem correctly. Without this working, clients couldn't discover or use our file search functionality.

### Helper Methods

#### setupClientServer()
Creates and configures a connected MCP client/server pair for testing. Provides a reusable setup method for tests that need a fully configured and connected MCP client/server pair with file search capabilities.

#### cleanup()
Properly disconnects and cleans up a client/server pair to prevent resource leaks and test interference.

---

## IntegrationTests

End-to-end integration tests using real server processes and JSON-RPC communication. These tests verify that the complete system works as a standalone MCP server by launching the actual executable and communicating via stdin/stdout JSON-RPC.

### testServerInitialization()

**Purpose**: Verifies that the server can be launched, initialized via MCP protocol, and returns correct server information and capabilities.

**What it tests**:
- Real server process startup and readiness
- MCP initialization handshake via JSON-RPC
- Server info response (name: "mac-file-search", version)
- Server capabilities advertisement (tools capability)
- Complete protocol compliance for initialization

**Why it exists**: This is the fundamental integration test ensuring our server works as a real MCP server that clients can discover and connect to.

### testServerToolListing()

**Purpose**: Verifies that the server properly advertises its available tools through the standard MCP tool discovery mechanism.

**What it tests**:
- Server initialization followed by tool listing
- MCP tools/list request/response cycle
- Tool metadata in response (file-search tool presence)
- Complete JSON-RPC protocol compliance for tool discovery
- Tool schema and description availability

**Why it exists**: Tool discovery is essential for MCP clients to know what functionality is available.

### testServerFileSearch()

**Purpose**: Verifies that the complete file search workflow works end-to-end with real Spotlight queries and JSON-RPC communication.

**What it tests**:
- Complete MCP initialization and tool calling workflow
- Real file search execution with Spotlight integration
- Search parameter handling (query, filenameOnly, limit)
- JSON response format and search result structure
- Actual file discovery (Package.swift files)

**Why it exists**: This is the core functionality test ensuring the entire system works together.

### testServerSearchInDirectory()

**Purpose**: Verifies that directory-scoped searches work correctly through the complete MCP protocol stack with real Spotlight queries.

**What it tests**:
- Directory-scoped search using onlyIn parameter
- Real Spotlight query with directory restrictions
- Specific file discovery (main.swift in Sources directory)
- Path validation in search results
- Complete integration of scoped search functionality

**Why it exists**: Directory scoping is a critical feature for practical file search usage.

### testServerErrorHandling()

**Purpose**: Verifies that the server handles invalid requests gracefully and returns proper error responses through the MCP protocol.

**What it tests**:
- Invalid tool name handling via JSON-RPC
- Proper error response format (isError flag)
- Error message content ("Unknown tool")
- Server stability after receiving invalid requests
- Complete error handling through the protocol stack

**Why it exists**: Robust error handling is essential for production MCP servers.

### Helper Methods

#### buildServerIfNeeded()
Ensures the server binary is available for integration testing by building it automatically when needed.

#### startServer()
Launches the MCP server as a separate process with pipe communication for real JSON-RPC testing.

#### stopServer()
Gracefully terminates the server process and cleans up resources.

#### sendJSONRPCRequest()
Provides the core communication mechanism for integration tests by handling JSON-RPC request/response cycles over stdin/stdout pipes.

---

## SearchFunctionalityTests

Tests for core file search functionality using Spotlight. These tests verify that the file-search tool can successfully find files using various search parameters and query types.

### testFileSearchBasic()

**Purpose**: Verifies that the core file search mechanism works with Spotlight and returns valid, parseable results even in various system environments.

**What it tests**:
- Basic file-search tool invocation with simple query ("swift")
- Legacy filenameOnly parameter functionality
- Result limit enforcement (limit=3)
- JSON response format and parseability
- Search result structure validation (path, name fields)
- Graceful handling when no results are found

**Why it exists**: This is the fundamental smoke test for file search.

### testFileSearchWithDirectory()

**Purpose**: Verifies that the onlyIn parameter successfully restricts search results to specific directories.

**What it tests**:
- Directory-scoped search using onlyIn parameter
- Swift file detection within project directory structure
- Result filtering to ensure all results are within specified directory
- File extension validation (.swift files)
- Detection of known project files (Package.swift, main.swift)
- Multi-file result handling

**Why it exists**: Directory scoping is a key feature for practical file search usage.

### testFileSearchSpecificFile()

**Purpose**: Verifies that the file search can successfully locate specific files by exact name match within a directory scope.

**What it tests**:
- Specific file name search ("LICENSE")
- Directory-scoped search using onlyIn parameter
- Exact file name matching and result validation
- Path correctness verification
- Single file detection accuracy

**Why it exists**: Users often need to find specific files by exact name.

### testFilenameSearchBasic()

**Purpose**: Verifies that the queryType="filename" parameter restricts searches to file names only, excluding file content from the search scope.

**What it tests**:
- Explicit queryType="filename" parameter usage
- Search within test files directory using onlyIn
- Filename-only matching (excludes content searching)
- Result validation within specified directory
- Query string matching in file names ("2024")

**Why it exists**: Filename-only search is faster and more precise when users know they're looking for files by name rather than content.

### testContentSearchBasic()

**Purpose**: Verifies that queryType="contents" searches within file content rather than file names, enabling full-text search capabilities.

**What it tests**:
- Content-only search using queryType="contents"
- Full-text search within file content ("database" keyword)
- Directory scoping with onlyIn parameter
- Result validation to ensure all results are from test directory
- Content matching detection

**Why it exists**: Content search is crucial for finding files based on what they contain rather than what they're named.

### testExtensionSearchBasic()

**Purpose**: Verifies that queryType="extension" searches for files with specific file extensions, enabling file type filtering.

**What it tests**:
- Extension-based search using queryType="extension"
- File type filtering ("swift" extension)
- Directory scoping with onlyIn parameter
- Extension validation of results (.swift files)
- Result path verification within test directory

**Why it exists**: Extension search is essential for finding files of specific types.

### testFileSearchTimeout()

**Purpose**: Verifies that file search operations complete within reasonable time limits and don't hang indefinitely, even with broad queries that might return many results.

**What it tests**:
- Search operation with broad query ("swift") that could return many results
- Response time validation (should not hang)
- JSON response format and parseability
- Search result parsing works correctly
- Server stability with potentially large result sets

**Why it exists**: Timeout protection is crucial for server stability.

### testLimitParameter()

**Purpose**: Verifies that the limit parameter successfully restricts the number of search results returned, preventing overwhelming responses.

**What it tests**:
- Result count limiting with limit=3 parameter
- Wildcard search ("*") to potentially generate many results
- Directory scoping with onlyIn parameter
- Limit enforcement verification (≤ 3 results)
- Result enumeration and display

**Why it exists**: Result limiting is essential for performance and usability.

---

## SortingAndFilteringTests

Tests for advanced search features including sorting, filtering, and complex query combinations. These tests verify that search results can be properly sorted and filtered using various parameters.

### testSortingByName()

**Purpose**: Verifies that the sortBy="name" and sortOrder="ascending" parameters correctly order search results alphabetically by filename.

**What it tests**:
- sortBy="name" parameter functionality
- sortOrder="ascending" parameter functionality
- Alphabetical sorting of file names
- Sort order verification (names should be in alphabetical order)
- Directory-scoped search with sorting

**Why it exists**: Name-based sorting is one of the most common ways users expect to organize search results.

### testSortingByDate()

**Purpose**: Verifies that search results can be sorted by file modification date, with the most recently modified files appearing first.

**What it tests**:
- sortBy="dateModified" parameter functionality
- sortOrder="descending" parameter functionality
- Date-based sorting (newest first)
- Date comparison and ordering validation
- Metadata extraction for modification dates

**Why it exists**: Date-based sorting helps users find recently modified files first.

### testSortingBySize()

**Purpose**: Verifies that search results can be sorted by file size, with the largest files appearing first.

**What it tests**:
- sortBy="size" parameter functionality
- sortOrder="descending" parameter functionality
- File size-based sorting (largest first)
- Size comparison and ordering validation
- Metadata extraction for file sizes

**Why it exists**: Size-based sorting helps users find large files that might be taking up disk space.

### testAllQueryTypeSearch()

**Purpose**: Verifies that queryType="all" performs comprehensive searches across both file names and file content simultaneously.

**What it tests**:
- queryType="all" parameter functionality
- Combined filename and content searching
- Search term matching in both names and content
- Result diversity from different match types
- File extension analysis of results
- Directory-scoped comprehensive search

**Why it exists**: The "all" query type is the most comprehensive search mode.

### testFilenameSearchWithLegacyParameter()

**Purpose**: Verifies that the legacy filenameOnly=true parameter still works for clients that haven't upgraded to the newer queryType parameter.

**What it tests**:
- Legacy filenameOnly=true parameter functionality
- Backward compatibility with older clients
- Filename-only search behavior with legacy parameter
- Directory scoping with legacy parameter
- Result validation within test directory

**Why it exists**: We maintain backward compatibility with existing clients.

### testContentSearchSpecificKeywords()

**Purpose**: Verifies that content search can find files containing specific multi-word phrases within their text content.

**What it tests**:
- Multi-word content search ("machine learning")
- Phrase matching within file content
- queryType="contents" with complex phrases
- Directory scoping for content searches
- Result validation within test directory

**Why it exists**: Users often search for specific phrases or technical terms within files.

### testExtensionSearchMultipleTypes()

**Purpose**: Verifies that extension search can find multiple files of a specific type and that the results actually have the expected file extensions.

**What it tests**:
- Extension search for JSON files (queryType="extension", query="json")
- Multiple file detection of the same type
- File extension validation (.json)
- Expected file discovery (config.json, sample-data.json)
- Directory scoping for extension searches

**Why it exists**: Extension-based searching is crucial for finding all files of a particular type.

### testTimeoutParameter()

**Purpose**: Verifies that searches complete within specified timeout limits and don't exceed reasonable execution times.

**What it tests**:
- timeoutSeconds parameter functionality
- Search execution time measurement
- Timeout enforcement (should complete within 5 seconds)
- Result quality within time constraints
- Server stability with timeout limits

**Why it exists**: Timeout protection prevents searches from hanging indefinitely.

### testInvalidQueryType()

**Purpose**: Verifies that the server properly handles invalid queryType values by either returning an error or gracefully falling back to default behavior.

**What it tests**:
- Invalid queryType value handling ("invalid-type")
- Server error response or graceful fallback behavior
- Server stability with bad parameters
- Proper error reporting or default behavior consistency
- Response format validation for error cases

**Why it exists**: Clients might send invalid parameters due to bugs or API misuse.

---

## ToolTests

Tests for MCP tool discovery, validation, and error handling. These tests verify that tools are properly registered, discoverable, and handle invalid requests correctly.

### testListTools()

**Purpose**: Verifies that our file search server properly advertises its available tools through the MCP protocol's standardized tool discovery mechanism.

**What it tests**:
- Tool listing via MCP ListTools request/response
- Correct tool count (should be exactly 1 tool: file-search)
- Tool metadata verification (name, description, input schema)
- Tool name matches expected "file-search"
- Tool description is properly set and informative
- Input schema is present and properly structured

**Why it exists**: Tool discovery is fundamental to MCP - clients need to know what tools are available before they can use them.

### testInvalidToolName()

**Purpose**: Verifies that our server properly handles and reports errors when clients attempt to call tools that don't exist.

**What it tests**:
- Invalid tool name handling via MCP CallTool request
- Proper error response format (isError flag should be true)
- Error message content (should indicate "Unknown tool")
- Server remains stable after invalid requests
- Error response follows MCP protocol standards

**Why it exists**: Error handling is crucial for a robust MCP server.

---

## TypeSystemTests

Tests for data types, enums, and serialization used in the file search system. These tests verify that our type system works correctly and maintains compatibility across JSON serialization boundaries.

### testQueryTypeEnum()

**Purpose**: Verifies that QueryType enum has correct raw string values that match what clients expect in the MCP protocol.

**What it tests**:
- All QueryType enum cases have correct raw string values
- "extension" -> QueryType.extension
- "contents" -> QueryType.contents
- "filename" -> QueryType.filename
- "all" -> QueryType.all

**Why it exists**: The QueryType enum is serialized to JSON and sent over the MCP protocol.

### testSortOptionEnum()

**Purpose**: Verifies that SortOption enum has correct raw string values for client-server communication via MCP protocol.

**What it tests**:
- All SortOption enum cases have correct raw string values
- "name" -> SortOption.name
- "dateModified" -> SortOption.dateModified
- "dateCreated" -> SortOption.dateCreated
- "size" -> SortOption.size

**Why it exists**: SortOption values are sent by clients to specify how search results should be ordered.

### testSortOrderEnum()

**Purpose**: Verifies that SortOrder enum has correct raw string values for specifying ascending vs descending sort order.

**What it tests**:
- All SortOrder enum cases have correct raw string values
- "ascending" -> SortOrder.ascending
- "descending" -> SortOrder.descending

**Why it exists**: Sort order specification must be consistent between client and server.

### testSearchArgsInitWithFilenameOnly()

**Purpose**: Verifies backward compatibility logic where the legacy filenameOnly parameter automatically sets the queryType to .filename.

**What it tests**:
- filenameOnly=true automatically sets queryType=.filename
- filenameOnly=false doesn't override explicit queryType
- filenameOnly=nil doesn't affect explicit queryType
- Backward compatibility with older client code
- Proper precedence between legacy and new parameters

**Why it exists**: We maintain backward compatibility with older clients that use the filenameOnly boolean parameter.

### testSearchArgsWithAllParameters()

**Purpose**: Verifies that SearchArgs can be initialized with the full set of parameters and maintains all values correctly.

**What it tests**:
- All SearchArgs properties can be set and retrieved correctly
- query, queryType, extensions, onlyIn parameters
- dateFilter with from/to date ranges
- sortBy, sortOrder, and limit parameters
- Complex object initialization and property access
- DateFilter nested object handling

**Why it exists**: SearchArgs is the primary data transfer object for search requests.

### testSearchHitProperties()

**Purpose**: Verifies that SearchHit objects correctly store and provide access to all file metadata properties.

**What it tests**:
- All SearchHit properties can be set and retrieved correctly
- path, name, kind properties (strings)
- size property (integer)
- created and modified properties (Date objects)
- Object initialization and property access

**Why it exists**: SearchHit is the primary data structure for search results returned to clients.

### testSearchArgsCodable()

**Purpose**: Verifies that SearchArgs can be correctly encoded to and decoded from JSON, ensuring compatibility with MCP protocol data exchange.

**What it tests**:
- JSON encoding of complete SearchArgs object
- JSON decoding back to SearchArgs object
- Data integrity across encode/decode cycle
- All property types (strings, arrays, enums, nested objects)
- Complex nested object handling (DateFilter)
- Enum serialization (queryType, sortBy, sortOrder)

**Why it exists**: SearchArgs objects are sent from MCP clients as JSON.

### testDateFilterCodable()

**Purpose**: Verifies that DateFilter objects can be correctly encoded to and decoded from JSON as part of SearchArgs date filtering functionality.

**What it tests**:
- JSON encoding of DateFilter object
- JSON decoding back to DateFilter object
- Date object serialization and deserialization
- Data integrity across encode/decode cycle
- from and to Date properties

**Why it exists**: DateFilter is a nested object within SearchArgs that contains Date objects.

---

## Test Dependencies

The test suite relies on several key frameworks and utilities:

- **XCTest** - Swift's standard testing framework
- **MCP** - Model Context Protocol Swift SDK for client/server communication
- **Foundation** - Core Swift framework for data structures and utilities
- **Logging** - Swift logging framework for debug output
- **@testable import MCPFileSearch** - Access to internal implementation details

## Test Data

Some tests reference a `test-files` directory that should contain sample files for more comprehensive testing scenarios. Tests will skip gracefully if this directory is not available.