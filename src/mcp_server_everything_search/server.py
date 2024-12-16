"""MCP server implementation for Everything Search."""

import ctypes
import os
import sys
from enum import IntEnum
from typing import Literal

from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import TextContent, Tool, Resource, ResourceTemplate, Prompt
from pydantic import BaseModel, Field

from .everything_sdk import (
    EverythingSDK,
    EVERYTHING_SORT_NAME_ASCENDING,
    EVERYTHING_SORT_NAME_DESCENDING,
    EVERYTHING_SORT_PATH_ASCENDING,
    EVERYTHING_SORT_PATH_DESCENDING,
    EVERYTHING_SORT_SIZE_ASCENDING,
    EVERYTHING_SORT_SIZE_DESCENDING,
    EVERYTHING_SORT_EXTENSION_ASCENDING,
    EVERYTHING_SORT_EXTENSION_DESCENDING,
    EVERYTHING_SORT_DATE_CREATED_ASCENDING,
    EVERYTHING_SORT_DATE_CREATED_DESCENDING,
    EVERYTHING_SORT_DATE_MODIFIED_ASCENDING,
    EVERYTHING_SORT_DATE_MODIFIED_DESCENDING,
)

class SortOption(IntEnum):
    """Sort options for search results.
    
    Available options:
    - NAME_ASC (1): Sort by filename in ascending order
    - NAME_DESC (2): Sort by filename in descending order
    - PATH_ASC (3): Sort by full path in ascending order
    - PATH_DESC (4): Sort by full path in descending order
    - SIZE_ASC (5): Sort by file size in ascending order (smallest first)
    - SIZE_DESC (6): Sort by file size in descending order (largest first)
    - EXT_ASC (7): Sort by file extension in ascending order
    - EXT_DESC (8): Sort by file extension in descending order
    - CREATED_ASC (11): Sort by creation date in ascending order (oldest first)
    - CREATED_DESC (12): Sort by creation date in descending order (newest first)
    - MODIFIED_ASC (13): Sort by modification date in ascending order (oldest first)
    - MODIFIED_DESC (14): Sort by modification date in descending order (newest first)
    """
    NAME_ASC = EVERYTHING_SORT_NAME_ASCENDING
    NAME_DESC = EVERYTHING_SORT_NAME_DESCENDING
    PATH_ASC = EVERYTHING_SORT_PATH_ASCENDING
    PATH_DESC = EVERYTHING_SORT_PATH_DESCENDING
    SIZE_ASC = EVERYTHING_SORT_SIZE_ASCENDING
    SIZE_DESC = EVERYTHING_SORT_SIZE_DESCENDING
    EXT_ASC = EVERYTHING_SORT_EXTENSION_ASCENDING
    EXT_DESC = EVERYTHING_SORT_EXTENSION_DESCENDING
    CREATED_ASC = EVERYTHING_SORT_DATE_CREATED_ASCENDING
    CREATED_DESC = EVERYTHING_SORT_DATE_CREATED_DESCENDING
    MODIFIED_ASC = EVERYTHING_SORT_DATE_MODIFIED_ASCENDING
    MODIFIED_DESC = EVERYTHING_SORT_DATE_MODIFIED_DESCENDING

class SearchQuery(BaseModel):
    """Model for search query parameters."""
    query: str = Field(
        description="Search query string. Supports wildcards (* and ?) and boolean operators (AND, OR, NOT)"
    )
    max_results: int = Field(
        default=100,
        ge=1,
        le=1000,
        description="Maximum number of results to return (1-1000)"
    )
    match_path: bool = Field(
        default=False,
        description="Match against full path instead of filename only"
    )
    match_case: bool = Field(
        default=False,
        description="Enable case-sensitive search"
    )
    match_whole_word: bool = Field(
        default=False,
        description="Match whole words only"
    )
    match_regex: bool = Field(
        default=False,
        description="Enable regex search"
    )
    sort_by: SortOption = Field(
        default=SortOption.NAME_ASC,
        description="""Sort order for results. Available options:
        - 1 (NAME_ASC): Sort by filename (A to Z)
        - 2 (NAME_DESC): Sort by filename (Z to A)
        - 3 (PATH_ASC): Sort by path (A to Z)
        - 4 (PATH_DESC): Sort by path (Z to A)
        - 5 (SIZE_ASC): Sort by size (smallest first)
        - 6 (SIZE_DESC): Sort by size (largest first)
        - 7 (EXT_ASC): Sort by extension (A to Z)
        - 8 (EXT_DESC): Sort by extension (Z to A)
        - 11 (CREATED_ASC): Sort by creation date (oldest first)
        - 12 (CREATED_DESC): Sort by creation date (newest first)
        - 13 (MODIFIED_ASC): Sort by modification date (oldest first)
        - 14 (MODIFIED_DESC): Sort by modification date (newest first)"""
    )

    class Config:
        """Pydantic model configuration."""
        use_enum_values = True  # Use enum values in schema

