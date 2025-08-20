import XCTest
import Foundation
@testable import MCPFileSearch

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
    
    func testRealMCPServerInitialization() throws {
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
    
    func testRealMCPServerToolListing() throws {
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
    
    func testRealMCPServerFileSearch() throws {
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
    
    func testRealMCPServerSearchInDirectory() throws {
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
    
    func testRealMCPServerErrorHandling() throws {
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
