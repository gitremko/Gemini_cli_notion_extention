#!/usr/bin/env node
const mode = (process.env.MCP_TRANSPORT || '').toLowerCase();

(async () => {
  if (mode === 'http') {
    await import('./http.js');
  } else {
    await import('./server.js');
  }
})();

export {};
