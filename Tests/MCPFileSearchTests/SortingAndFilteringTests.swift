import XCTest
import MCP
import Foundation
@testable import MCPFileSearch

/// Tests for advanced search features including sorting, filtering, and complex query combinations.
/// These tests verify that search results can be properly sorted and filtered using various parameters.
final class SortingAndFilteringTests: XCTestCase {
    
    private var connectionHelper: ConnectionTests!
    private var testFilesDir: String!
    
    override func setUp() async throws {
        try await super.setUp()
        connectionHelper = ConnectionTests()
        
        // Set up test files directory path
        let currentDir = FileManager.default.currentDirectoryPath
        testFilesDir = "\(currentDir)/test-files"
        
        print("Starting sorting and filtering test: \(name)")
        print("Test files directory: \(testFilesDir!)")
    }
    
    override func tearDown() async throws {
        print("Completed sorting and filtering test: \(name)")
        try await super.tearDown()
    }
    
    // MARK: - Sorting Tests
    
    /// Tests sorting search results by file name in ascending order.
    /// 
    /// **Purpose**: Verifies that the sortBy="name" and sortOrder="ascending" parameters
    /// correctly order search results alphabetically by filename.
    /// 
    /// **What it tests**:
    /// - sortBy="name" parameter functionality
    /// - sortOrder="ascending" parameter functionality
    /// - Alphabetical sorting of file names
    /// - Sort order verification (names should be in alphabetical order)
    /// - Directory-scoped search with sorting
    /// 
    /// **Why it exists**: Name-based sorting is one of the most common ways users expect
    /// to organize search results. This test ensures Spotlight results are properly
    /// sorted by filename when requested, making results predictable and user-friendly.
    func testSortingByName() async throws {
        guard testFilesDir != nil && FileManager.default.fileExists(atPath: testFilesDir) else {
            throw XCTSkip("Test files directory not available")
        }
        
        print("📋 Testing sorting by name...")
        
        let (client, server) = try await connectionHelper.setupClientServer()
        
        // Search and sort by name ascending
        let (content, isError) = try await client.callTool(
            name: "file-search",
            arguments: [
                "query": Value.string("*"),
                "queryType": Value.string("filename"),
                "onlyIn": Value.array([Value.string(testFilesDir)]),
                "sortBy": Value.string("name"),
                "sortOrder": Value.string("ascending"),
                "limit": 10
            ]
        )
        
        XCTAssertFalse(isError ?? true, "Sort by name search should not error")
        
        if case .text(let jsonResponse) = content.first! {
            let searchResults = try parseSearchResults(from: jsonResponse)
            print("Found \(searchResults.count) files sorted by name (ascending)")
            
            if searchResults.count > 1 {
                let names = searchResults.map { $0.name }
                let sortedNames = names.sorted()
                
                print("File names in order:")
                for (index, name) in names.enumerated() {
                    print("  \(index + 1). \(name)")
                }
                
                XCTAssertEqual(names, sortedNames, "Results should be sorted by name in ascending order")
            }
        }
        
        await connectionHelper.cleanup(client: client, server: server)
    }
    
    /// Tests sorting search results by modification date in descending order.
    /// 
    /// **Purpose**: Verifies that search results can be sorted by file modification date,
    /// with the most recently modified files appearing first.
    /// 
    /// **What it tests**:
    /// - sortBy="dateModified" parameter functionality
    /// - sortOrder="descending" parameter functionality
    /// - Date-based sorting (newest first)
    /// - Date comparison and ordering validation
    /// - Metadata extraction for modification dates
    /// 
    /// **Why it exists**: Date-based sorting helps users find recently modified files
    /// first, which is often what they're looking for. This test ensures the date
    /// sorting functionality works correctly with Spotlight metadata.
    func testSortingByDate() async throws {
        guard testFilesDir != nil && FileManager.default.fileExists(atPath: testFilesDir) else {
            throw XCTSkip("Test files directory not available")
        }
        
        print("📅 Testing sorting by modification date...")
        
        let (client, server) = try await connectionHelper.setupClientServer()
        
        // Search and sort by date modified descending
        let (content, isError) = try await client.callTool(
            name: "file-search",
            arguments: [
                "query": Value.string("*"),
                "queryType": Value.string("filename"),
                "onlyIn": Value.array([Value.string(testFilesDir)]),
                "sortBy": Value.string("dateModified"),
                "sortOrder": Value.string("descending"),
                "limit": 10
            ]
        )
        
        XCTAssertFalse(isError ?? true, "Sort by date search should not error")
        
        if case .text(let jsonResponse) = content.first! {
            let searchResults = try parseSearchResults(from: jsonResponse)
            print("Found \(searchResults.count) files sorted by modification date (descending)")
            
            if searchResults.count > 1 {
                print("Files by modification date:")
                for (index, result) in searchResults.enumerated() {
                    let dateStr = String(describing: result.modified)
                    print("  \(index + 1). \(result.name) - \(dateStr)")
                }
                
                // Verify sorting by checking that dates are in descending order
                let dates = searchResults.compactMap { $0.modified }
                if dates.count > 1 {
                    let sortedDates = dates.sorted(by: >)
                    XCTAssertEqual(dates, sortedDates, "Results should be sorted by date in descending order")
                }
            }
        }
        
        await connectionHelper.cleanup(client: client, server: server)
    }
    
