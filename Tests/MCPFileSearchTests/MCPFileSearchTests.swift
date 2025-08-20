import XCTest
import MCP
import Logging
@testable import MCPFileSearch

final class MCPFileSearchTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        print("🧪 Starting test: \(name)")
    }
    
    override func tearDown() {
        print("✅ Completed test: \(name)")
        super.tearDown()
    }
    
    func testServerConnection() async throws {
        print("🔧 Creating client and server...")
        let client = Client(name: "TestClient", version: "1.0.0")
        let server = MCPFileSearchServer.createServer()
        
        print("⚙️ Configuring server handlers...")
        await MCPFileSearchServer.configureServer(server)
        
        print("🔗 Creating transport pair...")
        let (clientTransport, serverTransport) = await InMemoryTransport.createConnectedPair()
        
        print("🚀 Starting server and connecting client...")
        async let _ = server.start(transport: serverTransport)
        
        print("📡 Connecting client...")
        let result = try await client.connect(transport: clientTransport)
        print("✅ Client connected successfully")
        
        print("🔍 Verifying server capabilities...")
        XCTAssertNotNil(result.capabilities.tools, "Server should advertise tools capability")
        XCTAssertEqual(result.serverInfo.name, "mac-file-search")
        XCTAssertEqual(result.serverInfo.version, "0.1.0")
        print("✅ Server capabilities verified")
        
        print("🧹 Cleaning up...")
        await client.disconnect()
        await server.stop()
        print("✅ Cleanup completed")
    }
    
    func testListTools() async throws {
        print("🛠️ Testing tool listing...")
        
        // Create and configure client/server
        let (client, server) = try await setupClientServer()
        
        print("📋 Listing tools...")
        let (tools, _) = try await client.listTools()
        print("📋 Got \(tools.count) tools")
        
        // Verify tools
        XCTAssertEqual(tools.count, 1, "Should have exactly one tool")
        
        let fileSearchTool = tools.first!
        XCTAssertEqual(fileSearchTool.name, "file-search")
        XCTAssertEqual(fileSearchTool.description, "Advanced Spotlight-backed file search on macOS with multiple query types, date filtering, and sorting.")
        XCTAssertNotNil(fileSearchTool.inputSchema)
        print("✅ Tool verification passed")
        
        // Clean up
        await cleanup(client: client, server: server)
    }
    
    func testFileSearchBasic() async throws {
        print("🔍 Testing basic file-search functionality...")
        
        // Create and configure client/server
        let (client, server) = try await setupClientServer()
        
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
        print("🔍 isError: \(isError ?? false)")
        XCTAssertEqual(content.count, 1, "Should return one content item")
        
        if case .text(let jsonResponse) = content.first! {
            print("📄 Got JSON response: \(jsonResponse)")
            
            // Parse JSON response - should be valid even if empty
            let data = jsonResponse.data(using: String.Encoding.utf8)!
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let searchResults = try decoder.decode([SearchHit].self, from: data)
            
            print("📊 Found \(searchResults.count) results")
            
            // Verify result structure if any results found
            if !searchResults.isEmpty {
                let firstResult = searchResults.first!
                XCTAssertFalse(firstResult.path.isEmpty, "Path should not be empty")
                XCTAssertFalse(firstResult.name.isEmpty, "Name should not be empty")
                print("✅ First result: \(firstResult.name) at \(firstResult.path)")
            } else {
                print("ℹ️ No results found - this may be expected in test environment")
            }
        } else {
            XCTFail("Expected text content")
        }
        
        // Clean up
        await cleanup(client: client, server: server)
    }
    
    func testFileSearchWithDirectory() async throws {
        print("📁 Testing directory-scoped search for multiple files...")
        
        // Create and configure client/server
        let (client, server) = try await setupClientServer()
        
        // Get current directory for testing
        let currentDir = FileManager.default.currentDirectoryPath
        print("📁 Searching in directory: \(currentDir)")
        
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
            print("📄 Got JSON response: \(jsonResponse)")
            
            // Parse JSON response
            let data = jsonResponse.data(using: String.Encoding.utf8)!
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let searchResults = try decoder.decode([SearchHit].self, from: data)
            
            // Should find Swift files in the Sources/ directory
            XCTAssertGreaterThan(searchResults.count, 0, "Should find at least one .swift file")
            
            // Verify all results are in our project directory
            for result in searchResults {
                XCTAssertTrue(result.path.contains(currentDir), "All results should be in project directory")
                XCTAssertTrue(result.name.hasSuffix(".swift"), "All results should be Swift files")
                print("✅ Found Swift file: \(result.name) at \(result.path)")
            }
            
            // Should find some specific files we know exist
            let knownFiles = ["main.swift", "Package.swift"]
            let foundFiles = searchResults.map { $0.name }
            
            for knownFile in knownFiles {
                let found = foundFiles.contains { $0.contains(knownFile) }
                if found {
                    print("✅ Found expected file: \(knownFile)")
                }
            }
            
            // At minimum should find Package.swift
            let packageSwift = searchResults.first { $0.name.contains("Package.swift") }
            XCTAssertNotNil(packageSwift, "Should find Package.swift file")
            
        } else {
            XCTFail("Expected text content")
        }
        
        // Clean up
        await cleanup(client: client, server: server)
    }
    
    func testFileSearchSpecificFile() async throws {
        print("🎯 Testing search for specific known file...")
        
        // Create and configure client/server
        let (client, server) = try await setupClientServer()
        
        // Get current directory for scoped search
        let currentDir = FileManager.default.currentDirectoryPath
        print("📁 Searching for LICENSE file in: \(currentDir)")
        
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
            print("📄 Got JSON response: \(jsonResponse)")
            
            // Parse JSON response
            let data = jsonResponse.data(using: String.Encoding.utf8)!
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let searchResults = try decoder.decode([SearchHit].self, from: data)
            
            // Should find LICENSE file
            XCTAssertGreaterThan(searchResults.count, 0, "Should find LICENSE file")
            
            let licenseFile = searchResults.first { $0.name == "LICENSE" }
            XCTAssertNotNil(licenseFile, "Should find LICENSE file")
            
            if let licenseFile = licenseFile {
                XCTAssertTrue(licenseFile.path.contains(currentDir), "LICENSE should be in project directory")
                XCTAssertTrue(licenseFile.path.hasSuffix("LICENSE"), "Path should end with LICENSE")
                print("✅ Found LICENSE file at: \(licenseFile.path)")
            }
        } else {
            XCTFail("Expected text content")
        }
        
        // Clean up
        await cleanup(client: client, server: server)
    }
    
    func testFileSearchTimeout() async throws {
        print("⏱️ Testing file-search with timeout to ensure no hanging...")
        
        // Create and configure client/server
        let (client, server) = try await setupClientServer()
        
        // Test with a simple query that should return quickly or timeout
        let (content, isError) = try await client.callTool(
            name: "file-search",
            arguments: [
                "query": "xyz123nonexistent",
                "filenameOnly": true,
                "limit": 1
            ]
        )
        
        // Verify response - should not hang and should return valid JSON
        print("🔍 isError: \(isError ?? false)")
        XCTAssertEqual(content.count, 1, "Should return one content item")
        
        if case .text(let jsonResponse) = content.first! {
            print("📄 Got JSON response: \(jsonResponse)")
            
            // Should be valid JSON array (likely empty)
            let data = jsonResponse.data(using: String.Encoding.utf8)!
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let searchResults = try decoder.decode([SearchHit].self, from: data)
            
            print("📊 Found \(searchResults.count) results for nonexistent query")
            // No specific assertions about results - just that it doesn't hang
        } else {
            XCTFail("Expected text content")
        }
        
        // Clean up
        await cleanup(client: client, server: server)
    }
    
    func testInvalidToolName() async throws {
        // Create and configure client/server
        let (client, server) = try await setupClientServer()
        
        // Call invalid tool
        let (content, isError) = try await client.callTool(
            name: "invalid.tool",
            arguments: ["query": "test"]
        )
        
        // Verify error response
        XCTAssertTrue(isError ?? false, "Should return an error for invalid tool")
        XCTAssertEqual(content.count, 1, "Should return one content item")
        
        if case .text(let errorMessage) = content.first! {
            XCTAssertEqual(errorMessage, "Unknown tool")
        } else {
            XCTFail("Expected text error message")
        }
        
        // Clean up
        await cleanup(client: client, server: server)
    }
    
    // MARK: - Type Tests
    
    func testQueryTypeEnum() {
        XCTAssertEqual(QueryType.extension.rawValue, "extension")
        XCTAssertEqual(QueryType.contents.rawValue, "contents")
        XCTAssertEqual(QueryType.filename.rawValue, "filename")
        XCTAssertEqual(QueryType.all.rawValue, "all")
    }
    
    func testSortOptionEnum() {
        XCTAssertEqual(SortOption.name.rawValue, "name")
        XCTAssertEqual(SortOption.dateModified.rawValue, "dateModified")
        XCTAssertEqual(SortOption.dateCreated.rawValue, "dateCreated")
        XCTAssertEqual(SortOption.size.rawValue, "size")
    }
    
    func testSortOrderEnum() {
        XCTAssertEqual(SortOrder.ascending.rawValue, "ascending")
        XCTAssertEqual(SortOrder.descending.rawValue, "descending")
    }
    
    func testSearchArgsInitWithFilenameOnly() {
        // Test backward compatibility - filenameOnly should set queryType to .filename
        let args1 = SearchArgs(
            query: "test",
            filenameOnly: true
        )
        XCTAssertEqual(args1.queryType, .filename)
        XCTAssertTrue(args1.filenameOnly ?? false)
        
        // Test that filenameOnly false doesn't override queryType
        let args2 = SearchArgs(
            query: "test",
            queryType: .contents,
            filenameOnly: false
        )
        XCTAssertEqual(args2.queryType, .contents)
        XCTAssertFalse(args2.filenameOnly ?? true)
        
        // Test that nil filenameOnly doesn't affect queryType
        let args3 = SearchArgs(
            query: "test",
            queryType: .extension,
            filenameOnly: nil
        )
        XCTAssertEqual(args3.queryType, .extension)
        XCTAssertNil(args3.filenameOnly)
    }
    
    func testSearchArgsWithAllParameters() {
        let dateFilter = DateFilter(
            from: Date(timeIntervalSince1970: 1000000),
            to: Date(timeIntervalSince1970: 2000000)
        )
        
        let args = SearchArgs(
            query: "test",
            queryType: .extension,
            extensions: ["swift", "json"],
            onlyIn: ["/path/one", "/path/two"],
            dateFilter: dateFilter,
            sortBy: .size,
            sortOrder: .descending,
            limit: 100
        )
        
        XCTAssertEqual(args.query, "test")
        XCTAssertEqual(args.queryType, .extension)
        XCTAssertEqual(args.extensions, ["swift", "json"])
        XCTAssertEqual(args.onlyIn, ["/path/one", "/path/two"])
        XCTAssertEqual(args.dateFilter?.from, Date(timeIntervalSince1970: 1000000))
        XCTAssertEqual(args.dateFilter?.to, Date(timeIntervalSince1970: 2000000))
        XCTAssertEqual(args.sortBy, .size)
        XCTAssertEqual(args.sortOrder, .descending)
        XCTAssertEqual(args.limit, 100)
    }
    
    func testSearchHitProperties() {
        let hit = SearchHit(
            path: "/test/path.swift",
            name: "path.swift",
            kind: "Swift Source",
            size: 12345,
            created: Date(timeIntervalSince1970: 1000000),
            modified: Date(timeIntervalSince1970: 2000000)
        )
        
        XCTAssertEqual(hit.path, "/test/path.swift")
        XCTAssertEqual(hit.name, "path.swift")
        XCTAssertEqual(hit.kind, "Swift Source")
        XCTAssertEqual(hit.size, 12345)
        XCTAssertEqual(hit.created, Date(timeIntervalSince1970: 1000000))
        XCTAssertEqual(hit.modified, Date(timeIntervalSince1970: 2000000))
    }
    
    func testSearchArgsCodable() throws {
        let dateFilter = DateFilter(
            from: Date(timeIntervalSince1970: 1000000),
            to: Date(timeIntervalSince1970: 2000000)
        )
        
        let original = SearchArgs(
            query: "test",
            queryType: .contents,
            extensions: ["txt", "md"],
            onlyIn: ["/Users/test"],
            dateFilter: dateFilter,
            sortBy: .dateModified,
            sortOrder: .descending,
            limit: 50,
            filenameOnly: false
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SearchArgs.self, from: data)
        
        XCTAssertEqual(decoded.query, original.query)
        XCTAssertEqual(decoded.queryType, original.queryType)
        XCTAssertEqual(decoded.extensions, original.extensions)
        XCTAssertEqual(decoded.onlyIn, original.onlyIn)
        XCTAssertEqual(decoded.sortBy, original.sortBy)
        XCTAssertEqual(decoded.sortOrder, original.sortOrder)
        XCTAssertEqual(decoded.limit, original.limit)
        XCTAssertEqual(decoded.filenameOnly, original.filenameOnly)
    }
    
    func testDateFilterCodable() throws {
        let original = DateFilter(
            from: Date(timeIntervalSince1970: 1000000),
            to: Date(timeIntervalSince1970: 2000000)
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DateFilter.self, from: data)
        
        XCTAssertEqual(decoded.from, original.from)
        XCTAssertEqual(decoded.to, original.to)
    }
    
    // MARK: - Helper Methods
    
    private func setupClientServer() async throws -> (Client, Server) {
        print("🔧 Setting up client/server pair...")
        let client = Client(name: "TestClient", version: "1.0.0")
        let server = MCPFileSearchServer.createServer()
        
        print("⚙️ Configuring server...")
        await MCPFileSearchServer.configureServer(server)
        
        print("🔗 Creating transport pair...")
        let (clientTransport, serverTransport) = await InMemoryTransport.createConnectedPair()
        
        print("🚀 Starting server and connecting client...")
        async let _ = server.start(transport: serverTransport)
        _ = try await client.connect(transport: clientTransport)
        print("✅ Client/server setup completed")
        
        return (client, server)
    }
    
    private func cleanup(client: Client, server: Server) async {
        print("🧹 Starting cleanup...")
        await client.disconnect()
        await server.stop()
        print("✅ Cleanup completed")
    }
}
