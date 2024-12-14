# Everything Search MCP Server

An MCP server that provides fast file searching capabilities using the Everything SDK.

## Prerequisites

1. Windows operating system (required - this server only works on Windows)
2. [Everything](https://www.voidtools.com/) search utility:
   - Download and install from https://www.voidtools.com/
   - **Make sure the Everything service is running**
3. Everything SDK:
   - Download from https://www.voidtools.com/support/everything/sdk/
   - Extract the SDK files to a location on your system

## Installation

1. Make sure you have Python 3.10+ installed
2. Clone this repository `git clone https://github.com/mamertofabian/mcp-everything-search.git`
3. Install [`uv`](https://docs.astral.sh/uv/getting-started/installation/) if you haven't already
4. From the project root directory, run:
   ```bash
   uv pip install .
   ```

## Configuration

The server requires the Everything SDK DLL to be available:

Environment variable:
   ```
   EVERYTHING_SDK_PATH=path\to\Everything64.dll
   ```

### Usage with Claude Desktop

Add this to your `claude_desktop_config.json`:

```json
"mcpServers": {
  "everything-search": {
    "command": "uv",
    "args": ["--directory", "path/to/mcp-everything-search/src/mcp_server_everything_search", "run", "mcp-server-everything-search"],
    "env": {
      "EVERYTHING_SDK_PATH": "path/to/Everything64.dll"
    }
  }
}
```

## Tools

### search

Search for files and folders using Everything SDK.

Parameters:
- `query` (required): Search query string
- `max_results` (optional): Maximum number of results to return (default: 100, max: 1000)

Example:
```json
{
  "query": "*.py",
  "max_results": 50
}
```

Response includes:
- File/folder path
- File size in bytes
- Last modified date

## License

This MCP server is licensed under the MIT License. See the LICENSE file for details.
