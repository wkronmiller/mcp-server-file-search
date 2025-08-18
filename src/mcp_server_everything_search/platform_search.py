"""Platform-specific search implementations with dedicated parameter models."""

from typing import Optional, List, Dict, Any, Union
from pydantic import BaseModel, Field
import platform


class BaseSearchQuery(BaseModel):
    """Base search parameters common to all platforms."""

    query: str = Field(
        description="Search query string. See platform-specific documentation for syntax details."
    )
    max_results: int = Field(
        default=100,
        ge=1,
        le=1000,
        description="Maximum number of results to return (1-1000)",
    )


class MacSpecificParams(BaseModel):
    """macOS-specific search parameters for mdfind."""

    live_updates: bool = Field(
        default=False, description="Provide live updates to search results"
    )
    search_directory: Optional[str] = Field(
        default=None,
        description="Limit search to specific directory (-onlyin parameter)",
    )
    literal_query: bool = Field(
        default=False,
        description="Treat query as literal string without interpretation",
    )
    interpret_query: bool = Field(
        default=False, description="Interpret query as if typed in Spotlight menu"
    )


class LinuxSpecificParams(BaseModel):
    """Linux-specific search parameters for locate."""

    ignore_case: bool = Field(
        default=True, description="Ignore case distinctions (-i parameter)"
    )
    regex_search: bool = Field(
        default=False, description="Use regular expressions in patterns (-r parameter)"
    )
    existing_files: bool = Field(
        default=True, description="Only output existing files (-e parameter)"
    )
    count_only: bool = Field(
        default=False, description="Only display count of matches (-c parameter)"
    )


class UnifiedSearchQuery(BaseSearchQuery):
    """Combined search parameters model."""

    mac_params: Optional[MacSpecificParams] = None
    linux_params: Optional[LinuxSpecificParams] = None
    # Windows parameters removed: this server no longer supports Windows/Everything

    @classmethod
    def get_schema_for_platform(cls) -> Dict[str, Any]:
        """Get the appropriate schema based on the current platform."""
        system = platform.system().lower()

        schema = {
            "type": "object",
            "properties": {"base": BaseSearchQuery.model_json_schema()},
            "required": ["base"],
        }

        # Add platform-specific parameters
        if system == "darwin":
            schema["properties"]["mac_params"] = MacSpecificParams.model_json_schema()
        elif system == "linux":
            schema["properties"]["linux_params"] = (
                LinuxSpecificParams.model_json_schema()
            )
        # Windows support removed

        return schema

    def get_platform_params(
        self,
    ) -> Optional[Union[MacSpecificParams, LinuxSpecificParams]]:
        """Get the parameters specific to the current platform."""
        system = platform.system().lower()
        if system == "darwin":
            return self.mac_params
        elif system == "linux":
            return self.linux_params
        # Windows support removed
        return None


def build_search_command(query: UnifiedSearchQuery) -> List[str]:
    """Build the appropriate search command based on platform and parameters."""
    system = platform.system().lower()
    platform_params = query.get_platform_params()

    if system == "darwin":
        cmd = ["mdfind"]
        if isinstance(platform_params, MacSpecificParams):
            if platform_params.live_updates:
                cmd.append("-live")
            if platform_params.search_directory:
                cmd.extend(["-onlyin", platform_params.search_directory])
            if platform_params.literal_query:
                cmd.append("-literal")
            if platform_params.interpret_query:
                cmd.append("-interpret")
        cmd.append(query.query)  # Use query directly from UnifiedSearchQuery
        return cmd

    elif system == "linux":
        cmd = ["locate"]
        if isinstance(platform_params, LinuxSpecificParams):
            if platform_params.ignore_case:
                cmd.append("-i")
            if platform_params.regex_search:
                cmd.append("-r")
            if platform_params.existing_files:
                cmd.append("-e")
            if platform_params.count_only:
                cmd.append("-c")
        cmd.append(query.query)  # Use query directly from UnifiedSearchQuery
        return cmd

    # Windows support removed
    raise NotImplementedError(f"Unsupported platform: {system}")
