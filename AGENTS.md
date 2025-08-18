# Repository Guidelines

Repository: https://github.com/wkronmiller/mcp-server-file-search (active fork)

## Project Structure & Module Organization
- Source: `src/mcp_server_everything_search/` (entry: `__main__.py`, server: `server.py`, platform adapters: `search_interface.py`, `platform_search.py`, Windows SDK: `everything_sdk.py`).
- Package name: `mcp_server_everything_search`; script entry point: `mcp-server-everything-search`.
- Docs: `README.md`, `SEARCH_SYNTAX.md`.
- Build config: `pyproject.toml`; lockfile: `uv.lock`.

## Build, Test, and Development Commands
- Run (uv): `uvx mcp-server-everything-search`
- Run (Python): `python -m mcp_server_everything_search`
- Lint: `uv run ruff check .`
- Format: `uv run ruff format .`
- Type check: `uv run pyright`
- Tests: `uv run pytest -q`

## Coding Style & Naming Conventions
- Language: Python 3.10+ (see `.python-version`).
- Indentation: 4 spaces; UTF-8 files; Unix newlines.
- Naming: modules/files `snake_case.py`; classes `PascalCase`; functions/vars `snake_case`.
- Imports: standard library, third‑party, then local; keep groups separated.
- Tools: `ruff` for lint/format, `pyright` for types. Keep public APIs typed.

## Testing Guidelines
- Framework: `pytest` (none committed yet; add under `tests/`).
- Naming: files `test_*.py`, tests `test_*` functions/classes.
- Keep tests platform‑aware; mock OS commands (`mdfind`, `locate`) when feasible.
- Run locally with `uv run pytest -q`; aim to cover platform helpers and argument parsing.

## Commit & Pull Request Guidelines
- Commits: concise, imperative subject (≤72 chars), include rationale in body when needed.
  - Example: `fix(mac): handle -onlyin with spaces`.
- PRs: clear description, linked issues, reproduction steps, and test plan.
  - Include screenshots or logs for CLI output when relevant.
  - Update `README.md`/`SEARCH_SYNTAX.md` if behavior or flags change.

## Security & Configuration Tips
- Windows: set `EVERYTHING_SDK_PATH` to the Everything SDK DLL before running.
- Linux: ensure `plocate`/`locate` database is initialized (`sudo updatedb`).
- macOS: relies on Spotlight (`mdfind`). No extra config.
- Avoid checking in secrets; prefer env vars in local dev only.
