import XCTest
@testable import MCPFileSearch
import CoreServices

final class QueryBuilderTests: XCTestCase {
    
    func testLegacyQueryTypeAll() {
        let args = SearchArgs(query: "test", queryType: .all)
        let predicate = QueryBuilder.buildPredicate(for: args)
        
        // Should create OR predicate for filename and content
        XCTAssertNotNil(predicate)
        let description = predicate.description
        XCTAssertTrue(description.contains("kMDItemFSName"))
        XCTAssertTrue(description.contains("kMDItemTextContent"))
        XCTAssertTrue(description.contains("OR"))
    }
    
    func testLegacyQueryTypeExtension() {
        let args = SearchArgs(query: "swift", queryType: .extension)
        let predicate = QueryBuilder.buildPredicate(for: args)
        
        let description = predicate.description
        XCTAssertTrue(description.contains("kMDItemFSName"))
        XCTAssertTrue(description.contains("*.swift"))
    }
    
    func testLegacyExtensionsArray() {
        let args = SearchArgs(query: "", queryType: .extension, extensions: ["swift", "py", "js"])
        let predicate = QueryBuilder.buildPredicate(for: args)
        
        let description = predicate.description
        XCTAssertTrue(description.contains("kMDItemFSName"))
        XCTAssertTrue(description.contains("*.swift"))
        XCTAssertTrue(description.contains("*.py"))
        XCTAssertTrue(description.contains("*.js"))
    }
    
    func testSimpleAdvancedQuery() {
        let contentFilter = SearchFilter.content(query: "hello")
        let extensionsFilter = SearchFilter.extensions(["pdf", "docx"])
        let filterGroup = FilterGroup(filters: [contentFilter, extensionsFilter])
        let advancedQuery = AdvancedQuery(filterGroups: [filterGroup])
        let args = SearchArgs.advanced(advancedQuery)
        
        let predicate = QueryBuilder.buildPredicate(for: args)
        let description = predicate.description
        
        // Should contain both content and extension predicates with AND logic
        XCTAssertTrue(description.contains("kMDItemTextContent"))
        XCTAssertTrue(description.contains("*hello*"))
        XCTAssertTrue(description.contains("kMDItemFSName"))
        XCTAssertTrue(description.contains("*.pdf"))
        XCTAssertTrue(description.contains("*.docx"))
        XCTAssertTrue(description.contains("AND"))
    }
    
    func testAdvancedQueryWithORCombination() {
        let contentFilter = SearchFilter.content(query: "hello")
        let filenameFilter = SearchFilter.filename(query: "world")
        let filterGroup = FilterGroup(filters: [contentFilter, filenameFilter], combination: .or)
        let advancedQuery = AdvancedQuery(filterGroups: [filterGroup])
        let args = SearchArgs.advanced(advancedQuery)
        
        let predicate = QueryBuilder.buildPredicate(for: args)
        let description = predicate.description
        
        // Should contain both content and filename predicates with OR logic
        XCTAssertTrue(description.contains("kMDItemTextContent"))
        XCTAssertTrue(description.contains("*hello*"))
        XCTAssertTrue(description.contains("kMDItemFSName"))
        XCTAssertTrue(description.contains("*world*"))
        XCTAssertTrue(description.contains("OR"))
    }
    
    func testAdvancedQueryMultipleGroups() {
        let contentFilter = SearchFilter.content(query: "foo")
        let extensionsFilter = SearchFilter.extensions(["pdf"])
        let group1 = FilterGroup(filters: [contentFilter, extensionsFilter])
        
        let filenameFilter = SearchFilter.filename(query: "bar")
        let group2 = FilterGroup(filters: [filenameFilter])
        
        let advancedQuery = AdvancedQuery(filterGroups: [group1, group2])
        let args = SearchArgs.advanced(advancedQuery)
        
        let predicate = QueryBuilder.buildPredicate(for: args)
        let description = predicate.description
        
        // Should have OR between groups, AND within groups
        XCTAssertTrue(description.contains("kMDItemTextContent"))
        XCTAssertTrue(description.contains("*foo*"))
        XCTAssertTrue(description.contains("*.pdf"))
        XCTAssertTrue(description.contains("*bar*"))
    }
    
