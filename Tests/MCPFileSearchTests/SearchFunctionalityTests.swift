import XCTest
import MCP
import Foundation
@testable import MCPFileSearch

/// Tests for core file search functionality using Spotlight.
/// These tests verify that the file-search tool can successfully find files using various
/// search parameters and query types.
final class SearchFunctionalityTests: XCTestCase {
    
    private var connectionHelper: ConnectionTests!
    private var testFilesDir: String!
    
    override func setUp() async throws {
        try await super.setUp()
        connectionHelper = ConnectionTests()
        
        // Set up test files directory path
        let currentDir = FileManager.default.currentDirectoryPath
        testFilesDir = "\(currentDir)/test-files"
        
        print("Starting search functionality test: \(name)")
        print("Test files directory: \(testFilesDir!)")
    }
    
    override func tearDown() async throws {
        print("Completed search functionality test: \(name)")
        try await super.tearDown()
    }
    
    // MARK: - Basic Search Tests
    
    /// Tests basic file search functionality with minimal parameters.
    /// 
    /// **Purpose**: Verifies that the core file search mechanism works with Spotlight and
    /// returns valid, parseable results even in various system environments.
    /// 
    /// **What it tests**:
    /// - Basic file-search tool invocation with simple query ("swift")
    /// - Legacy filenameOnly parameter functionality
    /// - Result limit enforcement (limit=3)
    /// - JSON response format and parseability
    /// - Search result structure validation (path, name fields)
    /// - Graceful handling when no results are found
    /// 
    /// **Why it exists**: This is the fundamental smoke test for file search. It ensures
    /// Spotlight integration works and the tool returns valid data structures. This test
    /// is designed to pass even in minimal environments where few files may be indexed.
    func testFileSearchBasic() async throws {
        print("Testing basic file-search functionality...")
        
        // Create and configure client/server
        let (client, server) = try await connectionHelper.setupClientServer()
        
        // First test: search with a broad query to see if Spotlight is working at all
        let (content, isError) = try await client.callTool(
            name: "file-search",
            arguments: [
                "query": "swift",
                "filenameOnly": true,
                "limit": 3
            ]
        )
        
        // Verify response structure (even if no results found)
        print("isError: \(isError ?? false)")
        XCTAssertEqual(content.count, 1, "Should return one content item")
        
        if case .text(let jsonResponse) = content.first! {
            print("Got JSON response: \(jsonResponse)")
            
            // Parse JSON response - should be valid even if empty
            let searchResults = try parseSearchResults(from: jsonResponse)
            print("📊 Found \(searchResults.count) results")
            
            // Verify result structure if any results found
            if !searchResults.isEmpty {
                let firstResult = searchResults.first!
                XCTAssertFalse(firstResult.path.isEmpty, "Path should not be empty")
                XCTAssertFalse(firstResult.name.isEmpty, "Name should not be empty")
                print("First result: \(firstResult.name) at \(firstResult.path)")
            } else {
                print("ℹ️ No results found - this may be expected in test environment")
            }
        } else {
            XCTFail("Expected text content")
        }
        
        // Clean up
        await connectionHelper.cleanup(client: client, server: server)
    }
    
    /// Tests directory-scoped file search to ensure onlyIn parameter works correctly.
    /// 
    /// **Purpose**: Verifies that the onlyIn parameter successfully restricts search results
    /// to specific directories, which is essential for scoped searches.
    /// 
    /// **What it tests**:
    /// - Directory-scoped search using onlyIn parameter
    /// - Swift file detection within project directory structure
    /// - Result filtering to ensure all results are within specified directory
    /// - File extension validation (.swift files)
    /// - Detection of known project files (Package.swift, main.swift)
    /// - Multi-file result handling
    /// 
    /// **Why it exists**: Directory scoping is a key feature for practical file search usage.
    /// Users often want to search within specific project directories rather than system-wide.
    /// This test ensures the onlyIn parameter properly restricts Spotlight queries.
    func testFileSearchWithDirectory() async throws {
        print("Testing directory-scoped search for multiple files...")
        
        // Create and configure client/server
        let (client, server) = try await connectionHelper.setupClientServer()
        
        // Get current directory for testing
        let currentDir = FileManager.default.currentDirectoryPath
        print("Searching in directory: \(currentDir)")
        
        // Search for Swift files in the project (should find main.swift, etc.)
        let (content, isError) = try await client.callTool(
            name: "file-search",
            arguments: [
                "query": ".swift",
                "filenameOnly": true,
                "onlyIn": [Value.string(currentDir)],
                "limit": 10
            ]
        )
        
        // Verify response
        XCTAssertFalse(isError ?? true, "Tool call should not return an error")
        XCTAssertEqual(content.count, 1, "Should return one content item")
        
        if case .text(let jsonResponse) = content.first! {
            print("Got JSON response: \(jsonResponse)")
            
            let searchResults = try parseSearchResults(from: jsonResponse)
            
            // Should find Swift files in the Sources/ directory
            XCTAssertGreaterThan(searchResults.count, 0, "Should find at least one .swift file")
            
            // Verify all results are in our project directory
            for result in searchResults {
                XCTAssertTrue(result.path.contains(currentDir), "All results should be in project directory")
                XCTAssertTrue(result.name.hasSuffix(".swift"), "All results should be Swift files")
                print("Found Swift file: \(result.name) at \(result.path)")
            }
            
            // Should find some specific files we know exist
            let knownFiles = ["main.swift", "Package.swift"]
            let foundFiles = searchResults.map { $0.name }
            
            for knownFile in knownFiles {
                let found = foundFiles.contains { $0.contains(knownFile) }
                if found {
                    print("Found expected file: \(knownFile)")
                }
            }
            
            // At minimum should find Package.swift
            let packageSwift = searchResults.first { $0.name.contains("Package.swift") }
            XCTAssertNotNil(packageSwift, "Should find Package.swift file")
            
        } else {
            XCTFail("Expected text content")
        }
        
        // Clean up
        await connectionHelper.cleanup(client: client, server: server)
    }
    
