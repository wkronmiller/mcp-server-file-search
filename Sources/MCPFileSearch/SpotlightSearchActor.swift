@preconcurrency import Foundation
@preconcurrency import CoreServices

/// Errors that can occur during Spotlight search operations
enum SpotlightSearchError: Error {
    /// Another search is already in progress
    case searchInProgress
    /// Failed to start the NSMetadataQuery
    case failedToStart
    /// Search operation timed out
    case timeout
}

/// Actor-based wrapper for Spotlight search operations
/// Ensures thread-safe access to NSMetadataQuery and prevents concurrent searches
actor SpotlightSearchActor {
    /// Shared singleton instance
    static let shared = SpotlightSearchActor()
    
    /// Tracks whether a search is currently in progress
    private var isSearching = false
    
    /// Performs a Spotlight search with the given parameters
    /// - Parameter args: Search configuration and parameters
    /// - Returns: Array of search results
    /// - Throws: SpotlightSearchError if search cannot be started or times out
    func search(_ args: SearchArgs) async throws -> [SearchHit] {
        guard !isSearching else {
            Logger.warning("Search request rejected - another search is already in progress")
            throw SpotlightSearchError.searchInProgress
        }
        
        Logger.debug("Starting Spotlight search for query: '\(args.query)'")
        isSearching = true
        defer { 
            isSearching = false
            Logger.debug("Search completed, actor ready for next request")
        }
        
        let limit = args.limit ?? 200
        Logger.debug("Search limit set to: \(limit)")
        
        return try await MainActorSpotlightQuery.execute(args: args, limit: limit)
    }
}

/// Main actor class that executes NSMetadataQuery operations
/// Must run on main thread as required by NSMetadataQuery
@MainActor
private class MainActorSpotlightQuery {
    
    /// Executes a Spotlight search on the main thread
    /// - Parameters:
    ///   - args: Search configuration
    ///   - limit: Maximum number of results to return
    /// - Returns: Array of search results
    /// - Throws: SpotlightSearchError on failure
    static func execute(args: SearchArgs, limit: Int) async throws -> [SearchHit] {
        return try await withCheckedThrowingContinuation { continuation in
            let query = NSMetadataQuery()
            var hasResumed = false
            var observer: NSObjectProtocol?
            
            // Configure query
            query.predicate = Self.buildPredicate(for: args)
            query.searchScopes = args.onlyIn ?? [NSMetadataQueryLocalComputerScope]
            query.sortDescriptors = Self.buildSortDescriptors(for: args)
            
            Logger.debug("Query configured with predicate: \(query.predicate?.description ?? "none")")
            
            func cleanup() {
                if let obs = observer {
                    NotificationCenter.default.removeObserver(obs)
                    observer = nil
                }
                query.stop()
            }
            
            func resumeWith(results: [SearchHit]) {
                guard !hasResumed else { return }
                hasResumed = true
                cleanup()
                Logger.debug("Resuming continuation with \(results.count) results")
                continuation.resume(returning: results)
            }
            
            func resumeWithError(_ error: Error) {
                guard !hasResumed else { return }
                hasResumed = true
                cleanup()
                Logger.error("Resuming continuation with error: \(error)")
                continuation.resume(throwing: error)
            }
            
            // Set up completion observer (only using completion, not progress for simplicity)
            observer = NotificationCenter.default.addObserver(
                forName: .NSMetadataQueryDidFinishGathering,
                object: query,
                queue: .main
            ) { _ in
                Logger.debug("Query finished gathering, total results: \(query.resultCount)")
                let results = Self.extractResults(from: query, limit: limit)
                resumeWith(results: results)
            }
            
            // Start the query
            Logger.debug("Starting NSMetadataQuery")
            guard query.start() else {
                Logger.error("Failed to start NSMetadataQuery")
                resumeWithError(SpotlightSearchError.failedToStart)
                return
            }
            
            Logger.debug("Query started successfully")
            
            // Set up timeout (default 10 seconds, overridable via args.timeoutSeconds)
            let timeoutSeconds = args.timeoutSeconds ?? 10.0
            Task {
                let nanos = UInt64(max(0, timeoutSeconds) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanos)
                
                guard !hasResumed else { return }
                Logger.warning("Query timed out after \(timeoutSeconds) seconds, returning partial results")
                Logger.warning("Partial result count: \(query.resultCount)")
                
                let results = Self.extractResults(from: query, limit: limit)
                resumeWith(results: results)
            }
        }
    }
    