async def serve() -> None:
    """Run the server."""
    # Load Everything SDK DLL
    dll_path = os.getenv('EVERYTHING_SDK_PATH', 'D:\\dev\\tools\\Everything-SDK\\dll\\Everything64.dll')
    everything_sdk = EverythingSDK(dll_path)

    server = Server("everything-search")

    @server.list_tools()
    async def list_tools() -> list[Tool]:
        return [
            Tool(
                name="search",
                description="""Search for files and folders using Everything SDK.
                
                Features:
                - Fast file and folder search across all indexed drives
                - Support for wildcards and boolean operators
                - Multiple sort options (name, path, size, dates)
                - Case-sensitive and whole word matching
                - Regular expression support
                - Path matching
                """,
                inputSchema=SearchQuery.model_json_schema(),
            ),
        ]

    @server.list_resources()
    async def list_resources() -> list[Resource]:
        """Return an empty list since this server doesn't provide any resources."""
        return []

    @server.list_resource_templates()
    async def list_resource_templates() -> list[ResourceTemplate]:
        """Return an empty list since this server doesn't provide any resource templates."""
        return []

    @server.list_prompts()
    async def list_prompts() -> list[Prompt]:
        """Return an empty list since this server doesn't provide any prompts."""
        return []

    @server.call_tool()
    async def call_tool(name: str, arguments: dict) -> list[TextContent]:
        if name != "search":
            raise ValueError(f"Unknown tool: {name}")

        try:
            query = SearchQuery(**arguments)
            # Add debug logging
            print(f"Debug: Executing search with query: {query.query}", file=sys.stderr)
            print(f"Debug: Sort by: {query.sort_by}", file=sys.stderr)
            
            results = everything_sdk.search_files(
                query=query.query,
                max_results=query.max_results,
                match_path=query.match_path,
                match_case=query.match_case,
                match_whole_word=query.match_whole_word,
                match_regex=query.match_regex,
                sort_by=query.sort_by
            )
            
            return [TextContent(
                type="text",
                text="\n".join([
                    f"Path: {r.path}\n"
                    f"Filename: {r.filename}"
                    f"{f' ({r.extension})' if r.extension else ''}\n"
                    f"Size: {r.size:,} bytes\n"
                    f"Created: {r.created if r.created else 'N/A'}\n"
                    f"Modified: {r.modified if r.modified else 'N/A'}\n"
                    f"Accessed: {r.accessed if r.accessed else 'N/A'}\n"
                    f"Run Count: {r.run_count if r.run_count else 'N/A'}\n"
                    f"Attributes: {r.attributes if r.attributes else 'N/A'}\n"
                    for r in results
                ])
            )]
        except Exception as e:
            # Add more detailed error logging
            import traceback
            print(f"Debug: Error details:\n{traceback.format_exc()}", file=sys.stderr)
            return [TextContent(
                type="text",
                text=f"Search failed: {str(e)}"
            )]

    options = server.create_initialization_options()
    async with stdio_server() as (read_stream, write_stream):
        await server.run(read_stream, write_stream, options, raise_exceptions=True)

def configure_windows_console():
    """Configure Windows console for UTF-8 output."""
    if sys.platform == "win32":
        # Enable virtual terminal processing
        kernel32 = ctypes.windll.kernel32
        STD_OUTPUT_HANDLE = -11
        ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004
        
        handle = kernel32.GetStdHandle(STD_OUTPUT_HANDLE)
        mode = ctypes.c_ulong()
        kernel32.GetConsoleMode(handle, ctypes.byref(mode))
        mode.value |= ENABLE_VIRTUAL_TERMINAL_PROCESSING
        kernel32.SetConsoleMode(handle, mode)
        
        # Set UTF-8 encoding for console output
        sys.stdout.reconfigure(encoding='utf-8')
        sys.stderr.reconfigure(encoding='utf-8')

def main():
    """Main entry point."""
    import asyncio
    
    # Configure console before running the server
    configure_windows_console()
    
    asyncio.run(serve())