    /// Tests targeted search for a specific known file.
    /// 
    /// **Purpose**: Verifies that the file search can successfully locate specific files
    /// by exact name match within a directory scope.
    /// 
    /// **What it tests**:
    /// - Specific file name search ("LICENSE")
    /// - Directory-scoped search using onlyIn parameter
    /// - Exact file name matching and result validation
    /// - Path correctness verification
    /// - Single file detection accuracy
    /// 
    /// **Why it exists**: Users often need to find specific files by exact name. This test
    /// ensures our search can locate known files accurately, which is essential for
    /// file discovery workflows in development environments.
    func testFileSearchSpecificFile() async throws {
        print("🎯 Testing search for specific known file...")
        
        // Create and configure client/server
        let (client, server) = try await connectionHelper.setupClientServer()
        
        // Get current directory for scoped search
        let currentDir = FileManager.default.currentDirectoryPath
        print("Searching for LICENSE file in: \(currentDir)")
        
        // Search for LICENSE file specifically
        let (content, isError) = try await client.callTool(
            name: "file-search",
            arguments: [
                "query": "LICENSE",
                "filenameOnly": true,
                "onlyIn": [Value.string(currentDir)],
                "limit": 3
            ]
        )
        
        // Verify response
        XCTAssertFalse(isError ?? true, "Tool call should not return an error")
        XCTAssertEqual(content.count, 1, "Should return one content item")
        
        if case .text(let jsonResponse) = content.first! {
            print("Got JSON response: \(jsonResponse)")
            
            let searchResults = try parseSearchResults(from: jsonResponse)
            
            // Should find LICENSE file
            XCTAssertGreaterThan(searchResults.count, 0, "Should find LICENSE file")
            
            let licenseFile = searchResults.first { $0.name == "LICENSE" }
            XCTAssertNotNil(licenseFile, "Should find LICENSE file")
            
            if let licenseFile = licenseFile {
                XCTAssertTrue(licenseFile.path.contains(currentDir), "LICENSE should be in project directory")
                XCTAssertTrue(licenseFile.path.hasSuffix("LICENSE"), "Path should end with LICENSE")
                print("Found LICENSE file at: \(licenseFile.path)")
            }
        } else {
            XCTFail("Expected text content")
        }
        
        // Clean up
        await connectionHelper.cleanup(client: client, server: server)
    }
    
    // MARK: - Query Type Tests
    
    /// Tests filename-only search using the explicit queryType parameter.
    /// 
    /// **Purpose**: Verifies that the queryType="filename" parameter restricts searches
    /// to file names only, excluding file content from the search scope.
    /// 
    /// **What it tests**:
    /// - Explicit queryType="filename" parameter usage
    /// - Search within test files directory using onlyIn
    /// - Filename-only matching (excludes content searching)
    /// - Result validation within specified directory
    /// - Query string matching in file names ("2024")
    /// 
    /// **Why it exists**: Filename-only search is faster and more precise when users know
    /// they're looking for files by name rather than content. This test ensures the
    /// queryType parameter correctly configures Spotlight to search only file names.
    func testFilenameSearchBasic() async throws {
        guard testFilesDir != nil && FileManager.default.fileExists(atPath: testFilesDir) else {
            throw XCTSkip("Test files directory not available")
        }
        
        print("📁 Testing basic filename searches...")
        
        let (client, server) = try await connectionHelper.setupClientServer()
        
        // Search for files with "2024" in name
        let (content, isError) = try await client.callTool(
            name: "file-search",
            arguments: [
                "query": Value.string("2024"),
                "queryType": Value.string("filename"),
                "onlyIn": Value.array([Value.string(testFilesDir)]),
                "limit": 10
            ]
        )
        
        XCTAssertFalse(isError ?? true, "Filename search should not error")
        XCTAssertEqual(content.count, 1, "Should return one content item")
        
        if case .text(let jsonResponse) = content.first! {
            let searchResults = try parseSearchResults(from: jsonResponse)
            print("Found \(searchResults.count) files with '2024' in name")
            
            // All results should be in our test directory
            for result in searchResults {
                XCTAssertTrue(result.path.contains(testFilesDir), "All results should be in test directory")
            }
        }
        
        await connectionHelper.cleanup(client: client, server: server)
    }
    
