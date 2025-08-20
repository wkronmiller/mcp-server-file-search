import Foundation

/// Defines the type of search to perform on files
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

/// Arguments for configuring a file search operation
public struct SearchArgs: Codable, Sendable {
    /// The search query text
    let query: String
    /// Type of search to perform (defaults to .all if not specified)
    let queryType: QueryType?
    /// File extensions to search when queryType is .extension
    let extensions: [String]?
    /// Limit search to specific directory paths
    let onlyIn: [String]?
    /// Filter results by modification date range
    let dateFilter: DateFilter?
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
                sortBy: SortOption? = nil,
                sortOrder: SortOrder? = nil,
                limit: Int? = nil,
                filenameOnly: Bool? = nil,
                timeoutSeconds: Double? = nil) {
        self.query = query
        self.extensions = extensions
        self.onlyIn = onlyIn
        self.dateFilter = dateFilter
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
