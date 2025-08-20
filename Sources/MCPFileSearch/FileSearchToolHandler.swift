import Foundation
import MCP

/// Handles the file-search tool implementation for the MCP server
/// Provides advanced Spotlight-based file search with multiple query types and filtering
public class FileSearchToolHandler {
    
    /// Returns the tool definition for the file-search tool
    /// - Returns: Tool definition with complete parameter schema
    public static func getToolDefinition() -> Tool {
        return Tool(
            name: "file-search",
            description: "Advanced Spotlight-backed file search on macOS with multiple query types, date filtering, and sorting.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    "query": .object([
                        "type": .string("string"),
                        "description": .string("Search text. Meaning depends on queryType. For 'extension' type, can be file extension without dot. For other types, supports wildcards (*) and exact phrases.")
                    ]),
                    "queryType": .object([
                        "type": .string("string"),
                        "enum": .array([
                            .string("extension"),
                            .string("contents"),
                            .string("filename"),
                            .string("all")
                        ]),
                        "description": .string("Type of search: 'extension' (by file extension), 'contents' (file content only), 'filename' (filename only), 'all' (both filename and content). Default: 'all'")
                    ]),
                    "extensions": .object([
                        "type": .string("array"),
                        "items": .object(["type": .string("string")]),
                        "description": .string("List of file extensions to search (without dots). Used with queryType='extension'.")
                    ]),
                    "onlyIn": .object([
                        "type": .string("array"),
                        "items": .object(["type": .string("string")]),
                        "description": .string("Absolute paths to limit search scope")
                    ]),
                    "dateFilter": .object([
                        "type": .string("object"),
                        "properties": .object([
                            "from": .object([
                                "type": .string("string"),
                                "format": .string("date-time"),
                                "description": .string("ISO 8601 date string for start of date range")
                            ]),
                            "to": .object([
                                "type": .string("string"),
                                "format": .string("date-time"),
                                "description": .string("ISO 8601 date string for end of date range")
                            ])
                        ]),
                        "description": .string("Filter results by modification date range")
                    ]),
                    "sortBy": .object([
                        "type": .string("string"),
                        "enum": .array([
                            .string("name"),
                            .string("dateModified"),
                            .string("dateCreated"),
                            .string("size")
                        ]),
                        "description": .string("Sort results by: name, dateModified, dateCreated, or size. Default: 'name'")
                    ]),
                    "sortOrder": .object([
                        "type": .string("string"),
                        "enum": .array([
                            .string("ascending"),
                            .string("descending")
                        ]),
                        "description": .string("Sort order. Default: 'ascending'")
                    ]),
                    "limit": .object([
                        "type": .string("number"),
                        "description": .string("Max results to return. Default: 200")
                    ]),
                    "filenameOnly": .object([
                        "type": .string("boolean"),
                        "description": .string("Legacy parameter. If true, sets queryType to 'filename'.")
                    ])
                ]),
                "required": .array([])
            ])
        )
    }
    
    /// Handles incoming tool call requests for the file-search tool
    /// - Parameter params: The tool call parameters containing search arguments
    /// - Returns: Tool call result with search results or error information
    public static func handleToolCall(_ params: CallTool.Parameters) async -> CallTool.Result {
        Logger.info("FileSearchToolHandler: CallTool request received - tool: \(params.name)")
        
        guard params.name == "file-search" else {
            Logger.warning("Unknown tool requested: \(params.name)")
            return .init(content: [.text("Unknown tool")], isError: true)
        }

        do {
            Logger.debug("Parsing tool arguments")
            
            // Extract arguments from Value type
            let query = params.arguments?["query"]?.stringValue ?? ""
            Logger.debug("Query parameter: '\(query)'")
            
            // Parse queryType
            let queryTypeStr = params.arguments?["queryType"]?.stringValue
            let queryType = queryTypeStr.flatMap { QueryType(rawValue: $0) }
            Logger.debug("QueryType parameter: \(queryType?.rawValue ?? "not specified")")
            
            // Parse extensions array
            var extensions: [String]? = nil
            if let extensionsValue = params.arguments?["extensions"],
               case .array(let arrayValues) = extensionsValue {
                extensions = arrayValues.compactMap { $0.stringValue }
                Logger.debug("Extensions parameter: \(extensions?.joined(separator: ", ") ?? "none")")
            }
            
            // Extract onlyIn array if present
            var onlyIn: [String]? = nil
            if let onlyInValue = params.arguments?["onlyIn"],
               case .array(let arrayValues) = onlyInValue {
                onlyIn = arrayValues.compactMap { $0.stringValue }
                Logger.debug("OnlyIn parameter: \(onlyIn?.joined(separator: ", ") ?? "none")")
            }
            
            // Parse dateFilter
            var dateFilter: DateFilter? = nil
            if let dateFilterValue = params.arguments?["dateFilter"],
               case .object(let dateObj) = dateFilterValue {
                let formatter = ISO8601DateFormatter()
                let from = dateObj["from"]?.stringValue.flatMap { formatter.date(from: $0) }
                let to = dateObj["to"]?.stringValue.flatMap { formatter.date(from: $0) }
                if from != nil || to != nil {
                    dateFilter = DateFilter(from: from, to: to)
                    Logger.debug("DateFilter - from: \(from?.description ?? "nil"), to: \(to?.description ?? "nil")")
                }
            }
            
            // Parse sort options
            let sortByStr = params.arguments?["sortBy"]?.stringValue
            let sortBy = sortByStr.flatMap { SortOption(rawValue: $0) }
            Logger.debug("SortBy parameter: \(sortBy?.rawValue ?? "not specified")")
            
            let sortOrderStr = params.arguments?["sortOrder"]?.stringValue
            let sortOrder = sortOrderStr.flatMap { SortOrder(rawValue: $0) }
            Logger.debug("SortOrder parameter: \(sortOrder?.rawValue ?? "not specified")")
            
            // Extract filenameOnly boolean if present (for backward compatibility)
            let filenameOnly = params.arguments?["filenameOnly"]?.boolValue
            Logger.debug("FilenameOnly parameter: \(filenameOnly?.description ?? "not specified")")
            
            // Extract limit number if present
            var limit: Int? = nil
            if let limitValue = params.arguments?["limit"] {
                switch limitValue {
                case .int(let num):
                    limit = num
                case .double(let num):
                    limit = Int(num)
                case .string(let str):
                    limit = Int(str)
                default:
                    break
                }
            }
            Logger.debug("Limit parameter: \(limit?.description ?? "not specified")")
            
            // Create SearchArgs with all new parameters
            let args = SearchArgs(
                query: query,
                queryType: queryType,
                extensions: extensions,
                onlyIn: onlyIn,
                dateFilter: dateFilter,
                sortBy: sortBy,
                sortOrder: sortOrder,
                limit: limit,
                filenameOnly: filenameOnly
            )

            Logger.info("Starting Spotlight search with query: '\(query)'")
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Run Spotlight query using the new actor-based implementation
            let hits = try await SpotlightSearchActor.shared.search(args)
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            Logger.info("Search completed in \(String(format: "%.3f", duration))s - found \(hits.count) results")

            // Encode JSON response
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let payload = try encoder.encode(hits)
            let json = String(data: payload, encoding: .utf8) ?? "[]"

            Logger.debug("Response JSON size: \(json.count) characters")
            return .init(content: [.text(json)], isError: false)
        } catch {
            Logger.error("Search failed with error: \(error.localizedDescription)")
            let nsError = error as NSError
            Logger.error("Error domain: \(nsError.domain), code: \(nsError.code)")
            Logger.error("Error userInfo: \(nsError.userInfo)")
            return .init(content: [.text("Search failed: \(error.localizedDescription)")], isError: true)
        }
    }
}