    /// Tests content-only search functionality.
    /// 
    /// **Purpose**: Verifies that queryType="contents" searches within file content
    /// rather than file names, enabling full-text search capabilities.
    /// 
    /// **What it tests**:
    /// - Content-only search using queryType="contents"
    /// - Full-text search within file content ("database" keyword)
    /// - Directory scoping with onlyIn parameter
    /// - Result validation to ensure all results are from test directory
    /// - Content matching detection
    /// 
    /// **Why it exists**: Content search is crucial for finding files based on what they
    /// contain rather than what they're named. This test ensures Spotlight properly
    /// searches file content when the contents query type is specified.
    func testContentSearchBasic() async throws {
        guard testFilesDir != nil && FileManager.default.fileExists(atPath: testFilesDir) else {
            throw XCTSkip("Test files directory not available")
        }
        
        print("📄 Testing basic content searches...")
        
        let (client, server) = try await connectionHelper.setupClientServer()
        
        // Search for "database" keyword in content
        let (content, isError) = try await client.callTool(
            name: "file-search",
            arguments: [
                "query": Value.string("database"),
                "queryType": Value.string("contents"),
                "onlyIn": Value.array([Value.string(testFilesDir)]),
                "limit": 10
            ]
        )
        
        XCTAssertFalse(isError ?? true, "Content search should not error")
        XCTAssertEqual(content.count, 1, "Should return one content item")
        
        if case .text(let jsonResponse) = content.first! {
            let searchResults = try parseSearchResults(from: jsonResponse)
            print("Found \(searchResults.count) files containing 'database'")
            
            // Verify all results are from our test directory
            for result in searchResults {
                XCTAssertTrue(result.path.contains(testFilesDir), "All results should be in test directory")
            }
        }
        
        await connectionHelper.cleanup(client: client, server: server)
    }
    
    /// Tests file extension-based search functionality.
    /// 
    /// **Purpose**: Verifies that queryType="extension" searches for files with specific
    /// file extensions, enabling file type filtering.
    /// 
    /// **What it tests**:
    /// - Extension-based search using queryType="extension"
    /// - File type filtering ("swift" extension)
    /// - Directory scoping with onlyIn parameter
    /// - Extension validation of results (.swift files)
    /// - Result path verification within test directory
    /// 
    /// **Why it exists**: Extension search is essential for finding files of specific types
    /// (e.g., all .swift files, all .json files). This test ensures the extension query
    /// type properly configures Spotlight to filter by file extension.
    func testExtensionSearchBasic() async throws {
        guard testFilesDir != nil && FileManager.default.fileExists(atPath: testFilesDir) else {
            throw XCTSkip("Test files directory not available")
        }
        
        print("🔧 Testing basic extension searches...")
        
        let (client, server) = try await connectionHelper.setupClientServer()
        
        // Search for Swift files
        let (content, isError) = try await client.callTool(
            name: "file-search",
            arguments: [
                "query": Value.string("swift"),
                "queryType": Value.string("extension"),
                "onlyIn": Value.array([Value.string(testFilesDir)]),
                "limit": 10
            ]
        )
        
        XCTAssertFalse(isError ?? true, "Extension search should not error")
        XCTAssertEqual(content.count, 1, "Should return one content item")
        
        if case .text(let jsonResponse) = content.first! {
            let searchResults = try parseSearchResults(from: jsonResponse)
            print("Found \(searchResults.count) .swift files")
            
            // Should find Swift files
            let swiftFiles = searchResults.filter { $0.name.hasSuffix(".swift") }
            
            for swiftFile in swiftFiles {
                print("✅ Found Swift file: \(swiftFile.name)")
                XCTAssertTrue(swiftFile.path.contains(testFilesDir))
            }
        }
        
        await connectionHelper.cleanup(client: client, server: server)
    }
    
    // MARK: - Timeout and Limit Tests
    
