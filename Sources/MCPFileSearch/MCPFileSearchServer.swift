import Foundation
import MCP

/// Main server class for the MCP File Search Server
/// Provides Spotlight-based file search capabilities for macOS
public class MCPFileSearchServer {
    
    /// Creates and configures a new MCP server instance
    /// - Returns: Configured MCP server ready for tool registration
    public static func createServer() -> Server {
        Logger.debug("Creating MCP server with name: mac-file-search, version: 0.1.0")
        let server = Server(
            name: "mac-file-search",
            version: "0.1.0",
            instructions: "A Model Context Protocol (MCP) server that provides Spotlight-based file search capabilities on macOS. Use the file-search tool to search for files by name or content across the local filesystem.",
            capabilities: .init(
                tools: .init(listChanged: true)
            )
        )
        
        Logger.debug("Server instance created successfully")
        return server
    }
    
    /// Configures the server with tool handlers and method implementations
    /// - Parameter server: The server instance to configure
    public static func configureServer(_ server: Server) async {
        Logger.debug("Configuring server with tool handlers")
        
        // Advertise tools
        Logger.debug("Registering ListTools handler")
        await server.withMethodHandler(ListTools.self) { request in
            Logger.debug("ListTools request received")
            let tools = [
                FileSearchToolHandler.getToolDefinition()
            ]
            Logger.debug("Returning \(tools.count) tool(s) in ListTools response")
            return .init(tools: tools)
        }

        // Implement file-search
        Logger.debug("Registering CallTool handler for file-search")
        await server.withMethodHandler(CallTool.self) { params in
            return await FileSearchToolHandler.handleToolCall(params)
        }
    }
}