    func testDateFilter() {
        let formatter = ISO8601DateFormatter()
        let fromDate = formatter.date(from: "2024-01-01T00:00:00Z")!
        let toDate = formatter.date(from: "2024-12-31T23:59:59Z")!
        let dateFilter = DateFilter(from: fromDate, to: toDate)
        let filter = SearchFilter.dateModified(dateFilter)
        let filterGroup = FilterGroup(filters: [filter])
        let advancedQuery = AdvancedQuery(filterGroups: [filterGroup])
        let args = SearchArgs.advanced(advancedQuery)
        
        let predicate = QueryBuilder.buildPredicate(for: args)
        let description = predicate.description
        
        XCTAssertTrue(description.contains("kMDItemFSContentChangeDate"))
        XCTAssertTrue(description.contains(">="))
        XCTAssertTrue(description.contains("<="))
    }
    
    func testSizeFilter() {
        let sizeFilter = SizeFilter(minSize: 1024, maxSize: 1048576) // 1KB to 1MB
        let filter = SearchFilter.size(sizeFilter)
        let filterGroup = FilterGroup(filters: [filter])
        let advancedQuery = AdvancedQuery(filterGroups: [filterGroup])
        let args = SearchArgs.advanced(advancedQuery)
        
        let predicate = QueryBuilder.buildPredicate(for: args)
        let description = predicate.description
        
        XCTAssertTrue(description.contains("kMDItemFSSize"))
        XCTAssertTrue(description.contains(">="))
        XCTAssertTrue(description.contains("<="))
    }
    
    func testSearchScopes() {
        let pathFilter = SearchFilter.paths(["/Users/test/Documents", "/Users/test/Desktop"])
        let filterGroup = FilterGroup(filters: [pathFilter])
        let advancedQuery = AdvancedQuery(filterGroups: [filterGroup])
        let args = SearchArgs.advanced(advancedQuery)
        
        let scopes = QueryBuilder.extractSearchScopes(from: args)
        
        XCTAssertEqual(scopes.count, 2)
        XCTAssertTrue(scopes.contains("/Users/test/Documents"))
        XCTAssertTrue(scopes.contains("/Users/test/Desktop"))
    }
    
    func testLegacySearchScopes() {
        let args = SearchArgs(query: "test", onlyIn: ["/tmp", "/var"])
        let scopes = QueryBuilder.extractSearchScopes(from: args)
        
        XCTAssertEqual(scopes.count, 2)
        XCTAssertTrue(scopes.contains("/tmp"))
        XCTAssertTrue(scopes.contains("/var"))
    }
    
    func testDefaultSearchScopes() {
        let args = SearchArgs(query: "test")
        let scopes = QueryBuilder.extractSearchScopes(from: args)
        
        XCTAssertEqual(scopes.count, 1)
        XCTAssertEqual(scopes.first, NSMetadataQueryLocalComputerScope)
    }
    
    func testComplexExampleQuery() {
        // Example: "document contains foo AND document extension is either docx or pdf"
        let contentFilter = SearchFilter.content(query: "foo")
        let extensionsFilter = SearchFilter.extensions(["docx", "pdf"])
        let filterGroup = FilterGroup(filters: [contentFilter, extensionsFilter], combination: .and)
        let advancedQuery = AdvancedQuery(filterGroups: [filterGroup])
        let args = SearchArgs.advanced(advancedQuery)
        
        let predicate = QueryBuilder.buildPredicate(for: args)
        let description = predicate.description
        
        // Should contain content search for "foo"
        XCTAssertTrue(description.contains("kMDItemTextContent"))
        XCTAssertTrue(description.contains("*foo*"))
        
        // Should contain extension filters for docx and pdf
        XCTAssertTrue(description.contains("kMDItemFSName"))
        XCTAssertTrue(description.contains("*.docx"))
        XCTAssertTrue(description.contains("*.pdf"))
        
        // Should use AND to combine content and extensions
        XCTAssertTrue(description.contains("AND"))
    }
}