    /// Builds an NSPredicate based on search arguments
    /// - Parameter args: Search configuration
    /// - Returns: NSPredicate for use with NSMetadataQuery
    private static func buildPredicate(for args: SearchArgs) -> NSPredicate {
        var predicates: [NSPredicate] = []
        
        let queryType = args.queryType ?? .all
        let pattern = "*\(args.query)*"
        
        switch queryType {
        case .extension:
            if let extensions = args.extensions, !extensions.isEmpty {
                let extensionPredicates = extensions.map { ext in
                    NSPredicate(format: "%K LIKE[c] %@", 
                              kMDItemFSName as NSString, 
                              "*.\(ext)" as NSString)
                }
                if extensionPredicates.count == 1 {
                    predicates.append(extensionPredicates[0])
                } else {
                    predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: extensionPredicates))
                }
                Logger.debug("Using extension predicates for: \(extensions.joined(separator: ", "))")
            } else if !args.query.isEmpty {
                predicates.append(NSPredicate(format: "%K LIKE[c] %@",
                                            kMDItemFSName as NSString,
                                            "*.\(args.query)" as NSString))
                Logger.debug("Using single extension predicate for: \(args.query)")
            }
            
        case .contents:
            if !args.query.isEmpty {
                predicates.append(NSPredicate(format: "%K LIKE[c] %@",
                                            kMDItemTextContent as NSString,
                                            pattern as NSString))
                Logger.debug("Using content-only predicate")
            }
            
        case .filename:
            if !args.query.isEmpty {
                predicates.append(NSPredicate(format: "%K LIKE[c] %@",
                                            kMDItemFSName as NSString,
                                            pattern as NSString))
                Logger.debug("Using filename-only predicate")
            }
            
        case .all:
            if !args.query.isEmpty {
                let allPredicate = NSPredicate(
                    format: "%K LIKE[c] %@ OR %K LIKE[c] %@",
                    kMDItemFSName as NSString, pattern as NSString,
                    kMDItemTextContent as NSString, pattern as NSString
                )
                predicates.append(allPredicate)
                Logger.debug("Using filename + content predicate")
            }
        }
        
        if let dateFilter = args.dateFilter {
            if let from = dateFilter.from {
                predicates.append(NSPredicate(format: "%K >= %@",
                                            kMDItemFSContentChangeDate as NSString,
                                            from as NSDate))
                Logger.debug("Added date filter: from \(from)")
            }
            if let to = dateFilter.to {
                predicates.append(NSPredicate(format: "%K <= %@",
                                            kMDItemFSContentChangeDate as NSString,
                                            to as NSDate))
                Logger.debug("Added date filter: to \(to)")
            }
        }
        
        if predicates.isEmpty {
            Logger.debug("No predicates specified, returning match-all predicate")
            return NSPredicate(value: true)
        } else if predicates.count == 1 {
            return predicates[0]
        } else {
            let compound = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            Logger.debug("Created compound predicate with \(predicates.count) conditions")
            return compound
        }
    }
    
    /// Builds sort descriptors based on search arguments
    /// - Parameter args: Search configuration
    /// - Returns: Array of NSSortDescriptor for result ordering
    private static func buildSortDescriptors(for args: SearchArgs) -> [NSSortDescriptor] {
        let sortBy = args.sortBy ?? .name
        let ascending = args.sortOrder != .descending
        
        let key: String
        switch sortBy {
        case .name:
            key = kMDItemFSName as String
        case .dateModified:
            key = kMDItemFSContentChangeDate as String
        case .dateCreated:
            key = kMDItemFSCreationDate as String
        case .size:
            key = kMDItemFSSize as String
        }
        
        Logger.debug("Sort by: \(key), ascending: \(ascending)")
        return [NSSortDescriptor(key: key, ascending: ascending)]
    }
    
    /// Extracts search results from NSMetadataQuery
    /// - Parameters:
    ///   - query: The completed NSMetadataQuery
    ///   - limit: Maximum number of results to extract
    /// - Returns: Array of SearchHit objects with file metadata
    private static nonisolated func extractResults(from query: NSMetadataQuery, limit: Int) -> [SearchHit] {
        let resultCount = query.resultCount
        let actualLimit = min(resultCount, limit)
        Logger.debug("Extracting \(actualLimit) results from \(resultCount) total")
        
        return (0..<actualLimit).compactMap { idx in
            guard let item = query.result(at: idx) as? NSMetadataItem else {
                Logger.warning("Failed to cast result at index \(idx) to NSMetadataItem")
                return nil
            }
            
            let path = item.value(forAttribute: kMDItemPath as String) as? String ?? ""
            let name = item.value(forAttribute: kMDItemFSName as String) as? String ?? ""
            let kind = item.value(forAttribute: kMDItemKind as String) as? String
            let size = item.value(forAttribute: kMDItemFSSize as String) as? Int64
            let created = item.value(forAttribute: kMDItemFSCreationDate as String) as? Date
            let modified = item.value(forAttribute: kMDItemFSContentChangeDate as String) as? Date
            
            if path.isEmpty {
                Logger.warning("Empty path for result at index \(idx)")
            }
            
            return SearchHit(
                path: path,
                name: name,
                kind: kind,
                size: size,
                created: created,
                modified: modified
            )
        }
    }
}
