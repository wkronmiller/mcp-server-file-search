# Advanced Query System

The MCP File Search server now supports complex filter combinations using AND/OR logic to perform sophisticated file searches. This allows you to combine multiple criteria such as content search, file extensions, dates, sizes, and paths.

## Key Concepts

### Filter Types
Individual filter criteria that can be combined:

- **`content`**: Search within file contents
- **`filename`**: Search by filename patterns  
- **`extensions`**: Filter by file extensions (supports multiple with OR logic)
- **`dateModified`**: Filter by modification date range
- **`dateCreated`**: Filter by creation date range
- **`size`**: Filter by file size range
- **`paths`**: Limit search to specific directories

### Filter Groups
Filters are organized into groups with combination logic:
- **Within a group**: Filters use AND logic by default, or OR if specified
- **Between groups**: Multiple groups are combined with OR logic

## Examples

### Basic AND Query
Find documents containing "foo" AND having pdf or docx extensions:

```json
{
  "advancedQuery": {
    "filterGroups": [
      {
        "filters": [
          {"content": {"query": "foo"}},
          {"extensions": ["pdf", "docx"]}
        ],
        "combination": "and"
      }
    ]
  }
}
```

### OR Query Within Group
Find files containing "error" OR "exception" in content:

```json
{
  "advancedQuery": {
    "filterGroups": [
      {
        "filters": [
          {"content": {"query": "error"}},
          {"content": {"query": "exception"}}
        ],
        "combination": "or"
      }
    ]
  }
}
```

### Complex Multi-Group Query
Find either:
1. Swift files containing "protocol", OR
2. Python files modified in the last week

```json
{
  "advancedQuery": {
    "filterGroups": [
      {
        "filters": [
          {"content": {"query": "protocol"}},
          {"extensions": ["swift"]}
        ]
      },
      {
        "filters": [
          {"extensions": ["py"]},
          {"dateModified": {"from": "2024-08-20T00:00:00Z"}}
        ]
      }
    ]
  }
}
```

### Size and Path Filtering
Find large files (>1MB) in specific directories:

```json
{
  "advancedQuery": {
    "filterGroups": [
      {
        "filters": [
          {"size": {"minSize": 1048576}},
          {"paths": ["/Users/john/Documents", "/Users/john/Desktop"]}
        ]
      }
    ]
  }
}
```

### Date Range Filtering
Find files modified in 2024:

```json
{
  "advancedQuery": {
    "filterGroups": [
      {
        "filters": [
          {"dateModified": {
            "from": "2024-01-01T00:00:00Z",
            "to": "2024-12-31T23:59:59Z"
          }}
        ]
      }
    ]
  }
}
```

## Filter Reference

### Content Filter
```json
{"content": {"query": "search text"}}
```
Searches within file contents. Supports wildcards (*).

### Filename Filter
```json
{"filename": {"query": "pattern"}}
```
Searches by filename. Supports wildcards (*).

### Extensions Filter
```json
{"extensions": ["ext1", "ext2", "ext3"]}
```
Filters by file extensions. Multiple extensions use OR logic.

### Date Filters
```json
{"dateModified": {"from": "ISO-date", "to": "ISO-date"}}
{"dateCreated": {"from": "ISO-date", "to": "ISO-date"}}
```
Filter by modification or creation date ranges. Dates in ISO 8601 format.

### Size Filter
```json
{"size": {"minSize": 1024, "maxSize": 1048576}}
```
Filter by file size in bytes. Both minSize and maxSize are optional.

### Paths Filter
```json
{"paths": ["/absolute/path1", "/absolute/path2"]}
```
Limit search to specific directories. Must be absolute paths.

## Complete Example

MCP tool call to find documents containing "Swift" AND having swift extensions:

```bash
echo '{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "file-search",
    "arguments": {
      "advancedQuery": {
        "filterGroups": [
          {
            "filters": [
              {"content": {"query": "Swift"}},
              {"extensions": ["swift"]}
            ]
          }
        ]
      },
      "limit": 10
    }
  }
}' | ./mcp-file-search
```

This will find up to 10 Swift source files that contain the word "Swift" in their content.

## Backward Compatibility

The legacy query parameters (`query`, `queryType`, `extensions`, `onlyIn`, `dateFilter`) are still supported for simple searches. They will be automatically converted to the appropriate advanced query structure internally.

For new applications, it's recommended to use the `advancedQuery` parameter for more flexible and powerful searches.