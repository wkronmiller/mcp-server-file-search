// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "mcp-file-search",
    platforms: [ .macOS(.v13) ],
    products: [ .executable(name: "mcp-file-search", targets: ["MCPFileSearch"]) ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.1.0")
    ],
    targets: [
        .executableTarget(
            name: "MCPFileSearch",
            dependencies: [ .product(name: "MCP", package: "swift-sdk") ],
            linkerSettings: [
                .linkedFramework("CoreServices"),
                .linkedFramework("Foundation")
            ]
        ),
        .testTarget(
            name: "MCPFileSearchTests",
            dependencies: [
                "MCPFileSearch",
                .product(name: "MCP", package: "swift-sdk")
            ]
        )
    ]
)
