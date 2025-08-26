import XCTest
import MCP
import Logging
@testable import MCPFileSearch

/// Tests for MCP tool discovery, validation, and error handling.
/// These tests verify that tools are properly registered, discoverable, and handle invalid requests correctly.
final class ToolTests: XCTestCase {
    
    private var connectionHelper: ConnectionTests!
    
    override func setUp() {
        super.setUp()
        connectionHelper = ConnectionTests()
        print("Starting tool test: \(name)")
    }
    
    override func tearDown() {
        print("Completed tool test: \(name)")
        super.tearDown()
    }
    
    /// Tests the MCP tools/list functionality with our file search server.
    /// 
    /// **Purpose**: Verifies that our file search server properly advertises its available tools
    /// through the MCP protocol's standardized tool discovery mechanism.
    /// 
    /// **What it tests**:
    /// - Tool listing via MCP ListTools request/response
    /// - Correct tool count (should be exactly 1 tool: file-search)
    /// - Tool metadata verification (name, description, input schema)
    /// - Tool name matches expected "file-search"
    /// - Tool description is properly set and informative
    /// - Input schema is present and properly structured
    /// 
    /// **Why it exists**: Tool discovery is fundamental to MCP - clients need to know what
    /// tools are available before they can use them. This test ensures our file-search tool
    /// is properly registered and discoverable by any MCP client.
    func testListTools() async throws {
        print("Testing tool listing...")
        
        // Create and configure client/server
        let (client, server) = try await connectionHelper.setupClientServer()
        
        print("Listing tools...")
        let (tools, _) = try await client.listTools()
        print("Got \(tools.count) tools")
        
        // Verify tools
        XCTAssertEqual(tools.count, 1, "Should have exactly one tool")
        
        let fileSearchTool = tools.first!
        XCTAssertEqual(fileSearchTool.name, "file-search")
        XCTAssertEqual(fileSearchTool.description, "Advanced Spotlight-backed file search on macOS with multiple query types, date filtering, and sorting.")
        XCTAssertNotNil(fileSearchTool.inputSchema)
        print("Tool verification passed")
        
        // Clean up
        await connectionHelper.cleanup(client: client, server: server)
    }
    

    
    /// Tests error handling when calling a non-existent tool.
    /// 
    /// **Purpose**: Verifies that our server properly handles and reports errors when clients
    /// attempt to call tools that don't exist.
    /// 
    /// **What it tests**:
    /// - Invalid tool name handling via MCP CallTool request
    /// - Proper error response format (isError flag should be true)
    /// - Error message content (should indicate "Unknown tool")
    /// - Server remains stable after invalid requests
    /// - Error response follows MCP protocol standards
    /// 
    /// **Why it exists**: Error handling is crucial for a robust MCP server. Clients may send
    /// invalid requests due to bugs, outdated tool lists, or typos. Our server must handle
    /// these gracefully without crashing and provide clear error messages to help debug issues.
    func testInvalidToolName() async throws {
        // Create and configure client/server
        let (client, server) = try await connectionHelper.setupClientServer()
        
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
        await connectionHelper.cleanup(client: client, server: server)
    }
}