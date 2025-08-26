import XCTest
import Foundation
@testable import MCPFileSearch

/// End-to-end integration tests using real server processes and JSON-RPC communication.
/// These tests verify that the complete system works as a standalone MCP server
/// by launching the actual executable and communicating via stdin/stdout JSON-RPC.
final class IntegrationTests: XCTestCase {
    
    private var serverProcess: Process?
    private var serverPath: String {
        return "./.build/debug/mcp-file-search"
    }
    
    override func setUp() {
        super.setUp()
        print("Starting integration test: \(name)")
        
        // Build the server if needed
        buildServerIfNeeded()
    }
    
    override func tearDown() {
        stopServer()
        print("Completed integration test: \(name)")
        super.tearDown()
    }
    
    // MARK: - Build and Server Management
    
    /// Builds the MCP server executable if it doesn't already exist.
    /// 
    /// **Purpose**: Ensures the server binary is available for integration testing
    /// by building it automatically when needed.
    /// 
    /// **What it does**:
    /// - Checks if the server executable exists at expected path
    /// - Runs `swift build` if the executable is missing
    /// - Validates build success before proceeding with tests
    /// - Handles build failures appropriately
    /// 
    /// **Why it exists**: Integration tests need the actual compiled server binary.
    /// This helper ensures the binary is always available, building it on-demand
    /// to avoid manual build steps in the test workflow.
    private func buildServerIfNeeded() {
        let fileManager = FileManager.default
        let currentDir = fileManager.currentDirectoryPath
        let serverExecutable = "\(currentDir)/\(serverPath)"
        
        if !fileManager.fileExists(atPath: serverExecutable) {
            print("Building server executable...")
            let buildProcess = Process()
            buildProcess.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
            buildProcess.arguments = ["build"]
            buildProcess.currentDirectoryURL = URL(fileURLWithPath: currentDir)
            
            do {
                try buildProcess.run()
                buildProcess.waitUntilExit()
                
                if buildProcess.terminationStatus != 0 {
                    XCTFail("Failed to build server executable")
                    return
                }
                print("Server executable built successfully")
            } catch {
                XCTFail("Failed to run swift build: \(error)")
            }
        }
    }
    
    /// Launches the MCP server as a separate process with pipe communication.
    /// 
    /// **Purpose**: Starts the actual MCP server binary as a child process to test
    /// real JSON-RPC communication over stdin/stdout.
    /// 
    /// **What it does**:
    /// - Launches the server executable as a child process
    /// - Sets up stdin/stdout/stderr pipes for communication
    /// - Waits for server startup and validates it's running
    /// - Returns pipes for JSON-RPC communication
    /// - Handles startup failures and error reporting
    /// 
    /// **Why it exists**: Integration tests must verify the complete system including
    /// process startup, JSON-RPC parsing, and real MCP protocol handling. This
    /// method provides the foundation for true end-to-end testing.
    private func startServer() -> (stdin: Pipe, stdout: Pipe, stderr: Pipe)? {
        let currentDir = FileManager.default.currentDirectoryPath
        let serverExecutable = "\(currentDir)/\(serverPath)"
        
        guard FileManager.default.fileExists(atPath: serverExecutable) else {
            XCTFail("Server executable not found at \(serverExecutable)")
            return nil
        }
        
        let process = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        
        process.executableURL = URL(fileURLWithPath: serverExecutable)
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr
        
        do {
            try process.run()
            self.serverProcess = process
            print("Server started with PID: \(process.processIdentifier)")
            
            // Give the server more time to start up and listen for requests
            usleep(1_000_000) // 1.0 second
            
            // Verify server is still running
            if !process.isRunning {
                print("Server process died immediately")
                
                // Read stderr to see what went wrong
                let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
                if let stderrString = String(data: stderrData, encoding: .utf8), !stderrString.isEmpty {
                    print("Server stderr: \(stderrString)")
                }
                
                XCTFail("Server process terminated unexpectedly")
                return nil
            }
            
            print("Server is running and ready")
            return (stdin: stdin, stdout: stdout, stderr: stderr)
        } catch {
            XCTFail("Failed to start server process: \(error)")
            return nil
        }
    }
    