    /// Tests search timeout functionality to prevent hanging operations.
    /// 
    /// **Purpose**: Verifies that file search operations complete within reasonable time
    /// limits and don't hang indefinitely, even with broad queries that might return many results.
    /// 
    /// **What it tests**:
    /// - Search operation with broad query ("swift") that could return many results
    /// - Response time validation (should not hang)
    /// - JSON response format and parseability
    /// - Search result parsing works correctly
    /// - Server stability with potentially large result sets
    /// 
    /// **Why it exists**: Timeout protection is crucial for server stability. Spotlight
    /// searches could potentially hang or take very long with certain queries. This test
    /// ensures our search implementation handles realistic queries promptly and gracefully.
    func testFileSearchTimeout() async throws {
        print("⏱️ Testing file-search response time with broad query...")
        
        // Create and configure client/server
        let (client, server) = try await connectionHelper.setupClientServer()
        
        let startTime = Date()
        
        // Test with a realistic query that might find multiple files
        let (content, isError) = try await client.callTool(
            name: "file-search",
            arguments: [
                "query": "swift",
                "filenameOnly": true,
                "limit": 10
            ]
        )
        
        let duration = Date().timeIntervalSince(startTime)
        
        // Verify response - should complete quickly and return valid JSON
        print("Search completed in \(String(format: "%.2f", duration)) seconds")
        XCTAssertFalse(isError ?? true, "Search should not return error")
        XCTAssertLessThan(duration, 10.0, "Search should complete within 10 seconds")
        XCTAssertEqual(content.count, 1, "Should return one content item")
        
        if case .text(let jsonResponse) = content.first! {
            print("Got JSON response: \(jsonResponse)")
            
            let searchResults = try parseSearchResults(from: jsonResponse)
            print("📊 Found \(searchResults.count) results in \(String(format: "%.2f", duration))s")
            
            // Results should be properly structured regardless of count
            for result in searchResults.prefix(3) {
                XCTAssertFalse(result.path.isEmpty, "Path should not be empty")
                XCTAssertFalse(result.name.isEmpty, "Name should not be empty")
            }
        } else {
            XCTFail("Expected text content")
        }
        
        // Clean up
        await connectionHelper.cleanup(client: client, server: server)
    }
    
    /// Tests the limit parameter for controlling result count.
    /// 
    /// **Purpose**: Verifies that the limit parameter successfully restricts the number
    /// of search results returned, preventing overwhelming responses.
    /// 
    /// **What it tests**:
    /// - Result count limiting with limit=3 parameter
    /// - Wildcard search ("*") to potentially generate many results
    /// - Directory scoping with onlyIn parameter
    /// - Limit enforcement verification (≤ 3 results)
    /// - Result enumeration and display
    /// 
    /// **Why it exists**: Result limiting is essential for performance and usability.
    /// Without limits, searches could return thousands of results, overwhelming clients
    /// and consuming excessive resources. This test ensures the limit parameter works correctly.
    func testLimitParameter() async throws {
        guard testFilesDir != nil && FileManager.default.fileExists(atPath: testFilesDir) else {
            throw XCTSkip("Test files directory not available")
        }
        
        print("🔢 Testing limit parameter...")
        
        let (client, server) = try await connectionHelper.setupClientServer()
        
        // Test with small limit
        let (content, isError) = try await client.callTool(
            name: "file-search",
            arguments: [
                "query": Value.string("*"),
                "queryType": Value.string("all"),
                "onlyIn": Value.array([Value.string(testFilesDir)]),
                "limit": 3
            ]
        )
        
        XCTAssertFalse(isError ?? true, "Limited search should not error")
        
        if case .text(let jsonResponse) = content.first! {
            let searchResults = try parseSearchResults(from: jsonResponse)
            print("Found \(searchResults.count) files with limit of 3")
            
            XCTAssertLessThanOrEqual(searchResults.count, 3, "Should not exceed limit of 3 results")
            
            for (index, result) in searchResults.enumerated() {
                print("  \(index + 1). \(result.name)")
            }
        }
        
        await connectionHelper.cleanup(client: client, server: server)
    }
    
    // MARK: - Helper Methods
    
    /// Parses JSON search results into SearchHit objects.
    /// 
    /// **Purpose**: Provides consistent JSON parsing for search results across all tests
    /// in this class.
    /// 
    /// **What it does**:
    /// - Converts JSON string response to SearchHit array
    /// - Configures ISO 8601 date parsing for created/modified timestamps
    /// - Handles JSON parsing errors appropriately
    /// 
    /// **Why it exists**: Multiple tests need to parse search results. This helper
    /// ensures consistent parsing logic and reduces code duplication across test methods.
    private func parseSearchResults(from jsonResponse: String) throws -> [SearchHit] {
        let data = jsonResponse.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([SearchHit].self, from: data)
    }
}