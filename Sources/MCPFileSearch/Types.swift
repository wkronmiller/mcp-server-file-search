import Foundation

/// Defines the type of search to perform on files (legacy - use FilterGroup for advanced queries)
public enum QueryType: String, Codable, Sendable {
    /// Search by file extension
    case `extension` = "extension"
    /// Search within file contents only
    case contents = "contents"
    /// Search by filename only
    case filename = "filename"
    /// Search both filename and contents
    case all = "all"
}

/// Defines how search results should be sorted
public enum SortOption: String, Codable, Sendable {
    /// Sort by filename
    case name = "name"
    /// Sort by modification date
    case dateModified = "dateModified"
    /// Sort by creation date
    case dateCreated = "dateCreated"
    /// Sort by file size
    case size = "size"
}

/// Defines the sort order for search results
public enum SortOrder: String, Codable, Sendable {
    /// Sort in ascending order
    case ascending = "ascending"
    /// Sort in descending order
    case descending = "descending"
}

/// Filter for date-based searches on modification dates
public struct DateFilter: Codable, Sendable {
    /// Start date for filtering (inclusive)
    let from: Date?
    /// End date for filtering (inclusive)
    let to: Date?
}

/// Filter for size-based searches on file sizes
public struct SizeFilter: Codable, Sendable {
    /// Minimum file size in bytes (inclusive)
    let minSize: Int64?
    /// Maximum file size in bytes (inclusive)
    let maxSize: Int64?
}

/// Individual filter criteria that can be combined
public enum SearchFilter: Codable, Sendable {
    /// Search within file contents
    case content(query: String)
    /// Search by filename
    case filename(query: String)
    /// Filter by file extensions (OR logic within extensions)
    case extensions([String])
    /// Filter by modification date range
    case dateModified(DateFilter)
    /// Filter by creation date range
    case dateCreated(DateFilter)
    /// Filter by file size range
    case size(SizeFilter)
    /// Limit to specific directory paths
    case paths([String])
}

/// Combination logic for multiple filters
public enum FilterCombination: String, Codable, Sendable {
    /// All filters must match (default)
    case and = "and"
    /// Any filter can match
    case or = "or"
}

/// Group of filters with combination logic
public struct FilterGroup: Codable, Sendable {
    /// List of filters to apply
    let filters: [SearchFilter]
    /// How to combine the filters (default: and)
    let combination: FilterCombination?
    
    public init(filters: [SearchFilter], combination: FilterCombination? = nil) {
        self.filters = filters
        self.combination = combination
    }
}

/// Advanced query structure supporting filter combinations
public struct AdvancedQuery: Codable, Sendable {
    /// Groups of filters (OR logic between groups, AND/OR logic within groups)
    let filterGroups: [FilterGroup]
    
    public init(filterGroups: [FilterGroup]) {
        self.filterGroups = filterGroups
    }
    
    /// Helper to create a simple single-group query
    public static func single(filters: [SearchFilter], combination: FilterCombination = .and) -> AdvancedQuery {
        return AdvancedQuery(filterGroups: [FilterGroup(filters: filters, combination: combination)])
    }
}

/// Arguments for configuring a file search operation
public struct SearchArgs: Codable, Sendable {
    /// The search query text (legacy - use advancedQuery for complex searches)
    let query: String
    /// Type of search to perform (defaults to .all if not specified, legacy)
    let queryType: QueryType?
    /// File extensions to search when queryType is .extension (legacy)
    let extensions: [String]?
    /// Limit search to specific directory paths (legacy - use advancedQuery)
    let onlyIn: [String]?
    /// Filter results by modification date range (legacy - use advancedQuery)
    let dateFilter: DateFilter?
    /// Advanced query with filter combinations
    let advancedQuery: AdvancedQuery?
    /// How to sort the results
    let sortBy: SortOption?
    /// Order for sorting results
    let sortOrder: SortOrder?
    /// Maximum number of results to return
    let limit: Int?
    /// Legacy parameter for backward compatibility - sets queryType to .filename
    let filenameOnly: Bool?
    /// Timeout in seconds for the Spotlight query (default: 10 seconds if not provided)
    let timeoutSeconds: Double?
    
    public init(query: String,
                queryType: QueryType? = nil,
                extensions: [String]? = nil,
                onlyIn: [String]? = nil,
                dateFilter: DateFilter? = nil,
                advancedQuery: AdvancedQuery? = nil,
                sortBy: SortOption? = nil,
                sortOrder: SortOrder? = nil,
                limit: Int? = nil,
                filenameOnly: Bool? = nil,
                timeoutSeconds: Double? = nil) {
        self.query = query
        self.extensions = extensions
        self.onlyIn = onlyIn
        self.dateFilter = dateFilter
        self.advancedQuery = advancedQuery
        self.sortBy = sortBy
        self.sortOrder = sortOrder
        self.limit = limit
        self.filenameOnly = filenameOnly
        self.timeoutSeconds = timeoutSeconds
        
        // Handle backward compatibility
        if let filenameOnly = filenameOnly, filenameOnly {
            self.queryType = .filename
        } else {
            self.queryType = queryType
        }
    }
    
    /// Helper to create SearchArgs with advanced query
    public static func advanced(_ advancedQuery: AdvancedQuery,
                               sortBy: SortOption? = nil,
                               sortOrder: SortOrder? = nil,
                               limit: Int? = nil,
                               timeoutSeconds: Double? = nil) -> SearchArgs {
        return SearchArgs(
            query: "", // Empty for advanced queries
            advancedQuery: advancedQuery,
            sortBy: sortBy,
            sortOrder: sortOrder,
            limit: limit,
            timeoutSeconds: timeoutSeconds
        )
    }
}

/// Represents a file found in a search operation
public struct SearchHit: Codable, Sendable {
    /// Full filesystem path to the file
    let path: String
    /// Filename without path
    let name: String
    /// File type description (e.g., "Plain Text", "JPEG Image")
    let kind: String?
    /// File size in bytes
    let size: Int64?
    /// File creation date
    let created: Date?
    /// File modification date
    let modified: Date?
}
