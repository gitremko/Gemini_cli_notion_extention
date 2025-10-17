import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { buildNotionServer } from './shared/notionServer.js';

const server = buildNotionServer();

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((err) => {
  console.error('Failed to start Notion MCP server:', err);
  process.exit(1);
});
