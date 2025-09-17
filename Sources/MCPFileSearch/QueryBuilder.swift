import Foundation
#if os(macOS)
import CoreServices
#endif

/// Builds NSPredicate objects from SearchFilter and AdvancedQuery structures
public struct QueryBuilder {
    
    /// Builds an NSPredicate from SearchArgs, supporting both legacy and advanced queries
    /// - Parameter args: Search configuration
    /// - Returns: NSPredicate for use with NSMetadataQuery
    public static func buildPredicate(for args: SearchArgs) -> NSPredicate {
        #if !os(macOS)
        Logger.warning("QueryBuilder: macOS-specific predicates not available on this platform")
        return NSPredicate(value: false) // Return a predicate that matches nothing
        #else
        // If advanced query is provided, use it; otherwise fall back to legacy
        if let advancedQuery = args.advancedQuery {
            return buildAdvancedPredicate(from: advancedQuery)
        } else {
            return buildLegacyPredicate(from: args)
        }
        #endif
    }
    
    /// Extracts search scopes from AdvancedQuery or legacy parameters
    /// - Parameter args: Search configuration
    /// - Returns: Array of search scopes for NSMetadataQuery
    public static func extractSearchScopes(from args: SearchArgs) -> [String] {
        #if !os(macOS)
        Logger.warning("QueryBuilder: macOS-specific search scopes not available on this platform")
        return [] // Return empty scopes for non-macOS platforms
        #else
        return extractSearchScopesImpl(from: args)
        #endif
    }
    
    #if os(macOS)
    /// Internal implementation of extractSearchScopes for macOS
    private static func extractSearchScopesImpl(from args: SearchArgs) -> [String] {
        // Check advanced query first
        if let advancedQuery = args.advancedQuery {
            let pathFilters = advancedQuery.filterGroups.flatMap { group in
                group.filters.compactMap { filter in
                    switch filter {
                    case .paths(let paths):
                        return paths
                    default:
                        return nil
                    }
                }
            }.flatMap { $0 }
            
            if !pathFilters.isEmpty {
                Logger.debug("Using path scopes from advanced query: \(pathFilters.joined(separator: ", "))")
                return pathFilters
            }
        }
        
        // Fall back to legacy onlyIn parameter
        if let onlyIn = args.onlyIn, !onlyIn.isEmpty {
            Logger.debug("Using legacy onlyIn scopes: \(onlyIn.joined(separator: ", "))")
            return onlyIn
        }
        
        // Default to local computer scope
        return [NSMetadataQueryLocalComputerScope]
    }
    /// - Parameter advancedQuery: Advanced query with filter groups
    /// - Returns: NSPredicate combining all filter groups with OR logic
    private static func buildAdvancedPredicate(from advancedQuery: AdvancedQuery) -> NSPredicate {
        guard !advancedQuery.filterGroups.isEmpty else {
            Logger.debug("Empty advanced query, returning match-all predicate")
            return NSPredicate(value: true)
        }
        
        if advancedQuery.filterGroups.count == 1 {
            return buildGroupPredicate(from: advancedQuery.filterGroups[0])
        } else {
            let groupPredicates = advancedQuery.filterGroups.map { buildGroupPredicate(from: $0) }
            Logger.debug("Created OR predicate with \(groupPredicates.count) filter groups")
            return NSCompoundPredicate(orPredicateWithSubpredicates: groupPredicates)
        }
    }
    
    /// Builds predicate from a single FilterGroup
    /// - Parameter group: Filter group with combination logic
    /// - Returns: NSPredicate for the group
    private static func buildGroupPredicate(from group: FilterGroup) -> NSPredicate {
        guard !group.filters.isEmpty else {
            return NSPredicate(value: true)
        }
        
        let filterPredicates = group.filters.compactMap { buildFilterPredicate(from: $0) }
        
        if filterPredicates.isEmpty {
            return NSPredicate(value: true)
        } else if filterPredicates.count == 1 {
            return filterPredicates[0]
        } else {
            let combination = group.combination ?? .and
            switch combination {
            case .and:
                Logger.debug("Created AND predicate with \(filterPredicates.count) filters")
                return NSCompoundPredicate(andPredicateWithSubpredicates: filterPredicates)
            case .or:
                Logger.debug("Created OR predicate with \(filterPredicates.count) filters")
                return NSCompoundPredicate(orPredicateWithSubpredicates: filterPredicates)
            }
        }
    }
    
