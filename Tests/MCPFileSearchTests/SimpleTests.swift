import XCTest
import MCP
import Logging
@testable import MCPFileSearch

final class SimpleTests: XCTestCase {
    
    func testBasicConnection() async throws {
        print("🔧 Creating basic client...")
        let client = Client(name: "TestClient", version: "1.0.0")
        
        print("🔧 Creating basic server...")
        let server = Server(
            name: "test-server",
            version: "1.0.0",
            capabilities: .init(
                tools: .init(listChanged: true)
            )
        )
        
        print("🔗 Creating transport pair...")
        let (clientTransport, serverTransport) = await InMemoryTransport.createConnectedPair()
        
        print("🚀 Starting server...")
        async let _ = server.start(transport: serverTransport)
        
        print("📡 Connecting client...")
        let result = try await client.connect(transport: clientTransport)
        print("✅ Client connected: \(result.serverInfo.name)")
        
        print("🧹 Disconnecting...")
        await client.disconnect()
        await server.stop()
        print("✅ Test completed successfully")
    }
    
    func testSimpleToolListing() async throws {
        print("🛠️ Testing simple tool listing...")
        
        let client = Client(name: "TestClient", version: "1.0.0")
        let server = Server(
            name: "test-server",
            version: "1.0.0",
            capabilities: .init(
                tools: .init(listChanged: true)
            )
        )
        
        // Add a simple tool handler
        await server.withMethodHandler(ListTools.self) { _ in
            print("📋 Server: Listing tools...")
            return .init(tools: [
                Tool(
                    name: "test.tool",
                    description: "A test tool",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "message": .object([
                                "type": .string("string"),
                                "description": .string("A test message")
                            ])
                        ])
                    ])
                )
            ])
        }
        
        let (clientTransport, serverTransport) = await InMemoryTransport.createConnectedPair()
        
        async let _ = server.start(transport: serverTransport)
        _ = try await client.connect(transport: clientTransport)
        
        print("📋 Client: Requesting tools...")
        let (tools, _) = try await client.listTools()
        print("📋 Got \(tools.count) tools")
        
        XCTAssertEqual(tools.count, 1)
        XCTAssertEqual(tools.first?.name, "test.tool")
        
        await client.disconnect()
        await server.stop()
        print("✅ Simple tool test completed")
    }
}