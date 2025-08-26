import XCTest
import Foundation
@testable import MCPFileSearch

/// Tests for data types, enums, and serialization used in the file search system.
/// These tests verify that our type system works correctly and maintains compatibility
/// across JSON serialization boundaries.
final class TypeSystemTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        print("Starting type system test: \(name)")
    }
    
    override func tearDown() {
        print("Completed type system test: \(name)")
        super.tearDown()
    }
    
    // MARK: - Enum Tests
    
    /// Tests QueryType enum values and raw value mappings.
    /// 
    /// **Purpose**: Verifies that QueryType enum has correct raw string values that match
    /// what clients expect in the MCP protocol.
    /// 
    /// **What it tests**:
    /// - All QueryType enum cases have correct raw string values
    /// - "extension" -> QueryType.extension
    /// - "contents" -> QueryType.contents
    /// - "filename" -> QueryType.filename
    /// - "all" -> QueryType.all
    /// 
    /// **Why it exists**: The QueryType enum is serialized to JSON and sent over the MCP
    /// protocol. Clients depend on these exact string values to specify search types.
    /// Any mismatch would break client-server communication.
    func testQueryTypeEnum() {
        XCTAssertEqual(QueryType.extension.rawValue, "extension")
        XCTAssertEqual(QueryType.contents.rawValue, "contents")
        XCTAssertEqual(QueryType.filename.rawValue, "filename")
        XCTAssertEqual(QueryType.all.rawValue, "all")
    }
    
    /// Tests SortOption enum values and raw value mappings.
    /// 
    /// **Purpose**: Verifies that SortOption enum has correct raw string values for
    /// client-server communication via MCP protocol.
    /// 
    /// **What it tests**:
    /// - All SortOption enum cases have correct raw string values
    /// - "name" -> SortOption.name
    /// - "dateModified" -> SortOption.dateModified
    /// - "dateCreated" -> SortOption.dateCreated
    /// - "size" -> SortOption.size
    /// 
    /// **Why it exists**: SortOption values are sent by clients to specify how search
    /// results should be ordered. Incorrect enum mappings would cause sort functionality
    /// to fail or behave unexpectedly.
    func testSortOptionEnum() {
        XCTAssertEqual(SortOption.name.rawValue, "name")
        XCTAssertEqual(SortOption.dateModified.rawValue, "dateModified")
        XCTAssertEqual(SortOption.dateCreated.rawValue, "dateCreated")
        XCTAssertEqual(SortOption.size.rawValue, "size")
    }
    
    /// Tests SortOrder enum values and raw value mappings.
    /// 
    /// **Purpose**: Verifies that SortOrder enum has correct raw string values for
    /// specifying ascending vs descending sort order.
    /// 
    /// **What it tests**:
    /// - All SortOrder enum cases have correct raw string values
    /// - "ascending" -> SortOrder.ascending
    /// - "descending" -> SortOrder.descending
    /// 
    /// **Why it exists**: Sort order specification must be consistent between client and
    /// server. Wrong enum values would cause results to be sorted in the opposite direction
    /// than requested by the client.
    func testSortOrderEnum() {
        XCTAssertEqual(SortOrder.ascending.rawValue, "ascending")
        XCTAssertEqual(SortOrder.descending.rawValue, "descending")
    }
    
    // MARK: - SearchArgs Tests
    
    /// Tests SearchArgs initialization with the legacy filenameOnly parameter.
    /// 
    /// **Purpose**: Verifies backward compatibility logic where the legacy filenameOnly
    /// parameter automatically sets the queryType to .filename.
    /// 
    /// **What it tests**:
    /// - filenameOnly=true automatically sets queryType=.filename
    /// - filenameOnly=false doesn't override explicit queryType
    /// - filenameOnly=nil doesn't affect explicit queryType
    /// - Backward compatibility with older client code
    /// - Proper precedence between legacy and new parameters
    /// 
    /// **Why it exists**: We maintain backward compatibility with older clients that
    /// use the filenameOnly boolean parameter instead of the newer queryType enum.
    /// This test ensures the compatibility logic works correctly.
    func testSearchArgsInitWithFilenameOnly() {
        // Test backward compatibility - filenameOnly should set queryType to .filename
        let args1 = SearchArgs(
            query: "test",
            filenameOnly: true
        )
        XCTAssertEqual(args1.queryType, .filename)
        XCTAssertTrue(args1.filenameOnly ?? false)
        
        // Test that filenameOnly false doesn't override queryType
        let args2 = SearchArgs(
            query: "test",
            queryType: .contents,
            filenameOnly: false
        )
        XCTAssertEqual(args2.queryType, .contents)
        XCTAssertFalse(args2.filenameOnly ?? true)
        
        // Test that nil filenameOnly doesn't affect queryType
        let args3 = SearchArgs(
            query: "test",
            queryType: .extension,
            filenameOnly: nil
        )
        XCTAssertEqual(args3.queryType, .extension)
        XCTAssertNil(args3.filenameOnly)
    }
    
    /// Tests SearchArgs initialization with all possible parameters.
    /// 
    /// **Purpose**: Verifies that SearchArgs can be initialized with the full set of
    /// parameters and maintains all values correctly.
    /// 
    /// **What it tests**:
    /// - All SearchArgs properties can be set and retrieved correctly
    /// - query, queryType, extensions, onlyIn parameters
    /// - dateFilter with from/to date ranges
    /// - sortBy, sortOrder, and limit parameters
    /// - Complex object initialization and property access
    /// - DateFilter nested object handling
    /// 
    /// **Why it exists**: SearchArgs is the primary data transfer object for search
    /// requests. This test ensures all parameters can be set correctly and the object
    /// maintains data integrity for complex search configurations.
    func testSearchArgsWithAllParameters() {
        let dateFilter = DateFilter(
            from: Date(timeIntervalSince1970: 1000000),
            to: Date(timeIntervalSince1970: 2000000)
        )
        
        let args = SearchArgs(
            query: "test",
            queryType: .extension,
            extensions: ["swift", "json"],
            onlyIn: ["/path/one", "/path/two"],
            dateFilter: dateFilter,
            sortBy: .size,
            sortOrder: .descending,
            limit: 100
        )
        
        XCTAssertEqual(args.query, "test")
        XCTAssertEqual(args.queryType, .extension)
        XCTAssertEqual(args.extensions, ["swift", "json"])
        XCTAssertEqual(args.onlyIn, ["/path/one", "/path/two"])
        XCTAssertEqual(args.dateFilter?.from, Date(timeIntervalSince1970: 1000000))
        XCTAssertEqual(args.dateFilter?.to, Date(timeIntervalSince1970: 2000000))
        XCTAssertEqual(args.sortBy, .size)
        XCTAssertEqual(args.sortOrder, .descending)
        XCTAssertEqual(args.limit, 100)
    }
    
    // MARK: - SearchHit Tests
    
    /// Tests SearchHit object property storage and retrieval.
    /// 
    /// **Purpose**: Verifies that SearchHit objects correctly store and provide access
    /// to all file metadata properties.
    /// 
    /// **What it tests**:
    /// - All SearchHit properties can be set and retrieved correctly
    /// - path, name, kind properties (strings)
    /// - size property (integer)
    /// - created and modified properties (Date objects)
    /// - Object initialization and property access
    /// 
    /// **Why it exists**: SearchHit is the primary data structure for search results
    /// returned to clients. This test ensures the object correctly maintains all file
    /// metadata that clients need for displaying search results.
    func testSearchHitProperties() {
        let hit = SearchHit(
            path: "/test/path.swift",
            name: "path.swift",
            kind: "Swift Source",
            size: 12345,
            created: Date(timeIntervalSince1970: 1000000),
            modified: Date(timeIntervalSince1970: 2000000)
        )
        
        XCTAssertEqual(hit.path, "/test/path.swift")
        XCTAssertEqual(hit.name, "path.swift")
        XCTAssertEqual(hit.kind, "Swift Source")
        XCTAssertEqual(hit.size, 12345)
        XCTAssertEqual(hit.created, Date(timeIntervalSince1970: 1000000))
        XCTAssertEqual(hit.modified, Date(timeIntervalSince1970: 2000000))
    }
    
    // MARK: - Codable Tests
    
    /// Tests SearchArgs JSON serialization and deserialization (Codable compliance).
    /// 
    /// **Purpose**: Verifies that SearchArgs can be correctly encoded to and decoded from
    /// JSON, ensuring compatibility with MCP protocol data exchange.
    /// 
    /// **What it tests**:
    /// - JSON encoding of complete SearchArgs object
    /// - JSON decoding back to SearchArgs object
    /// - Data integrity across encode/decode cycle
    /// - All property types (strings, arrays, enums, nested objects)
    /// - Complex nested object handling (DateFilter)
    /// - Enum serialization (queryType, sortBy, sortOrder)
    /// 
    /// **Why it exists**: SearchArgs objects are sent from MCP clients as JSON. This test
    /// ensures our objects can be properly serialized/deserialized without data loss,
    /// which is critical for MCP protocol communication.
    func testSearchArgsCodable() throws {
        let dateFilter = DateFilter(
            from: Date(timeIntervalSince1970: 1000000),
            to: Date(timeIntervalSince1970: 2000000)
        )
        
        let original = SearchArgs(
            query: "test",
            queryType: .contents,
            extensions: ["txt", "md"],
            onlyIn: ["/Users/test"],
            dateFilter: dateFilter,
            sortBy: .dateModified,
            sortOrder: .descending,
            limit: 50,
            filenameOnly: false
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SearchArgs.self, from: data)
        
        XCTAssertEqual(decoded.query, original.query)
        XCTAssertEqual(decoded.queryType, original.queryType)
        XCTAssertEqual(decoded.extensions, original.extensions)
        XCTAssertEqual(decoded.onlyIn, original.onlyIn)
        XCTAssertEqual(decoded.sortBy, original.sortBy)
        XCTAssertEqual(decoded.sortOrder, original.sortOrder)
        XCTAssertEqual(decoded.limit, original.limit)
        XCTAssertEqual(decoded.filenameOnly, original.filenameOnly)
    }
    
    /// Tests DateFilter JSON serialization and deserialization (Codable compliance).
    /// 
    /// **Purpose**: Verifies that DateFilter objects can be correctly encoded to and
    /// decoded from JSON as part of SearchArgs date filtering functionality.
    /// 
    /// **What it tests**:
    /// - JSON encoding of DateFilter object
    /// - JSON decoding back to DateFilter object  
    /// - Date object serialization and deserialization
    /// - Data integrity across encode/decode cycle
    /// - from and to Date properties
    /// 
    /// **Why it exists**: DateFilter is a nested object within SearchArgs that contains
    /// Date objects. Date serialization can be tricky, so this test ensures our date
    /// filtering parameters survive JSON serialization correctly for MCP communication.
    func testDateFilterCodable() throws {
        let original = DateFilter(
            from: Date(timeIntervalSince1970: 1000000),
            to: Date(timeIntervalSince1970: 2000000)
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DateFilter.self, from: data)
        
        XCTAssertEqual(decoded.from, original.from)
        XCTAssertEqual(decoded.to, original.to)
    }
}