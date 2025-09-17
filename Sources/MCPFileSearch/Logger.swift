import Foundation

/// Log levels for filtering log output
public enum LogLevel: String {
    /// Detailed debugging information
    case debug = "DEBUG"
    /// General informational messages
    case info = "INFO"
    /// Warning messages for potential issues
    case warning = "WARN"
    /// Error messages for failures
    case error = "ERROR"
}

/// Thread-safe logger that writes to both stderr and a log file
/// Log files are stored in ~/.local/share/mcp-file-search/log/
public class Logger {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    private static let logFileURL: URL? = {
        let pid = ProcessInfo.processInfo.processIdentifier
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let logDir = homeDir.appendingPathComponent(".local/share/mcp-file-search/log")
        
        // Create log directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true, attributes: nil)
            let logFile = logDir.appendingPathComponent("\(pid).log")
            return logFile
        } catch {
            // Use system print for error output
            print("Warning: Failed to create log directory: \(error)")
            return nil
        }
    }()
    
    private static let logQueue = DispatchQueue(label: "com.mcpfilesearch.logger", qos: .utility)
    
    /// Logs a message at the specified level
    /// - Parameters:
    ///   - level: The log level
    ///   - message: The message to log
    ///   - file: Source file (automatically captured)
    ///   - function: Source function (automatically captured)
    ///   - line: Source line number (automatically captured)
    public static func log(_ level: LogLevel, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let timestamp = dateFormatter.string(from: Date())
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(timestamp)] [\(level.rawValue)] [\(fileName):\(line)] \(function): \(message)\n"
        
        // Always log to stderr for immediate feedback
        print(logMessage, terminator: "")
        
        // Also log to file if available
        if let logFileURL = logFileURL {
            logQueue.async {
                do {
                    if !FileManager.default.fileExists(atPath: logFileURL.path) {
                        FileManager.default.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
                    }
                    
                    let fileHandle = try FileHandle(forWritingTo: logFileURL)
                    defer { fileHandle.closeFile() }
                    
                    fileHandle.seekToEndOfFile()
                    if let data = logMessage.data(using: .utf8) {
                        fileHandle.write(data)
                    }
                } catch {
                    // Silently fail to avoid recursive logging
                }
            }
        }
    }
    
    /// Logs a debug message
    public static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message, file: file, function: function, line: line)
    }
    
    /// Logs an info message
    public static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message, file: file, function: function, line: line)
    }
    
    /// Logs a warning message
    public static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message, file: file, function: function, line: line)
    }
    
    /// Logs an error message
    public static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message, file: file, function: function, line: line)
    }
}