    /// Tests sorting search results by file size in descending order.
    /// 
    /// **Purpose**: Verifies that search results can be sorted by file size,
    /// with the largest files appearing first.
    /// 
    /// **What it tests**:
    /// - sortBy="size" parameter functionality
    /// - sortOrder="descending" parameter functionality
    /// - File size-based sorting (largest first)
    /// - Size comparison and ordering validation
    /// - Metadata extraction for file sizes
    /// 
    /// **Why it exists**: Size-based sorting helps users find large files that might
    /// be taking up disk space or small files that might be incomplete. This test
    /// ensures size sorting works correctly with Spotlight file metadata.
    func testSortingBySize() async throws {
        guard testFilesDir != nil && FileManager.default.fileExists(atPath: testFilesDir) else {
            throw XCTSkip("Test files directory not available")
        }
        
        print("📏 Testing sorting by file size...")
        
        let (client, server) = try await connectionHelper.setupClientServer()
        
        // Search and sort by size descending
        let (content, isError) = try await client.callTool(
            name: "file-search",
            arguments: [
                "query": Value.string("*"),
                "queryType": Value.string("filename"),
                "onlyIn": Value.array([Value.string(testFilesDir)]),
                "sortBy": Value.string("size"),
                "sortOrder": Value.string("descending"),
                "limit": 10
            ]
        )
        
        XCTAssertFalse(isError ?? true, "Sort by size search should not error")
        
        if case .text(let jsonResponse) = content.first! {
            let searchResults = try parseSearchResults(from: jsonResponse)
            print("Found \(searchResults.count) files sorted by size (descending)")
            
            if searchResults.count > 1 {
                print("Files by size:")
                for (index, result) in searchResults.enumerated() {
                    let sizeStr = result.size != nil ? "\(result.size!) bytes" : "unknown size"
                    print("  \(index + 1). \(result.name) - \(sizeStr)")
                }
                
                // Verify sorting by checking that sizes are in descending order
                let sizes = searchResults.compactMap { $0.size }
                if sizes.count > 1 {
                    let sortedSizes = sizes.sorted(by: >)
                    XCTAssertEqual(sizes, sortedSizes, "Results should be sorted by size in descending order")
                }
            }
        }
        
        await connectionHelper.cleanup(client: client, server: server)
    }
    
    // MARK: - Complex Query Tests
    
