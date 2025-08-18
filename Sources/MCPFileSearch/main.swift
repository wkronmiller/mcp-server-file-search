import Foundation
import MCP

@main
struct App {
    static func main() async throws {
        let server = Server(
            name: "mac-file-search",
            version: "0.1.0",
            capabilities: .init(
                tools: .init(listChanged: true)
            )
        )

        // Advertise tools
        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: [
                Tool(
                    name: "file.search",
                    description: "Spotlight-backed search of filenames or contents on macOS.",
                    inputSchema: .object([
                        "query": .string("Search text. If filenameOnly is true, matches name; otherwise full-text/metadata."),
                        "onlyIn": .array(.string("Limit search to these directories (absolute paths)")),
                        "filenameOnly": .boolean("If true, only search filenames (no contents/metadata)."),
                        "limit": .number("Max results to return (default 200).")
                    ])
                )
            ])
        }

        // Implement file.search
        await server.withMethodHandler(CallTool.self) { params in
            guard params.name == "file.search" else {
                return .init(content: [.text("Unknown tool")], isError: true)
            }

            do {
                // Decode args -> SearchArgs
                let argsData = try JSONSerialization.data(withJSONObject: params.arguments ?? [:])
                var args = try JSONDecoder().decode(SearchArgs.self, from: argsData)
                if args.limit == nil { args.limit = 200 }

                // Run Spotlight query (no mdfind)
                let hits = try await SpotlightQuery.run(args)

                // Encode JSON response
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let payload = try encoder.encode(hits)
                let json = String(data: payload, encoding: .utf8) ?? "[]"

                return .init(content: [.text(json, mimeType: "application/json")])
            } catch {
                return .init(content: [.text("Search failed: \(error.localizedDescription)")], isError: true)
            }
        }

        // Start stdio transport (MCP)
        try await server.start(transport: StdioTransport())
    }
}