    /// Builds predicate from a single SearchFilter
    /// - Parameter filter: Individual filter criterion
    /// - Returns: NSPredicate for the filter, or nil if invalid
    private static func buildFilterPredicate(from filter: SearchFilter) -> NSPredicate? {
        switch filter {
        case .content(let query):
            guard !query.isEmpty else { return nil }
            let pattern = "*\(query)*"
            Logger.debug("Building content filter for: '\(query)'")
            return NSPredicate(format: "%K LIKE[c] %@",
                             kMDItemTextContent as NSString,
                             pattern as NSString)
            
        case .filename(let query):
            guard !query.isEmpty else { return nil }
            let pattern = "*\(query)*"
            Logger.debug("Building filename filter for: '\(query)'")
            return NSPredicate(format: "%K LIKE[c] %@",
                             kMDItemFSName as NSString,
                             pattern as NSString)
            
        case .extensions(let extensions):
            guard !extensions.isEmpty else { return nil }
            let extensionPredicates = extensions.map { ext in
                NSPredicate(format: "%K LIKE[c] %@",
                          kMDItemFSName as NSString,
                          "*.\(ext)" as NSString)
            }
            Logger.debug("Building extensions filter for: \(extensions.joined(separator: ", "))")
            if extensionPredicates.count == 1 {
                return extensionPredicates[0]
            } else {
                return NSCompoundPredicate(orPredicateWithSubpredicates: extensionPredicates)
            }
            
        case .dateModified(let dateFilter):
            return buildDatePredicate(dateFilter: dateFilter, attribute: kMDItemFSContentChangeDate)
            
        case .dateCreated(let dateFilter):
            return buildDatePredicate(dateFilter: dateFilter, attribute: kMDItemFSCreationDate)
            
        case .size(let sizeFilter):
            return buildSizePredicate(sizeFilter: sizeFilter)
            
        case .paths(let paths):
            guard !paths.isEmpty else { return nil }
            Logger.debug("Building paths filter for: \(paths.joined(separator: ", "))")
            // Note: This is handled differently in NSMetadataQuery via searchScopes
            // Return nil here since it's handled by the caller
            return nil
        }
    }
    
    /// Builds date-based predicate
    /// - Parameters:
    ///   - dateFilter: Date filter with from/to range
    ///   - attribute: Metadata attribute key for the date
    /// - Returns: NSPredicate for date filtering
    private static func buildDatePredicate(dateFilter: DateFilter, attribute: CFString) -> NSPredicate? {
        var predicates: [NSPredicate] = []
        
        if let from = dateFilter.from {
            predicates.append(NSPredicate(format: "%K >= %@",
                                        attribute as NSString,
                                        from as NSDate))
            Logger.debug("Added date filter: from \(from)")
        }
        
        if let to = dateFilter.to {
            predicates.append(NSPredicate(format: "%K <= %@",
                                        attribute as NSString,
                                        to as NSDate))
            Logger.debug("Added date filter: to \(to)")
        }
        
        if predicates.isEmpty {
            return nil
        } else if predicates.count == 1 {
            return predicates[0]
        } else {
            return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
    }
    
    /// Builds size-based predicate
    /// - Parameter sizeFilter: Size filter with min/max range
    /// - Returns: NSPredicate for size filtering
    private static func buildSizePredicate(sizeFilter: SizeFilter) -> NSPredicate? {
        var predicates: [NSPredicate] = []
        
        if let minSize = sizeFilter.minSize {
            predicates.append(NSPredicate(format: "%K >= %@",
                                        kMDItemFSSize as NSString,
                                        NSNumber(value: minSize)))
            Logger.debug("Added size filter: min \(minSize) bytes")
        }
        
        if let maxSize = sizeFilter.maxSize {
            predicates.append(NSPredicate(format: "%K <= %@",
                                        kMDItemFSSize as NSString,
                                        NSNumber(value: maxSize)))
            Logger.debug("Added size filter: max \(maxSize) bytes")
        }
        
        if predicates.isEmpty {
            return nil
        } else if predicates.count == 1 {
            return predicates[0]
        } else {
            return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
    }
    
    /// Legacy predicate builder for backward compatibility
    /// - Parameter args: Search configuration using legacy parameters
    /// - Returns: NSPredicate built from legacy query structure
    private static func buildLegacyPredicate(from args: SearchArgs) -> NSPredicate {
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
    #endif
}