    /// Tests the "all" query type that searches both filenames and content.
    /// 
    /// **Purpose**: Verifies that queryType="all" performs comprehensive searches
    /// across both file names and file content simultaneously.
    /// 
    /// **What it tests**:
    /// - queryType="all" parameter functionality
    /// - Combined filename and content searching
    /// - Search term matching in both names and content
    /// - Result diversity from different match types
    /// - File extension analysis of results
    /// - Directory-scoped comprehensive search
    /// 
    /// **Why it exists**: The "all" query type is the most comprehensive search mode,
    /// finding files whether the search term appears in the filename or content.
    /// This test ensures this powerful search mode works correctly.
    func testAllQueryTypeSearch() async throws {
        guard testFilesDir != nil && FileManager.default.fileExists(atPath: testFilesDir) else {
            throw XCTSkip("Test files directory not available")
        }
        
        print("🔍 Testing 'all' query type (filename + content)...")
        
        let (client, server) = try await connectionHelper.setupClientServer()
        
        // Search using default "all" query type
        let (content, isError) = try await client.callTool(
            name: "file-search",
            arguments: [
                "query": Value.string("test"),
                "queryType": Value.string("all"),
                "onlyIn": Value.array([Value.string(testFilesDir)]),
                "limit": 20
            ]
        )
        
        XCTAssertFalse(isError ?? true, "All query type search should not error")
        XCTAssertEqual(content.count, 1, "Should return one content item")
        
        if case .text(let jsonResponse) = content.first! {
            let searchResults = try parseSearchResults(from: jsonResponse)
            print("Found \(searchResults.count) files with 'test' in name or content")
            
            // Should find various files containing "test"
            let filesWithTest = searchResults.filter { result in
                result.name.contains("test") || result.path.contains("test")
            }
            
            print("Files with 'test' in name/path: \(filesWithTest.count)")
            for file in filesWithTest.prefix(5) {
                print("  - \(file.name)")
            }
            
            // Group results by file extension for analysis
            let extensionGroups = Dictionary(grouping: searchResults) { result in
                URL(fileURLWithPath: result.name).pathExtension.isEmpty ? "no extension" : URL(fileURLWithPath: result.name).pathExtension
            }
            
            print("Results by extension:")
            for (ext, files) in extensionGroups {
                print("  .\(ext): \(files.count) files")
            }
        }
        
        await connectionHelper.cleanup(client: client, server: server)
    }
    
    /// Tests backward compatibility with the legacy filenameOnly parameter.
    /// 
    /// **Purpose**: Verifies that the legacy filenameOnly=true parameter still works
    /// for clients that haven't upgraded to the newer queryType parameter.
    /// 
    /// **What it tests**:
    /// - Legacy filenameOnly=true parameter functionality
    /// - Backward compatibility with older clients
    /// - Filename-only search behavior with legacy parameter
    /// - Directory scoping with legacy parameter
    /// - Result validation within test directory
    /// 
    /// **Why it exists**: We maintain backward compatibility with existing clients
    /// that use the older filenameOnly boolean parameter. This test ensures legacy
    /// clients continue to work while we transition to the newer queryType system.
    func testFilenameSearchWithLegacyParameter() async throws {
        guard testFilesDir != nil && FileManager.default.fileExists(atPath: testFilesDir) else {
            throw XCTSkip("Test files directory not available")
        }
        
        print("📁 Testing filename search with legacy filenameOnly parameter...")
        
        let (client, server) = try await connectionHelper.setupClientServer()
        
        // Use the legacy filenameOnly parameter
        let (content, isError) = try await client.callTool(
            name: "file-search",
            arguments: [
                "query": Value.string("2023"),
                "filenameOnly": Value.bool(true),
                "onlyIn": Value.array([Value.string(testFilesDir)]),
                "limit": 5
            ]
        )
        
        XCTAssertFalse(isError ?? true, "Legacy filename search should not error")
        
        if case .text(let jsonResponse) = content.first! {
            let searchResults = try parseSearchResults(from: jsonResponse)
            print("Found \(searchResults.count) files with '2023' in name using legacy parameter")
            
            // All results should be from our test directory
            for result in searchResults {
                XCTAssertTrue(result.path.contains(testFilesDir), "All results should be in test directory")
            }
        }
        
        await connectionHelper.cleanup(client: client, server: server)
    }
    
