import Foundation
import MCP
#if canImport(System)
import System
#else
@preconcurrency import SystemPackage
#endif

/// Shared helper to manage a real MCP server process and a connected MCP Client.
/// Uses StdioTransport with the child process's stdin/stdout pipes.
actor SharedMCP {
    static let shared = SharedMCP()

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?

    private var client: Client?
    private var transport: StdioTransport?

    /// Ensure the server is built and a client is connected.
    func startIfNeeded() async throws -> Client {
        if let proc = process, proc.isRunning, let existing = client {
            return existing
        }

        try startServer()

        // Create client and connect over stdio transport wired to child pipes
        let client = Client(name: "TestClient", version: "1.0.0")
        guard let stdin = stdinPipe, let stdout = stdoutPipe else {
            throw MCPError.internalError("Pipes not initialized")
        }

        // Map pipes to FileDescriptor for StdioTransport
        let inFD = FileDescriptor(rawValue: stdout.fileHandleForReading.fileDescriptor)
        let outFD = FileDescriptor(rawValue: stdin.fileHandleForWriting.fileDescriptor)

        let transport = StdioTransport(input: inFD, output: outFD)
        async let _ = monitorStderr()
        let _ = try await client.connect(transport: transport)

        self.client = client
        self.transport = transport
        return client
    }

    /// Run closure with the shared client, serializing access.
    func withClient<T: Sendable>(_ body: @Sendable (Client) async throws -> T) async throws -> T {
        let client = try await startIfNeeded()
        return try await body(client)
    }

    /// Stop the client and terminate the server process.
    func stop() async {
        if let client = self.client {
            await client.disconnect()
        }
        if let process = self.process {
            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
            }
        }
        self.client = nil
        self.transport = nil
        self.stdinPipe = nil
        self.stdoutPipe = nil
        self.stderrPipe = nil
        self.process = nil
    }

    // MARK: - Private helpers

    private func startServer() throws {
        let fm = FileManager.default
        let cwd = fm.currentDirectoryPath
        let execPath = try resolveServerExecutablePath(cwd: cwd)

        let process = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()

        process.executableURL = URL(fileURLWithPath: execPath)
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()

        // Give it a moment to boot
        usleep(300_000)
        guard process.isRunning else {
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: errData, encoding: .utf8) ?? ""
            throw MCPError.internalError("Server failed to start. Stderr: \(msg)")
        }

        self.process = process
        self.stdinPipe = stdin
        self.stdoutPipe = stdout
        self.stderrPipe = stderr
    }

    private func resolveServerExecutablePath(cwd: String) throws -> String {
        let fm = FileManager.default
        let candidates = [
            "\(cwd)/.build/debug/mcp-file-search",
            "\(cwd)/.build/arm64-apple-macosx/debug/mcp-file-search",
            "\(cwd)/.build/x86_64-apple-macosx/debug/mcp-file-search"
        ]
        for path in candidates {
            if fm.fileExists(atPath: path) { return path }
        }
        // Fallback: search within .build for a debug binary named mcp-file-search
        let buildDir = "\(cwd)/.build"
        if let enumerator = fm.enumerator(atPath: buildDir) {
            for case let rel as String in enumerator {
                if rel.hasSuffix("/mcp-file-search"), rel.contains("/debug/") {
                    return "\(buildDir)/\(rel)"
                }
            }
        }
        throw MCPError.internalError("Server executable not found. Run 'make build' before tests.")
    }

    private func monitorStderr() async {
        guard let stderr = self.stderrPipe else { return }
        // Non-fatal: best-effort background read to keep pipe from filling
        let handle = stderr.fileHandleForReading
        while process?.isRunning == true {
            let data = handle.availableData
            if data.isEmpty { break }
            // Optionally log or ignore
        }
    }
}
