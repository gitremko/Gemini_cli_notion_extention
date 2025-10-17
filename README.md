# Notion MCP for Gemini CLI

A lightweight Model Context Protocol (MCP) server that lets Gemini CLI (and other MCP clients) search, read, and write Notion content.

[![CI](https://github.com/gitremko/Gemini_cli_notion_extention/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/gitremko/Gemini_cli_notion_extention/actions/workflows/ci.yml)

## Requirements
- Gemini CLI installed and working
- Node.js 20+ and npm
- A Notion Internal Integration (API key)

## Quick Install (recommended)
- Install from GitHub:
  - `gemini extensions install https://github.com/gitremko/Gemini_cli_notion_extention`
- Create a Notion Internal Integration and grant access (see below)
- Set your API key (see "Set API Key")
- Restart Gemini CLI, then run: `gemini extensions list` (should show `notion`)

## Create the Notion Integration (required)
1) Open https://www.notion.so/profile/integrations
2) Click "New integration"
   - Workspace: choose the workspace you will use
   - Type: Internal
   - Capabilities: enable at minimum "Read content". To write, also enable "Insert content" and "Update content".
   - Save
3) Grant access to pages/databases
   - In the integration page, open the "Access" tab and add the pages/databases you want to use
   - Or share specific Notion pages/databases with your integration from Notion
4) Copy the "Internal Integration Secret" â€” this is your API key

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
- After install, Gemini CLI discovers the MCP server `notion` automatically.
- Try a simple tool call (search):
  - Ask: "search Notion for 'your term'" â€” the tool used is `notion_search`.

## Local Development (link)
- `git clone https://github.com/gitremko/Gemini_cli_notion_extention && cd Gemini_cli_notion_extention`
- `npm install && npm run build`
- `gemini extensions link .`
- Edit code, then `npm run build` and restart Gemini CLI
- Unlink later: `gemini extensions unlink notion`

## Available Tools (full)

- `notion_search` â€” search pages/databases (query, optional filter, page_size)
- `notion_get_page` â€” fetch a page object by id
- `notion_list_blocks` â€” list child blocks for a page/block
- `notion_append_paragraph` â€” append paragraph text
- `notion_create_page` â€” create a page in a database (with title property)
- `notion_create_subpage` â€” create a subpage under a page
- `notion_query_database` â€” query a database (filter, sorts, cursor, page_size)
- `notion_update_page` â€” update properties of a page
- `notion_get_block` â€” fetch a single block by id
- `notion_append_blocks` â€” append one or more blocks under a parent
- `notion_archive_page` â€” archive a page
- `notion_unarchive_page` â€” restore an archived page
- `notion_delete_block` â€” delete (archive) a block
- `notion_update_block_text` â€” update rich_text of paragraph/heading
- `notion_append_heading` â€” append a heading (1/2/3)
- `notion_append_todo` â€” append a to_do (checkbox)
- `notion_list_databases` â€” list databases in the workspace
- `notion_list_pages_in_database` â€” list pages in a database
- `notion_append_image_url` â€” append an image block from an external URL

Prompts
- `notion_build_filter` â€” build a database filter skeleton
- `notion_blocks_snippet` â€” generate blocks JSON for append
- `notion_create_page_snippet` â€” generate properties JSON for page creation

## Troubleshooting
- Connection closed (-32000): ensure Node is available on PATH and reinstall the extension.
- API token is invalid: verify your key and that the integration has access to the pages/databases.
- Verify the bundled entry runs:
  - Windows: `node "%USERPROFILE%\.gemini\extensions\notion\dist\extension.cjs"`
  - macOS/Linux: `node "$HOME/.gemini/extensions/notion/dist/extension.cjs"`

## Uninstall / Update
- Uninstall a GitHub-installed extension: `gemini extensions uninstall notion`
- Update: uninstall, then install again from the GitHub URL
- Remove a local link: `gemini extensions unlink notion`

## License
MIT


