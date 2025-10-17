# Notion MCP for Gemini CLI

A lightweight Model Context Protocol (MCP) server that lets Gemini CLI (and other MCP clients) search, read, and write Notion content.

## Requirements
- Gemini CLI installed and working
- Node.js 20+ and npm
- A Notion Internal Integration (API key)

## Quick Install (recommended)
- Install from GitHub:
  - `gemini extensions install https://github.com/gitremko/Gemini_cli_notion_extention`
- Create a Notion Internal Integration and grant access (see below)
- Set your API key (see “Set API Key”)
- Restart Gemini CLI, then run: `gemini extensions list` ? should show `notion`

## Create the Notion Integration (required)
1) Go to https://www.notion.so/profile/integrations
2) Click “New integration”
   - Workspace: choose the workspace you’ll use
   - Type: `Internal`
   - Capabilities: enable at least “Read content”, “Update content”, “Insert content”
   - Save
3) Grant access to pages/databases
   - On the integration page, open the “Access” tab and add the pages/databases you want to use
   - Or share specific Notion pages/databases with your integration from Notion
4) Copy the “Internal Integration Secret” — this is your API key

## Set API Key
- Windows (User-scoped, required on Windows)
  - PowerShell: `[Environment]::SetEnvironmentVariable('NOTION_API_KEY','secret_...','User')`
  - Open a new terminal after setting it
- macOS/Linux
  - Current shell: `export NOTION_API_KEY=secret_...`
  - Persist: add the export line to `~/.zshrc` or `~/.bashrc`

Notes
- Windows: this server reads the token only from the User-scoped environment (registry `HKCU\Environment`).
- Non-Windows: the token is read from the process environment.
- Supported names (first match wins): `NOTION_API_KEY`, `GEMINI_NOTION_API_KEY`, `NOTION_TOKEN`, `NOTION_SECRET`.

## Verify the Install
- Bundled server (no node_modules required):
  - Windows: `node "%USERPROFILE%\.gemini\extensions\notion\dist\extension.cjs"`
  - macOS/Linux: `node "$HOME/.gemini/extensions/notion/dist/extension.cjs"`
- Expected log: `Using Notion API key from: ...` and the process waits for a client connection

## Use in Gemini CLI
- After install, Gemini CLI discovers the MCP server `notion` automatically
- Try a simple tool call (e.g., search):
  - Ask Gemini to “search Notion for ‘<your term>’” — the tool used is `notion_search`

## Local Development (link)
- `git clone https://github.com/gitremko/Gemini_cli_notion_extention && cd Gemini_cli_notion_extention`
- `npm install && npm run build`
- `gemini extensions link .`
- Edit code ? `npm run build` ? restart Gemini CLI
- Unlink later: `gemini extensions unlink notion`

## Available Tools (high-level)
- `notion_search` — search pages/databases (query, optional filter, page_size)
- `notion_get_page` — fetch a page object by id
- `notion_list_blocks` — list child blocks for a page/block
- `notion_append_paragraph` — append paragraph text
- `notion_create_page` — create a page in a database (with title property)
- Additional helpers: headings, to-dos, database listing, snippets

## Troubleshooting
- Connection closed (-32000)
  - Ensure Node is available on PATH
  - Reinstall: `gemini extensions uninstall notion` ? `gemini extensions install <repo>`
- API token is invalid
  - Verify your key is correct and set in the right place
  - Confirm your integration has access to the specific pages/databases
- Verify the bundled entry runs
  - Windows: `node "%USERPROFILE%\.gemini\extensions\notion\dist\extension.cjs"`
  - macOS/Linux: `node "$HOME/.gemini/extensions/notion/dist/extension.cjs"`

## Uninstall / Update
- Uninstall GitHub-installed extension: `gemini extensions uninstall notion`
- Update: uninstall, then install again from the GitHub URL
- Remove local link: `gemini extensions unlink notion`

## License
MIT