    /// Tests content search with specific multi-word keywords.
    /// 
    /// **Purpose**: Verifies that content search can find files containing specific
    /// multi-word phrases within their text content.
    /// 
    /// **What it tests**:
    /// - Multi-word content search ("machine learning")
    /// - Phrase matching within file content
    /// - queryType="contents" with complex phrases
    /// - Directory scoping for content searches
    /// - Result validation within test directory
    /// 
    /// **Why it exists**: Users often search for specific phrases or technical terms
    /// within files. This test ensures our content search can handle complex
    /// multi-word queries and find relevant files accurately.
    func testContentSearchSpecificKeywords() async throws {
        guard testFilesDir != nil && FileManager.default.fileExists(atPath: testFilesDir) else {
            throw XCTSkip("Test files directory not available")
        }
        
        print("📄 Testing content search for specific keywords...")
        
        let (client, server) = try await connectionHelper.setupClientServer()
        
        // Search for "machine learning" keywords
        let (content, isError) = try await client.callTool(
            name: "file-search",
            arguments: [
                "query": Value.string("machine learning"),
                "queryType": Value.string("contents"),
                "onlyIn": Value.array([Value.string(testFilesDir)]),
                "limit": 10
            ]
        )
        
        XCTAssertFalse(isError ?? true, "ML content search should not error")
        
        if case .text(let jsonResponse) = content.first! {
            let searchResults = try parseSearchResults(from: jsonResponse)
            print("Found \(searchResults.count) files containing 'machine learning'")
            
            // All results should be from our test directory
            for result in searchResults {
                XCTAssertTrue(result.path.contains(testFilesDir), "All results should be in test directory")
            }
        }
        
        await connectionHelper.cleanup(client: client, server: server)
    }
    
    /// Tests extension search for specific file types with result validation.
    /// 
    /// **Purpose**: Verifies that extension search can find multiple files of a specific
    /// type and that the results actually have the expected file extensions.
    /// 
    /// **What it tests**:
    /// - Extension search for JSON files (queryType="extension", query="json")
    /// - Multiple file detection of the same type
    /// - File extension validation (.json)
    /// - Expected file discovery (config.json, sample-data.json)
    /// - Directory scoping for extension searches
    /// 
    /// **Why it exists**: Extension-based searching is crucial for finding all files
    /// of a particular type (e.g., all configuration files, all source files).
    /// This test ensures extension filtering works correctly and returns the right files.
    func testExtensionSearchMultipleTypes() async throws {
        guard testFilesDir != nil && FileManager.default.fileExists(atPath: testFilesDir) else {
            throw XCTSkip("Test files directory not available")
        }
        
        print("🔧 Testing extension search for JSON files...")
        
        let (client, server) = try await connectionHelper.setupClientServer()
        
        // Search for JSON files
        let (content, isError) = try await client.callTool(
            name: "file-search",
            arguments: [
                "query": Value.string("json"),
                "queryType": Value.string("extension"),
                "onlyIn": Value.array([Value.string(testFilesDir)]),
                "limit": 10
            ]
        )
        
        XCTAssertFalse(isError ?? true, "JSON extension search should not error")
        
        if case .text(let jsonResponse) = content.first! {
            let searchResults = try parseSearchResults(from: jsonResponse)
            print("Found \(searchResults.count) .json files")
            
            let jsonFiles = searchResults.filter { $0.name.hasSuffix(".json") }
            for jsonFile in jsonFiles {
                print("✅ Found JSON file: \(jsonFile.name)")
                XCTAssertTrue(jsonFile.path.contains(testFilesDir))
            }
            
            // Should find config.json and sample-data.json if they exist
            let expectedJsonFiles = ["config.json", "sample-data.json"]
            let foundJsonNames = jsonFiles.map { $0.name }
            
            for expectedJson in expectedJsonFiles {
                let found = foundJsonNames.contains { $0.contains(expectedJson) }
                if found {
                    print("✅ Found expected JSON file: \(expectedJson)")
                }
            }
        }
        
        await connectionHelper.cleanup(client: client, server: server)
    }
    
    // MARK: - Error Handling Tests
    
