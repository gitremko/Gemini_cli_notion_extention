# Changelog
## [0.1.1] - 2025-10-16

### Removed
- dotenv fallback and .env usage; project now uses OS environment variables only.
- Deleted .env.example.


All notable changes to this project will be documented in this file.

## [0.1.0] - 2025-10-16

### Added
- Initial public release of the Notion MCP server and Gemini CLI extension manifest.
- Core tools: `notion_search`, `notion_get_page`, `notion_list_blocks`, `notion_append_paragraph`, `notion_create_page`.
- Stdio and HTTP (streamable) transports.
- Example Gemini extension manifest (`gemini-extension.json`).
- TypeScript build setup with `tsc` and bundling via `esbuild`.

### Changed
- Repository cleanup to include only files required for a working plugin (removed local scripts and temp files).

### Notes

- Docs: Prefer OS environment variables over .env; .env remains supported for local dev. server.ts and http.ts now load dotenv automatically.

- Requires a Notion integration token exposed via `NOTION_API_KEY`.
- See README for setup and usage examples.


