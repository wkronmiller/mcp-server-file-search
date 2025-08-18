import Foundation

struct SearchArgs: Codable {
    /// Plain text to match. If `filenameOnly==true`, applies to filename; else full-text/metadata.
    var query: String
    /// Optional list of absolute paths to limit search (equivalent to `mdfind -onlyin`).
    var onlyIn: [String]?
    /// If true, restrict to file name match only (no contents/metadata).
    var filenameOnly: Bool?
    /// Optional max results (default 200).
    var limit: Int?
}

struct SearchHit: Codable {
    var path: String
    var name: String
    var kind: String?
    var modified: Date?
}
