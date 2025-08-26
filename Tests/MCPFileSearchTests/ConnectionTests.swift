import XCTest
import MCP
import Logging
@testable import MCPFileSearch

/// Tests for MCP client/server connection establishment and basic protocol functionality.
/// These tests verify that the core MCP transport layer and connection lifecycle work correctly.
final class ConnectionTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        print("Starting connection test: \(name)")
    }
    
    override func tearDown() {
        print("Completed connection test: \(name)")
        super.tearDown()
    }
    
    /// Tests the complete MCP server connection lifecycle using our custom MCPFileSearchServer.
    /// 
    /// **Purpose**: Verifies that our file search server can properly initialize, configure handlers,
    /// establish client connections, and advertise its capabilities through the MCP protocol.
    /// 
    /// **What it tests**:
    /// - Server creation and configuration with file-search tool handlers
    /// - In-memory transport creation and pairing for test isolation
    /// - MCP protocol initialization handshake between client and server
    /// - Server capability advertisement (tools capability should be present)
    /// - Server metadata verification (name: "mac-file-search", version: "0.1.0")
    /// - Clean connection teardown and resource cleanup
    /// 
    /// **Why it exists**: This is a fundamental integration test ensuring our server can participate
    /// in the MCP ecosystem correctly. Without this working, clients couldn't discover or use our
    /// file search functionality.
    func testServerConnection() async throws {
        print("Creating client and server...")
        let client = Client(name: "TestClient", version: "1.0.0")
        let server = MCPFileSearchServer.createServer()
        
        print("⚙️ Configuring server handlers...")
        await MCPFileSearchServer.configureServer(server)
        
        print("🔗 Creating transport pair...")
        let (clientTransport, serverTransport) = await InMemoryTransport.createConnectedPair()
        
        print("Starting server and connecting client...")
        async let _ = server.start(transport: serverTransport)
        
        print("Connecting client...")
        let result = try await client.connect(transport: clientTransport)
        print("Client connected successfully")
        
        print("Verifying server capabilities...")
        XCTAssertNotNil(result.capabilities.tools, "Server should advertise tools capability")
        XCTAssertEqual(result.serverInfo.name, "mac-file-search")
        XCTAssertEqual(result.serverInfo.version, "0.1.0")
        print("Server capabilities verified")
        
        print("🧹 Cleaning up...")
        await client.disconnect()
        await server.stop()
        print("Cleanup completed")
    }
    

    
    // MARK: - Helper Methods
    
    /// Creates and configures a connected MCP client/server pair for testing.
    /// 
    /// **Purpose**: Provides a reusable setup method for tests that need a fully configured
    /// and connected MCP client/server pair with file search capabilities.
    /// 
    /// **What it does**:
    /// - Creates a test client and our MCPFileSearchServer
    /// - Configures the server with all file search tool handlers
    /// - Establishes in-memory transport for isolated testing
    /// - Completes the MCP connection handshake
    /// - Returns the ready-to-use client/server pair
    /// 
    /// **Why it exists**: Many tests need a working MCP connection to test functionality.
    /// This helper eliminates code duplication and ensures consistent test setup across
    /// different test classes.
    func setupClientServer() async throws -> (Client, Server) {
        print("Setting up client/server pair...")
        let client = Client(name: "TestClient", version: "1.0.0")
        let server = MCPFileSearchServer.createServer()
        
        print("⚙️ Configuring server...")
        await MCPFileSearchServer.configureServer(server)
        
        print("🔗 Creating transport pair...")
        let (clientTransport, serverTransport) = await InMemoryTransport.createConnectedPair()
        
        print("Starting server and connecting client...")
        async let _ = server.start(transport: serverTransport)
        _ = try await client.connect(transport: clientTransport)
        print("Client/server setup completed")
        
        return (client, server)
    }
    
    /// Properly disconnects and cleans up a client/server pair.
    /// 
    /// **Purpose**: Ensures proper resource cleanup after tests to prevent resource leaks
    /// and test interference.
    /// 
    /// **What it does**:
    /// - Gracefully disconnects the MCP client
    /// - Stops the MCP server
    /// - Logs cleanup completion for debugging
    /// 
    /// **Why it exists**: Proper cleanup is essential for test isolation and preventing
    /// resource exhaustion during test runs. This helper ensures consistent cleanup
    /// across all tests that use MCP connections.
    func cleanup(client: Client, server: Server) async {
        print("🧹 Starting cleanup...")
        await client.disconnect()
        await server.stop()
        print("Cleanup completed")
    }
}