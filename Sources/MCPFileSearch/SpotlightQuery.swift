import Foundation

enum SpotlightQuery {
    static func run(_ args: SearchArgs) async throws -> [SearchHit] {
        let query = NSMetadataQuery()
        let qtext = args.query.replacingOccurrences(of: "\"", with: "\\\"")
        
        // Build predicate
        let predicate: NSPredicate
        if args.filenameOnly ?? false {
            predicate = NSPredicate(format: "kMDItemFSName ==[cdw] \"*\(qtext)*\"")
        } else {
            predicate = NSPredicate(format:
                "kMDItemFSName ==[cdw] \"*\(qtext)*\" OR kMDItemTextContent ==[cdw] \"*\(qtext)*\"")
        }
        query.predicate = predicate
        
        // Scopes
        if let scopes = args.onlyIn, !scopes.isEmpty {
            query.searchScopes = scopes
        } else {
            query.searchScopes = [NSMetadataQueryIndexedLocalComputerScope]
        }
        
        query.sortDescriptors = [
            NSSortDescriptor(key: kMDItemFSName as String, ascending: true)
        ]
        
        return try await withCheckedThrowingContinuation { cont in
            var obs: NSObjectProtocol?
            obs = NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidFinishGathering,
                object: query,
                queue: nil
            ) { _ in
                query.disableUpdates()
                query.stop()
                if let obs = obs { NotificationCenter.default.removeObserver(obs) }
                
                let limit = args.limit ?? 200
                let hits: [SearchHit] = (0..<query.resultCount).prefix(limit).compactMap { idx in
                    guard let item = query.result(at: idx) as? NSMetadataItem else { return nil }
                    let path = item.value(forAttribute: kMDItemPath as String) as? String ?? ""
                    let name = item.value(forAttribute: kMDItemFSName as String) as? String ?? ""
                    let kind = item.value(forAttribute: kMDItemKind as String) as? String
                    let mod = item.value(forAttribute: kMDItemFSContentChangeDate as String) as? Date
                    return SearchHit(path: path, name: name, kind: kind, modified: mod)
                }
                
                cont.resume(returning: hits)
            }
            
            query.start()
        }
    }
}

