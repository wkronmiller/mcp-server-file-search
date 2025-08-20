import Foundation
import MCP
#if os(macOS)
import Darwin
#elseif os(Linux)
import Glibc
#endif

/// Main server startup function
/// Initializes and starts the MCP File Search Server with stdio transport
/// - Throws: Any error that occurs during server startup
func runServer() async throws {
    Logger.info("Starting MCP File Search Server")
    Logger.debug("Platform: \(ProcessInfo.processInfo.operatingSystemVersionString)")
    Logger.debug("Process ID: \(ProcessInfo.processInfo.processIdentifier)")
    
    Logger.info("Creating server instance")
    let server = MCPFileSearchServer.createServer()
    
    Logger.info("Configuring server with tools and handlers")
    await MCPFileSearchServer.configureServer(server)
    
    Logger.info("Starting stdio transport - server ready to receive requests")
    // Start stdio transport (MCP) - this will block
    try await server.start(transport: StdioTransport())
}

/// Entry point - run server directly in an async context
Task {
    do {
        try await runServer()
    } catch {
        Logger.error("Server failed to start: \(error)")
        Logger.error("Stack trace: \(error.localizedDescription)")
        fputs("Error: \(error)\n", stderr)
        exit(1)
    }
}

// Wait forever using RunLoop (the server will handle its own lifecycle)
RunLoop.main.run()