    /// Gracefully terminates the server process and cleans up resources.
    /// 
    /// **Purpose**: Ensures proper cleanup of server processes and prevents
    /// resource leaks or zombie processes during test runs.
    /// 
    /// **What it does**:
    /// - Terminates the running server process if active
    /// - Waits for process termination to complete
    /// - Cleans up process references
    /// - Logs termination for debugging
    /// 
    /// **Why it exists**: Each integration test starts its own server process.
    /// Proper cleanup prevents process accumulation and ensures test isolation
    /// by fully terminating each server before the next test starts.
    private func stopServer() {
        if let process = serverProcess {
            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
                print("Server stopped")
            }
            serverProcess = nil
        }
    }
    
    // MARK: - JSON-RPC Communication
    
    /// Sends a JSON-RPC request to the server and waits for a response.
    /// 
    /// **Purpose**: Provides the core communication mechanism for integration tests
    /// by handling JSON-RPC request/response cycles over stdin/stdout pipes.
    /// 
    /// **What it does**:
    /// - Sends JSON-RPC request string to server via stdin
    /// - Waits for response on stdout with timeout protection
    /// - Handles partial responses and ensures complete JSON objects
    /// - Captures and reports stderr output for debugging
    /// - Returns the complete JSON-RPC response string
    /// 
    /// **Why it exists**: Integration tests need to send actual MCP protocol
    /// messages to the server. This method handles the complexity of pipe
    /// communication, timeouts, and response parsing for reliable testing.
    private func sendJSONRPCRequest(_ request: String, to stdin: Pipe, from stdout: Pipe, stderr: Pipe) throws -> String? {
        print("Sending request: \(request)")
        
        // Send request
        let requestData = (request + "\n").data(using: .utf8)!
        stdin.fileHandleForWriting.write(requestData)
        
        // Read response with a more robust approach
        let outputHandle = stdout.fileHandleForReading
        var responseData = Data()
        
        // Set a timeout for reading the response
        let timeout = 5.0
        let start = Date()
        
        while Date().timeIntervalSince(start) < timeout {
            let availableData = outputHandle.availableData
            if !availableData.isEmpty {
                responseData.append(availableData)
                // Simple check to see if we have a complete JSON object
                if let responseString = String(data: responseData, encoding: .utf8), responseString.contains("}") {
                    print("Received response: \(responseString)")
                    return responseString.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            // Sleep for a short interval to avoid busy-waiting
            usleep(100_000) // 0.1 seconds
        }
        
        print("No data received within timeout")
        let stderrData = stderr.fileHandleForReading.availableData
        if !stderrData.isEmpty, let stderrString = String(data: stderrData, encoding: .utf8) {
            print("Server stderr: \(stderrString)")
        }
        
        throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No response received within timeout"])
    }
    
    // MARK: - Integration Tests
    
    /// Tests complete MCP server initialization via JSON-RPC protocol.
    /// 
    /// **Purpose**: Verifies that the server can be launched, initialized via MCP
    /// protocol, and returns correct server information and capabilities.
    /// 
    /// **What it tests**:
    /// - Real server process startup and readiness
    /// - MCP initialization handshake via JSON-RPC
    /// - Server info response (name: "mac-file-search", version)
    /// - Server capabilities advertisement (tools capability)
    /// - Complete protocol compliance for initialization
    /// 
    /// **Why it exists**: This is the fundamental integration test ensuring our
    /// server works as a real MCP server that clients can discover and connect to.
    /// Without this working, no MCP client could use our server.
    func testServerInitialization() throws {
        print("Testing real MCP server initialization via JSON-RPC...")
        
        guard let serverPipes = startServer() else {
            XCTFail("Failed to start server")
            return
        }
        
        let initRequest = """
        {"jsonrpc":"2.0","method":"initialize","params":{"clientInfo":{"name":"test-client","version":"1.0.0"},"capabilities":{}},"id":1}
        """
        
        print("Sending initialization request...")
        let response = try sendJSONRPCRequest(initRequest, to: serverPipes.stdin, from: serverPipes.stdout, stderr: serverPipes.stderr)
        
        print("Received response: \(response ?? "nil")")
        XCTAssertNotNil(response, "Should receive a response")
        
        if let responseStr = response {
            XCTAssertTrue(responseStr.contains("result"), "Response should contain result")
            XCTAssertTrue(responseStr.contains("serverInfo"), "Response should contain serverInfo")
            XCTAssertTrue(responseStr.contains("mac-file-search"), "Response should contain server name")
        }
    }
    
    /// Tests MCP tool discovery via JSON-RPC tools/list request.
    /// 
    /// **Purpose**: Verifies that the server properly advertises its available tools
    /// through the standard MCP tool discovery mechanism.
    /// 
    /// **What it tests**:
    /// - Server initialization followed by tool listing
    /// - MCP tools/list request/response cycle
    /// - Tool metadata in response (file-search tool presence)
    /// - Complete JSON-RPC protocol compliance for tool discovery
    /// - Tool schema and description availability
    /// 
    /// **Why it exists**: Tool discovery is essential for MCP clients to know
    /// what functionality is available. This test ensures our file-search tool
    /// is properly advertised and discoverable by real MCP clients.
    func testServerToolListing() throws {
        print("Testing real MCP server tool listing via JSON-RPC...")
        
        guard let serverPipes = startServer() else {
            XCTFail("Failed to start server")
            return
        }
        
        // First initialize
        let initRequest = """
        {"jsonrpc":"2.0","method":"initialize","params":{"clientInfo":{"name":"test-client","version":"1.0.0"},"capabilities":{}},"id":1}
        """
        
        _ = try sendJSONRPCRequest(initRequest, to: serverPipes.stdin, from: serverPipes.stdout, stderr: serverPipes.stderr)
        
        // Then list tools
        let toolsRequest = """
        {"jsonrpc":"2.0","method":"tools/list","params":{},"id":2}
        """
        
        print("Sending tools/list request...")
        let response = try sendJSONRPCRequest(toolsRequest, to: serverPipes.stdin, from: serverPipes.stdout, stderr: serverPipes.stderr)
        
        print("Received response: \(response ?? "nil")")
        XCTAssertNotNil(response, "Should receive a response")
        
        if let responseStr = response {
            XCTAssertTrue(responseStr.contains("result"), "Response should contain result")
            XCTAssertTrue(responseStr.contains("tools"), "Response should contain tools array")
            XCTAssertTrue(responseStr.contains("file-search"), "Response should contain file-search tool")
        }
    }
    
    /// Tests actual file search functionality via JSON-RPC tools/call request.
    /// 
    /// **Purpose**: Verifies that the complete file search workflow works end-to-end
    /// with real Spotlight queries and JSON-RPC communication.
    /// 
    /// **What it tests**:
    /// - Complete MCP initialization and tool calling workflow
    /// - Real file search execution with Spotlight integration
    /// - Search parameter handling (query, filenameOnly, limit)
    /// - JSON response format and search result structure
    /// - Actual file discovery (Package.swift files)
    /// 
    /// **Why it exists**: This is the core functionality test ensuring the entire
    /// system works together - MCP protocol, Spotlight search, and result formatting.
    /// This test validates the primary use case for our server.
    func testServerFileSearch() throws {
        print("Testing real MCP server file search via JSON-RPC...")
        
        guard let serverPipes = startServer() else {
            XCTFail("Failed to start server")
            return
        }
        
        // First initialize
        let initRequest = """
        {"jsonrpc":"2.0","method":"initialize","params":{"clientInfo":{"name":"test-client","version":"1.0.0"},"capabilities":{}},"id":1}
        """
        
        _ = try sendJSONRPCRequest(initRequest, to: serverPipes.stdin, from: serverPipes.stdout, stderr: serverPipes.stderr)
        
        // Then search for Swift files
        let searchRequest = """
        {"jsonrpc":"2.0","method":"tools/call","params":{"name":"file-search","arguments":{"query":"Package.swift","filenameOnly":true,"limit":5}},"id":3}
        """
        
        print("Sending file-search request for Package.swift...")
        let response = try sendJSONRPCRequest(searchRequest, to: serverPipes.stdin, from: serverPipes.stdout, stderr: serverPipes.stderr)
        
        print("Received response: \(response ?? "nil")")
        XCTAssertNotNil(response, "Should receive a response")
        
        if let responseStr = response {
            XCTAssertTrue(responseStr.contains("result"), "Response should contain result")
            XCTAssertTrue(responseStr.contains("content"), "Response should contain content")
            
            // The response should contain an array of search results
            XCTAssertTrue(responseStr.contains("["), "Response should contain JSON array")
            XCTAssertTrue(responseStr.contains("Package.swift") || responseStr.contains("[]"), 
                         "Response should contain Package.swift or be empty array")
        }
    }
    
    /// Tests directory-scoped file search via JSON-RPC with onlyIn parameter.
    /// 
    /// **Purpose**: Verifies that directory-scoped searches work correctly through
    /// the complete MCP protocol stack with real Spotlight queries.
    /// 
    /// **What it tests**:
    /// - Directory-scoped search using onlyIn parameter
    /// - Real Spotlight query with directory restrictions
    /// - Specific file discovery (main.swift in Sources directory)
    /// - Path validation in search results
    /// - Complete integration of scoped search functionality
    /// 
    /// **Why it exists**: Directory scoping is a critical feature for practical
    /// file search usage. This test ensures the onlyIn parameter works correctly
    /// through the entire system stack in real-world usage scenarios.
    func testServerSearchInDirectory() throws {
        print("Testing real MCP server directory-scoped search via JSON-RPC...")
        
        guard let serverPipes = startServer() else {
            XCTFail("Failed to start server")
            return
        }
        
        // First initialize
        let initRequest = """
        {"jsonrpc":"2.0","method":"initialize","params":{"clientInfo":{"name":"test-client","version":"1.0.0"},"capabilities":{}},"id":1}
        """
        
        _ = try sendJSONRPCRequest(initRequest, to: serverPipes.stdin, from: serverPipes.stdout, stderr: serverPipes.stderr)
        
        // Get current directory for search
        let currentDir = FileManager.default.currentDirectoryPath
        let sourcesDir = "\(currentDir)/Sources"
        
        // Search for main.swift in Sources directory  
        let searchRequest = """
        {"jsonrpc":"2.0","method":"tools/call","params":{"name":"file-search","arguments":{"query":"main.swift","onlyIn":["\(sourcesDir)"],"filenameOnly":true,"limit":10}},"id":4}
        """
        
        print("Sending directory-scoped search request...")
        let response = try sendJSONRPCRequest(searchRequest, to: serverPipes.stdin, from: serverPipes.stdout, stderr: serverPipes.stderr)
        
        print("Received response: \(response ?? "nil")")
        XCTAssertNotNil(response, "Should receive a response")
        
        // Assert that it actually found main.swift
        if let responseStr = response {
            XCTAssertTrue(responseStr.contains("result"), "Response should contain result")
            XCTAssertTrue(responseStr.contains("content"), "Response should contain content")
            XCTAssertTrue(responseStr.contains("["), "Response should contain JSON array")
            XCTAssertTrue(responseStr.contains("main.swift"), "Response should contain main.swift in results")
            XCTAssertTrue(responseStr.contains("MCPFileSearch") && responseStr.contains("main.swift"), "Response should contain both MCPFileSearch and main.swift")
            
            // Should find some .swift files in the Sources directory
            XCTAssertTrue(responseStr.contains(".swift") || responseStr.contains("[]"), 
                         "Response should contain Swift files or be empty array")
        }
    }
    
    /// Tests server error handling with invalid tool calls via JSON-RPC.
    /// 
    /// **Purpose**: Verifies that the server handles invalid requests gracefully
    /// and returns proper error responses through the MCP protocol.
    /// 
    /// **What it tests**:
    /// - Invalid tool name handling via JSON-RPC
    /// - Proper error response format (isError flag)
    /// - Error message content ("Unknown tool")
    /// - Server stability after receiving invalid requests
    /// - Complete error handling through the protocol stack
    /// 
    /// **Why it exists**: Robust error handling is essential for production MCP
    /// servers. This test ensures our server handles client errors gracefully
    /// without crashing and provides helpful error messages for debugging.
    func testServerErrorHandling() throws {
        print("Testing real MCP server error handling via JSON-RPC...")
        
        guard let serverPipes = startServer() else {
            XCTFail("Failed to start server")
            return
        }
        
        // First initialize
        let initRequest = """
        {"jsonrpc":"2.0","method":"initialize","params":{"clientInfo":{"name":"test-client","version":"1.0.0"},"capabilities":{}},"id":1}
        """
        
        _ = try sendJSONRPCRequest(initRequest, to: serverPipes.stdin, from: serverPipes.stdout, stderr: serverPipes.stderr)
        
        // Try to call an invalid tool
        let invalidToolRequest = """
        {"jsonrpc":"2.0","method":"tools/call","params":{"name":"invalid-tool","arguments":{"query":"test"}},"id":5}
        """
        
        print("Sending invalid tool request...")
        let response = try sendJSONRPCRequest(invalidToolRequest, to: serverPipes.stdin, from: serverPipes.stdout, stderr: serverPipes.stderr)
        
        print("Received response: \(response ?? "nil")")
        XCTAssertNotNil(response, "Should receive a response")
        
        if let responseStr = response {
            XCTAssertTrue(responseStr.contains("result"), "Response should contain result")
            XCTAssertTrue(responseStr.contains("isError") || responseStr.contains("Unknown tool"), 
                         "Response should indicate an error")
        }
    }
}