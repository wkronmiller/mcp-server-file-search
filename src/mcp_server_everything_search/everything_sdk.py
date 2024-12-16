"""Everything SDK wrapper class."""

import ctypes
import datetime
import struct
from typing import Any, List
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

class SearchResult(BaseModel):
    """Model for search results."""
    path: str
    size: int
    modified: str

class EverythingSDK:
    """Wrapper for Everything SDK functionality."""
    
    def __init__(self, dll_path: str):
        """Initialize Everything SDK with the specified DLL path."""
        self.dll = ctypes.WinDLL(dll_path)
        self._configure_dll()

    def _configure_dll(self):
        """Configure DLL function signatures."""
        self.dll.Everything_GetResultDateModified.argtypes = [
            ctypes.c_int, 
            ctypes.POINTER(ctypes.c_ulonglong)
        ]
        self.dll.Everything_GetResultSize.argtypes = [
            ctypes.c_int, 
            ctypes.POINTER(ctypes.c_ulonglong)
        ]
        self.dll.Everything_GetResultFileNameW.argtypes = [ctypes.c_int]
        self.dll.Everything_GetResultFileNameW.restype = ctypes.c_wchar_p

    def _get_time(self, filetime: bytes) -> datetime.datetime:
        """Convert Windows filetime to Python datetime."""
        winticks = struct.unpack('<Q', filetime)[0]
        microsecs = (winticks - WINDOWS_TICKS_TO_POSIX_EPOCH) / WINDOWS_TICKS
        return datetime.datetime.fromtimestamp(microsecs)

    def search_files(self, query: str, max_results: int = 100) -> List[SearchResult]:
        """Perform file search using Everything SDK."""
        # Set up search parameters
        self.dll.Everything_SetSearchW(query)
        self.dll.Everything_SetRequestFlags(
            EVERYTHING_REQUEST_FILE_NAME | 
            EVERYTHING_REQUEST_PATH | 
            EVERYTHING_REQUEST_SIZE | 
            EVERYTHING_REQUEST_DATE_MODIFIED
        )

        # Execute search
        self.dll.Everything_QueryW(True)
        
        # Get results
        num_results = min(self.dll.Everything_GetNumResults(), max_results)
        results = []

        filename_buffer = ctypes.create_unicode_buffer(260)
        date_modified = ctypes.c_ulonglong(1)
        file_size = ctypes.c_ulonglong(1)

        for i in range(num_results):
            self.dll.Everything_GetResultFullPathNameW(i, filename_buffer, 260)
            self.dll.Everything_GetResultDateModified(i, date_modified)
            self.dll.Everything_GetResultSize(i, file_size)

            results.append(SearchResult(
                path=ctypes.wstring_at(filename_buffer),
                size=file_size.value,
                modified=self._get_time(date_modified).isoformat()
            ))

        return results 