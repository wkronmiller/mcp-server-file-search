import XCTest
import MCP
@testable import MCPFileSearch

final class E2EFileSearchTests: XCTestCase {
    override func setUpWithError() throws {
        #if !os(macOS)
        throw XCTSkip("E2E tests require macOS")
        #endif
    }
    
    override func tearDown() async throws {
        await SharedMCP.shared.stop()
        try await super.tearDown()
    }
    // Helper to decode tool text content into [SearchHit]
    private static func decodeHits(from content: [Tool.Content]) throws -> [SearchHit] {
        guard let first = content.first else { return [] }
        switch first {
        case .text(let json):
            let data = Data(json.utf8)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([SearchHit].self, from: data)
        default:
            return []
        }
    }

    func testListTools_e2e() async throws {
        try await SharedMCP.shared.withClient { client in
            let (tools, _) = try await client.listTools()
            XCTAssertGreaterThan(tools.count, 0)
            let tool = try XCTUnwrap(tools.first { $0.name == "file-search" })
            XCTAssertTrue(tool.description.contains("complex filter combinations"))
        }
    }

    func testLegacyFilenameOnlyInRepo_e2e() async throws {
        let cwd = FileManager.default.currentDirectoryPath
        try await SharedMCP.shared.withClient { client in
            let args: [String: Value] = [
                "query": .string("Package.swift"),
                "filenameOnly": .bool(true),
                "onlyIn": .array([.string(cwd)]),
                "limit": .int(10),
                "timeoutSeconds": .double(3)
            ]
            let (content, isError) = try await client.callTool(name: "file-search", arguments: args)
            XCTAssertNotEqual(isError, true)
            let hits = try Self.decodeHits(from: content)
            XCTAssertGreaterThan(hits.count, 0)
            // Expect at least one result in current repo
            XCTAssertTrue(hits.contains { $0.path.hasPrefix(cwd) && $0.name == "Package.swift" })
        }
    }

    func testAdvancedQuery_ANDWithinGroup_e2e() async throws {
        let cwd = FileManager.default.currentDirectoryPath
        try await SharedMCP.shared.withClient { client in
            // filename contains "Types.swift" AND extension swift
            let advanced: Value = .object([
                "filterGroups": .array([
                    .object([
                        "filters": .array([
                            .object(["filename": .object(["query": .string("Types.swift")])]),
                            .object(["extensions": .array([.string("swift")])])
                        ]),
                        "combination": .string("and")
                    ])
                ])
            ])

            let args: [String: Value] = [
                "advancedQuery": advanced,
                "onlyIn": .array([.string(cwd)]),
                "limit": .int(25),
                "timeoutSeconds": .double(3)
            ]

            let (content, isError) = try await client.callTool(name: "file-search", arguments: args)
            XCTAssertNotEqual(isError, true)
            let hits = try Self.decodeHits(from: content)
            XCTAssertTrue(hits.contains { $0.name == "Types.swift" && $0.path.hasPrefix(cwd) })
        }
    }

    func testAdvancedQuery_ORAcrossGroups_e2e() async throws {
        let cwd = FileManager.default.currentDirectoryPath
        try await SharedMCP.shared.withClient { client in
            // Group1: filename Types.swift
            // Group2: filename Package.swift
            let advanced: Value = .object([
                "filterGroups": .array([
                    .object([
                        "filters": .array([
                            .object(["filename": .object(["query": .string("Types.swift")])])
                        ])
                    ]),
                    .object([
                        "filters": .array([
                            .object(["filename": .object(["query": .string("Package.swift")])])
                        ])
                    ])
                ])
            ])

            let args: [String: Value] = [
                "advancedQuery": advanced,
                "onlyIn": .array([.string(cwd)]),
                "limit": .int(50),
                "timeoutSeconds": .double(3)
            ]

            let (content, isError) = try await client.callTool(name: "file-search", arguments: args)
            XCTAssertNotEqual(isError, true)
            let hits = try Self.decodeHits(from: content)
            let names = Set(hits.map { $0.name })
            XCTAssertTrue(names.contains("Types.swift"))
            XCTAssertTrue(names.contains("Package.swift"))
        }
    }

    func testSortingAndLimit_e2e() async throws {
        let cwd = FileManager.default.currentDirectoryPath
        try await SharedMCP.shared.withClient { client in
            // Extension swift within repo, sorted by name ascending, limit 3
            let advanced: Value = .object([
                "filterGroups": .array([
                    .object([
                        "filters": .array([
                            .object(["extensions": .array([.string("swift")])])
                        ])
                    ])
                ])
            ])

            let args: [String: Value] = [
                "advancedQuery": advanced,
                "onlyIn": .array([.string(cwd)]),
                "sortBy": .string("name"),
                "sortOrder": .string("ascending"),
                "limit": .int(3),
                "timeoutSeconds": .double(3)
            ]
            let (content, isError) = try await client.callTool(name: "file-search", arguments: args)
            XCTAssertNotEqual(isError, true)
            let hits = try Self.decodeHits(from: content)
            XCTAssertLessThanOrEqual(hits.count, 3)
            let names = hits.map { $0.name }
            XCTAssertEqual(names, names.sorted())
        }
    }

    func testInvalidAdvancedQuery_e2e() async throws {
        try await SharedMCP.shared.withClient { client in
            // Missing required "filters" inside a group
            let badAdvanced: Value = .object([
                "filterGroups": .array([
                    .object([:])
                ])
            ])
            let args: [String: Value] = [
                "advancedQuery": badAdvanced
            ]
            let (_, isError) = try await client.callTool(name: "file-search", arguments: args)
            XCTAssertEqual(isError, true)
        }
    }
}