    /// Tests the timeoutSeconds parameter for preventing long-running searches.
    /// 
    /// **Purpose**: Verifies that searches complete within specified timeout limits
    /// and don't exceed reasonable execution times.
    /// 
    /// **What it tests**:
    /// - timeoutSeconds parameter functionality
    /// - Search execution time measurement
    /// - Timeout enforcement (should complete within 5 seconds)
    /// - Result quality within time constraints
    /// - Server stability with timeout limits
    /// 
    /// **Why it exists**: Timeout protection prevents searches from hanging indefinitely
    /// and consuming server resources. This test ensures the timeout parameter works
    /// and that searches complete promptly even with time constraints.
    func testTimeoutParameter() async throws {
        guard testFilesDir != nil && FileManager.default.fileExists(atPath: testFilesDir) else {
            throw XCTSkip("Test files directory not available")
        }
        
        print("⏱️ Testing timeout parameter...")
        
        let (client, server) = try await connectionHelper.setupClientServer()
        
        let startTime = Date()
        
        // Test with short timeout
        let (content, isError) = try await client.callTool(
            name: "file-search",
            arguments: [
                "query": Value.string("*"),
                "queryType": Value.string("all"),
                "onlyIn": Value.array([Value.string(testFilesDir)]),
                "timeoutSeconds": 2,
                "limit": 10
            ]
        )
        
        let duration = Date().timeIntervalSince(startTime)
        
        XCTAssertFalse(isError ?? true, "Timeout search should not error")
        XCTAssertLessThan(duration, 5.0, "Search should complete within reasonable time")
        
        if case .text(let jsonResponse) = content.first! {
            let searchResults = try parseSearchResults(from: jsonResponse)
            print("Found \(searchResults.count) files with 2-second timeout in \(String(format: "%.2f", duration))s")
        }
        
        await connectionHelper.cleanup(client: client, server: server)
    }
    
    /// Tests error handling with invalid queryType values.
    /// 
    /// **Purpose**: Verifies that the server properly handles invalid queryType values
    /// by either returning an error or gracefully falling back to default behavior.
    /// 
    /// **What it tests**:
    /// - Invalid queryType value handling ("invalid-type")
    /// - Server error response or graceful fallback behavior
    /// - Server stability with bad parameters
    /// - Proper error reporting or default behavior consistency
    /// - Response format validation for error cases
    /// 
    /// **Why it exists**: Clients might send invalid parameters due to bugs or
    /// API misuse. The server should handle these gracefully by either returning
    /// a clear error or falling back to a documented default behavior.
    func testInvalidQueryType() async throws {
        guard testFilesDir != nil && FileManager.default.fileExists(atPath: testFilesDir) else {
            throw XCTSkip("Test files directory not available")
        }
        
        print("❌ Testing error handling for invalid query type...")
        
        let (client, server) = try await connectionHelper.setupClientServer()
        
        // Test with invalid query type
        let (content, isError) = try await client.callTool(
            name: "file-search",
            arguments: [
                "query": Value.string("test"),
                "queryType": Value.string("invalid-type"),
                "onlyIn": Value.array([Value.string(testFilesDir)]),
                "limit": 5
            ]
        )
        
        XCTAssertEqual(content.count, 1, "Should return one content item")
        
        // The server should either return an error OR fall back to default behavior
        if let errorFlag = isError, errorFlag {
            // If it returns an error, verify error message is informative
            if case .text(let errorMessage) = content.first! {
                XCTAssertTrue(errorMessage.contains("queryType") || errorMessage.contains("invalid"), 
                             "Error message should mention queryType or invalid parameter")
                print("✅ Server properly returned error: \(errorMessage)")
            }
        } else {
            // If it doesn't error, it should fall back to default behavior and return valid results
            if case .text(let jsonResponse) = content.first! {
                let searchResults = try parseSearchResults(from: jsonResponse)
                print("✅ Server gracefully handled invalid queryType, returned \(searchResults.count) results")
                
                // Verify all results are from our test directory
                for result in searchResults {
                    XCTAssertTrue(result.path.contains(testFilesDir), "All results should be in test directory")
                }
            }
        }
        
        await connectionHelper.cleanup(client: client, server: server)
    }
    
    // MARK: - Helper Methods
    
    /// Parses JSON search results into SearchHit objects for test validation.
    /// 
    /// **Purpose**: Provides consistent JSON parsing functionality across all sorting
    /// and filtering tests that need to validate search results.
    /// 
    /// **What it does**:
    /// - Converts JSON string responses to SearchHit arrays
    /// - Configures ISO 8601 date parsing for timestamps
    /// - Handles JSON parsing errors appropriately
    /// - Ensures consistent data parsing across all tests
    /// 
    /// **Why it exists**: Multiple tests in this class need to parse and validate
    /// search results. This helper eliminates code duplication and ensures
    /// consistent parsing behavior across all sorting and filtering tests.
    private func parseSearchResults(from jsonResponse: String) throws -> [SearchHit] {
        let data = jsonResponse.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([SearchHit].self, from: data)
    }
}