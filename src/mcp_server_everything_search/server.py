"""MCP server implementation for Everything Search."""

import ctypes
import datetime
import os
import struct
from pathlib import Path
from typing import Any, Dict, List, Optional

from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import TextContent, Tool
from pydantic import BaseModel

# Everything SDK constants
EVERYTHING_REQUEST_FILE_NAME = 0x00000001
EVERYTHING_REQUEST_PATH = 0x00000002
EVERYTHING_REQUEST_FULL_PATH_AND_FILE_NAME = 0x00000004
EVERYTHING_REQUEST_SIZE = 0x00000010
EVERYTHING_REQUEST_DATE_MODIFIED = 0x00000040

# Windows time conversion constants
WINDOWS_TICKS = int(1/10**-7)
WINDOWS_EPOCH = datetime.datetime.strptime('1601-01-01 00:00:00', '%Y-%m-%d %H:%M:%S')
POSIX_EPOCH = datetime.datetime.strptime('1970-01-01 00:00:00', '%Y-%m-%d %H:%M:%S')
EPOCH_DIFF = (POSIX_EPOCH - WINDOWS_EPOCH).total_seconds()
WINDOWS_TICKS_TO_POSIX_EPOCH = EPOCH_DIFF * WINDOWS_TICKS

class SearchQuery(BaseModel):
    """Model for search query parameters."""
    query: str
    max_results: int = 100

class SearchResult(BaseModel):
    """Model for search results."""
    path: str
    size: int
    modified: str

def get_time(filetime: bytes) -> datetime.datetime:
    """Convert Windows filetime to Python datetime."""
    winticks = struct.unpack('<Q', filetime)[0]
    microsecs = (winticks - WINDOWS_TICKS_TO_POSIX_EPOCH) / WINDOWS_TICKS
    return datetime.datetime.fromtimestamp(microsecs)

def search_files(dll: Any, query: str, max_results: int = 100) -> List[SearchResult]:
    """Perform file search using Everything SDK."""
    # Set up search parameters
    dll.Everything_SetSearchW(query)
    dll.Everything_SetRequestFlags(
        EVERYTHING_REQUEST_FILE_NAME | 
        EVERYTHING_REQUEST_PATH | 
        EVERYTHING_REQUEST_SIZE | 
        EVERYTHING_REQUEST_DATE_MODIFIED
    )

    # Execute search
    dll.Everything_QueryW(True)
    
    # Get results
    num_results = min(dll.Everything_GetNumResults(), max_results)
    results = []

    filename_buffer = ctypes.create_unicode_buffer(260)
    date_modified = ctypes.c_ulonglong(1)
    file_size = ctypes.c_ulonglong(1)

    for i in range(num_results):
        dll.Everything_GetResultFullPathNameW(i, filename_buffer, 260)
        dll.Everything_GetResultDateModified(i, date_modified)
        dll.Everything_GetResultSize(i, file_size)

        results.append(SearchResult(
            path=ctypes.wstring_at(filename_buffer),
            size=file_size.value,
            modified=get_time(date_modified).isoformat()
        ))

    return results

async def serve() -> None:
    """Run the server."""
    # Load Everything SDK DLL
    dll_path = os.getenv('EVERYTHING_SDK_PATH', 'D:\\dev\\tools\\Everything-SDK\\dll\\Everything64.dll')
    everything_dll = ctypes.WinDLL(dll_path)

    # Configure DLL function signatures
    everything_dll.Everything_GetResultDateModified.argtypes = [
        ctypes.c_int, 
        ctypes.POINTER(ctypes.c_ulonglong)
    ]
    everything_dll.Everything_GetResultSize.argtypes = [
        ctypes.c_int, 
        ctypes.POINTER(ctypes.c_ulonglong)
    ]
    everything_dll.Everything_GetResultFileNameW.argtypes = [ctypes.c_int]
    everything_dll.Everything_GetResultFileNameW.restype = ctypes.c_wchar_p

    server = Server("everything-search")

    @server.list_tools()
    async def list_tools() -> list[Tool]:
        return [
            Tool(
                name="search",
                description="Search for files and folders using Everything SDK",
                inputSchema=SearchQuery.schema(),
            ),
        ]

    @server.call_tool()
    async def call_tool(name: str, arguments: dict) -> list[TextContent]:
        if name != "search":
            raise ValueError(f"Unknown tool: {name}")

        try:
            query = arguments["query"]
            
            try:
                max_results_raw = arguments.get("max_results", 100)
                max_results = min(int(max_results_raw), 1000)
            except ValueError:
                max_results = 100

            results = search_files(everything_dll, query, max_results)
            
            return [TextContent(
                type="text",
                text="\n".join([
                    f"Path: {r.path}\n"
                    f"Size: {r.size} bytes\n"
                    f"Modified: {r.modified}\n"
                    for r in results
                ])
            )]
        except Exception as e:
            return [TextContent(
                type="text",
                text=f"Search failed: {str(e)}"
            )]

    options = server.create_initialization_options()
    async with stdio_server() as (read_stream, write_stream):
        await server.run(read_stream, write_stream, options, raise_exceptions=True)

def main():
    """Main entry point."""
    import asyncio
    asyncio.run(serve())
