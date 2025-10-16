# Gemini_cli_notion_extention

Extension for Notion in Gemini CLI via MCP.

## Notion MCP Server

Expose Notion pages and basic actions to MCP-capable clients (e.g., Gemini CLI if it supports MCP, Claude Code, VS Code Copilot MCP, Cursor).

## Setup

- Requirements
  - Node.js 18+
  - A Notion integration with an internal integration token
  - Share the relevant pages/databases with your integration in Notion

- Install
  - Prefer setting your Notion key as an environment variable:
    - Windows (PowerShell, user scope): `[Environment]::SetEnvironmentVariable('NOTION_API_KEY','secret_...','User')`
    - Windows (CMD, user scope): `setx NOTION_API_KEY "secret_..."`
    - macOS/Linux (current shell): `export NOTION_API_KEY=secret_...`
    - macOS/Linux (persist): add `export NOTION_API_KEY=secret_...` to `~/.zshrc` or `~/.bashrc`
    - Alternate names also supported: `GEMINI_NOTION_API_KEY`, `NOTION_TOKEN`, `NOTION_SECRET`
  - Optional (local dev): you may still use a `.env` file by copying `.env.example` to `.env`.
  - Run `npm install`.
  - For development: `npm run dev` (runs via tsx on stdio)
  - Build + run: `npm run build` then `npm start`.

## Tools

- `notion_search`
  - Args: `query` (string, required), `filter` ({ property: 'object', value: 'page'|'database' } optional), `page_size` (1-100)
  - Returns id, object type, title (if resolvable), url

- `notion_get_page`
  - Args: `page_id` (string)
  - Returns the full Notion page object (properties/meta)

- `notion_list_blocks`
  - Args: `block_id` (string), `page_size` (optional)
  - Returns child blocks for a page/block

- `notion_append_paragraph`
  - Args: `parent_block_id` (string), `text` (string)
  - Appends a simple paragraph block under the page/block

- `notion_create_page`
  - Args: `database_id` (string), `title` (string), `title_property` (default "Name"), `properties` (object, optional)
  - Creates a new page in a database

## Running with MCP Clients

- Stdio transport (generic MCP clients)
  - Command: `notion-mcp` (after `npm i -g` or `npm run build && node dist/cli.js`)
  - Env: `NOTION_API_KEY=...`
  - Example client config (pseudo):
    - name: `notion`
    - type: `stdio`
    - command: `notion-mcp`
    - env: `{ "NOTION_API_KEY": "your_secret" }`

- Streamable HTTP
  - Command: `MCP_TRANSPORT=http PORT=3030 notion-mcp`
  - Endpoint: `http://localhost:3030/mcp`
  - Some clients (Claude Code, VS Code, Cursor) support HTTP MCP.

## Gemini CLI Extension

- Install globally so others can run the same command:
  - `npm i -g` in this folder (or publish to npm and `npm i -g notion-mcp-server`)
- Configure Gemini CLI to run the extension binary:
  - command: `notion-mcp`
  - transport: `stdio` (default) or use HTTP with `MCP_TRANSPORT=http` and `PORT`
  - env: `{ "NOTION_API_KEY": "..." }`
  - If Gemini CLI supports an extensions manifest, point an entry to the above command/env. Exact keys depend on Gemini CLI; see their extensions docs.

## Gemini CLI Integration

- If your Gemini CLI supports MCP servers via stdio, add a server entry pointing to this command and pass `NOTION_API_KEY` in env.
- If it uses an `mcpServers` config (JSON), the entry typically looks like:
  {
    "mcpServers": {
      "notion": {
        "command": "node",
        "args": ["dist/server.js"],
        "env": { "NOTION_API_KEY": "..." },
        "transport": "stdio"
      }
    }
  }
- Concrete paths and config keys can differ per client; consult your Gemini CLI docs for where to place this block.

## Notes

- Ensure your Notion integration has access to the pages/databases you want to use (share them in Notion).
- Title property name can vary across databases; default is `Name`, override with `title_property` when needed.
- For testing and inspection, you can also use the MCP Inspector: `npx @modelcontextprotocol/inspector` and connect to the running server (stdio or HTTP as configured).

## User variables / secrets

- Preferred: set `NOTION_API_KEY` as an environment variable so secrets do not live in files.
- Also supported env var names: `GEMINI_NOTION_API_KEY`, `NOTION_TOKEN`, `NOTION_SECRET`.
- Windows (user-scoped):
  - PowerShell: `[Environment]::SetEnvironmentVariable('NOTION_API_KEY','secret_...','User')`
  - CMD: `setx NOTION_API_KEY "secret_..."`
  - Open a new terminal to pick up changes.
- macOS/Linux:
  - Current shell: `export NOTION_API_KEY=secret_...`
  - Persist: add to `~/.zshrc` or `~/.bashrc`.
- Optional fallback: for local development you can use a `.env` file (values are read into the process the same way).

## Getting Started

- Clone the repo:
  - `git clone https://github.com/gitremko/Gemini_cli_notion_extention`
  - `cd Gemini_cli_notion_extention`
- Configure secrets (preferred): set `NOTION_API_KEY` as an environment variable for your OS (see above). Optionally, use `.env` for local dev.
- Install and build:
  - `npm install`
  - `npm run build`
- Run as MCP (stdio):
  - `node dist/server.js`
- Or run the bundled CLI:
  - `node dist/cli.js`
- Configure your MCP-capable client (e.g., Gemini CLI, Claude Code) to use:
  - command: `notion-mcp` (after `npm i -g` in this folder) or `node dist/cli.js`
  - env: `{ "NOTION_API_KEY": "..." }`

See the full tool list and examples below. For changes, check CHANGELOG.md.


## License

MIT License — see LICENSE.
