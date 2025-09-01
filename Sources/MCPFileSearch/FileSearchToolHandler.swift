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
            description: "Advanced Spotlight-backed file search on macOS with support for complex filter combinations using AND/OR logic.",
            inputSchema: .object([
                "type": .string("object"),
                "properties": .object([
                    // Legacy parameters (for backward compatibility)
                    "query": .object([
                        "type": .string("string"),
                        "description": .string("Search text. Meaning depends on queryType. For 'extension' type, can be file extension without dot. For other types, supports wildcards (*) and exact phrases. Use advancedQuery for complex searches.")
                    ]),
                    "queryType": .object([
                        "type": .string("string"),
                        "enum": .array([
                            .string("extension"),
                            .string("contents"),
                            .string("filename"),
                            .string("all")
                        ]),
                        "description": .string("Type of search: 'extension' (by file extension), 'contents' (file content only), 'filename' (filename only), 'all' (both filename and content). Default: 'all'. Use advancedQuery for more control.")
                    ]),
                    "extensions": .object([
                        "type": .string("array"),
                        "items": .object(["type": .string("string")]),
                        "description": .string("List of file extensions to search (without dots). Used with queryType='extension'. Use advancedQuery for more control.")
                    ]),
                    "onlyIn": .object([
                        "type": .string("array"),
                        "items": .object(["type": .string("string")]),
                        "description": .string("Absolute paths to limit search scope. Use advancedQuery for more control.")
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
                        "description": .string("Filter results by modification date range. Use advancedQuery for more control.")
                    ]),
                    "filenameOnly": .object([
                        "type": .string("boolean"),
                        "description": .string("Legacy parameter. If true, sets queryType to 'filename'.")
                    ]),
                    
                    // Advanced query parameter
                    "advancedQuery": .object([
                        "type": .string("object"),
                        "properties": .object([
                            "filterGroups": .object([
                                "type": .string("array"),
                                "items": .object([
                                    "type": .string("object"),
                                    "properties": .object([
                                        "filters": .object([
                                            "type": .string("array"),
                                            "description": .string("Array of filter criteria"),
                                            "items": .object([
                                                "type": .string("object"),
                                                "description": .string("Filter criterion. Use one of: {content: {query: 'text'}}, {filename: {query: 'text'}}, {extensions: ['ext1', 'ext2']}, {dateModified: {from: 'ISO-date', to: 'ISO-date'}}, {dateCreated: {from: 'ISO-date', to: 'ISO-date'}}, {size: {minSize: bytes, maxSize: bytes}}, {paths: ['/path1', '/path2']}")
                                            ])
                                        ]),
                                        "combination": .object([
                                            "type": .string("string"),
                                            "enum": .array([.string("and"), .string("or")]),
                                            "description": .string("How to combine filters within this group. Default: 'and'")
                                        ])
                                    ]),
                                    "required": .array([.string("filters")])
                                ])
                            ])
                        ]),
                        "required": .array([.string("filterGroups")]),
                        "description": .string("Advanced query with filter combinations. Groups are combined with OR logic, filters within groups use AND logic (or OR if specified). Example: {filterGroups: [{filters: [{content: {query: 'foo'}}, {extensions: ['pdf', 'docx']}]}]} finds documents containing 'foo' AND having pdf/docx extensions.")
                    ]),
                    
                    // Common parameters
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
                    "timeoutSeconds": .object([
                        "type": .string("number"),
                        "description": .string("Timeout in seconds before returning partial results. Default: 10")
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
            
            // Parse advanced query if present
            var advancedQuery: AdvancedQuery? = nil
            if let advancedQueryValue = params.arguments?["advancedQuery"],
               case .object(let advancedObj) = advancedQueryValue {
                advancedQuery = try parseAdvancedQuery(from: advancedObj)
                Logger.debug("AdvancedQuery parsed with \(advancedQuery?.filterGroups.count ?? 0) filter groups")
            }
            
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
            
            // Extract timeoutSeconds number if present
            var timeoutSeconds: Double? = nil
            if let timeoutValue = params.arguments?["timeoutSeconds"] {
                switch timeoutValue {
                case .double(let d):
                    timeoutSeconds = d
                case .int(let i):
                    timeoutSeconds = Double(i)
                case .string(let s):
                    timeoutSeconds = Double(s)
                default:
                    break
                }
            }
            Logger.debug("TimeoutSeconds parameter: \(timeoutSeconds?.description ?? "not specified")")
            
            // Create SearchArgs with all parameters including advanced query
            let args = SearchArgs(
                query: query,
                queryType: queryType,
                extensions: extensions,
                onlyIn: onlyIn,
                dateFilter: dateFilter,
                advancedQuery: advancedQuery,
                sortBy: sortBy,
                sortOrder: sortOrder,
                limit: limit,
                filenameOnly: filenameOnly,
                timeoutSeconds: timeoutSeconds
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
    
    /// Parses advanced query from MCP Value object structure
    /// - Parameter advancedObj: Dictionary containing filterGroups
    /// - Returns: AdvancedQuery object
    /// - Throws: Error if parsing fails
    private static func parseAdvancedQuery(from advancedObj: [String: MCP.Value]) throws -> AdvancedQuery {
        guard let filterGroupsValue = advancedObj["filterGroups"],
              case .array(let groupArray) = filterGroupsValue else {
            throw NSError(domain: "ParseError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid filterGroups"])
        }
        
        let filterGroups = try groupArray.map { groupValue in
            guard case .object(let groupObj) = groupValue else {
                throw NSError(domain: "ParseError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid filter group object"])
            }
            return try parseFilterGroup(from: groupObj)
        }
        
        return AdvancedQuery(filterGroups: filterGroups)
    }
    
    /// Parses a filter group from MCP Value object
    /// - Parameter groupObj: Dictionary containing filters and combination
    /// - Returns: FilterGroup object
    /// - Throws: Error if parsing fails
    private static func parseFilterGroup(from groupObj: [String: MCP.Value]) throws -> FilterGroup {
        guard let filtersValue = groupObj["filters"],
              case .array(let filtersArray) = filtersValue else {
            throw NSError(domain: "ParseError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing or invalid filters array"])
        }
        
        let filters = try filtersArray.map { filterValue in
            guard case .object(let filterObj) = filterValue else {
                throw NSError(domain: "ParseError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid filter object"])
            }
            return try parseSearchFilter(from: filterObj)
        }
        
        let combination: FilterCombination?
        if let combinationValue = groupObj["combination"]?.stringValue {
            combination = FilterCombination(rawValue: combinationValue)
        } else {
            combination = nil
        }
        
        return FilterGroup(filters: filters, combination: combination)
    }
    
    /// Parses a search filter from MCP Value object
    /// - Parameter filterObj: Dictionary containing filter criteria
    /// - Returns: SearchFilter object
    /// - Throws: Error if parsing fails
    private static func parseSearchFilter(from filterObj: [String: MCP.Value]) throws -> SearchFilter {
        // Try each filter type
        if let contentValue = filterObj["content"],
           case .object(let contentObj) = contentValue,
           let query = contentObj["query"]?.stringValue {
            return .content(query: query)
        }
        
        if let filenameValue = filterObj["filename"],
           case .object(let filenameObj) = filenameValue,
           let query = filenameObj["query"]?.stringValue {
            return .filename(query: query)
        }
        
        if let extensionsValue = filterObj["extensions"],
           case .array(let extArray) = extensionsValue {
            let extensions = extArray.compactMap { $0.stringValue }
            return .extensions(extensions)
        }
        
        if let dateModifiedValue = filterObj["dateModified"],
           case .object(let dateObj) = dateModifiedValue {
            let dateFilter = try parseDateFilter(from: dateObj)
            return .dateModified(dateFilter)
        }
        
        if let dateCreatedValue = filterObj["dateCreated"],
           case .object(let dateObj) = dateCreatedValue {
            let dateFilter = try parseDateFilter(from: dateObj)
            return .dateCreated(dateFilter)
        }
        
        if let sizeValue = filterObj["size"],
           case .object(let sizeObj) = sizeValue {
            let sizeFilter = try parseSizeFilter(from: sizeObj)
            return .size(sizeFilter)
        }
        
        if let pathsValue = filterObj["paths"],
           case .array(let pathArray) = pathsValue {
            let paths = pathArray.compactMap { $0.stringValue }
            return .paths(paths)
        }
        
        throw NSError(domain: "ParseError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Unknown or invalid filter type"])
    }
    
    /// Parses a date filter from MCP Value object
    /// - Parameter dateObj: Dictionary containing from/to dates
    /// - Returns: DateFilter object
    /// - Throws: Error if parsing fails
    private static func parseDateFilter(from dateObj: [String: MCP.Value]) throws -> DateFilter {
        let formatter = ISO8601DateFormatter()
        let from = dateObj["from"]?.stringValue.flatMap { formatter.date(from: $0) }
        let to = dateObj["to"]?.stringValue.flatMap { formatter.date(from: $0) }
        return DateFilter(from: from, to: to)
    }
    
    /// Parses a size filter from MCP Value object
    /// - Parameter sizeObj: Dictionary containing minSize/maxSize
    /// - Returns: SizeFilter object
    /// - Throws: Error if parsing fails
    private static func parseSizeFilter(from sizeObj: [String: MCP.Value]) throws -> SizeFilter {
        let minSize: Int64?
        if let minValue = sizeObj["minSize"] {
            switch minValue {
            case .int(let i):
                minSize = Int64(i)
            case .double(let d):
                minSize = Int64(d)
            case .string(let s):
                minSize = Int64(s)
            default:
                minSize = nil
            }
        } else {
            minSize = nil
        }
        
        let maxSize: Int64?
        if let maxValue = sizeObj["maxSize"] {
            switch maxValue {
            case .int(let i):
                maxSize = Int64(i)
            case .double(let d):
                maxSize = Int64(d)
            case .string(let s):
                maxSize = Int64(s)
            default:
                maxSize = nil
            }
        } else {
            maxSize = nil
        }
        
        return SizeFilter(minSize: minSize, maxSize: maxSize)
    }
}
