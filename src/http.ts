import 'dotenv/config';
import express, { Request, Response } from 'express';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { buildNotionServer } from './shared/notionServer.js';

const server = buildNotionServer();

async function main() {
  const app = express();
  app.use(express.json({ limit: '2mb' }));

  app.post('/mcp', async (req: Request, res: Response) => {
    const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined, enableJsonResponse: true });
    res.on('close', () => transport.close());
    await server.connect(transport);
    await transport.handleRequest(req, res, req.body);
  });

  const port = parseInt(process.env.PORT || '3030', 10);
  app.listen(port, () => console.log(`Notion MCP (HTTP) on http://localhost:${port}/mcp`));
}

main().catch(err => {
  console.error('Failed to start HTTP server:', err);
  process.exit(1);
});
