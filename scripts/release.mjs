import { promises as fs } from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const to = path.join(root, 'release');
const distSrc = path.join(root, 'dist', 'extension.js');

async function rmrf(dir) {
  try {
    await fs.rm(dir, { recursive: true, force: true });
  } catch {}
}

async function ensureDir(dir) {
  await fs.mkdir(dir, { recursive: true });
}

async function copy(src, dest) {
  await ensureDir(path.dirname(dest));
  await fs.copyFile(src, dest);
}

async function main() {
  // Verify build exists
  try {
    await fs.access(distSrc);
  } catch {
    console.error('Missing dist/extension.js. Run: npm run build');
    process.exit(1);
  }

  await rmrf(to);
  await ensureDir(to);

  await copy(distSrc, path.join(to, 'dist', 'extension.js'));
  await copy(path.join(root, 'gemini-extension.json'), path.join(to, 'gemini-extension.json'));

  const readme = `# Notion MCP Extension (Gemini CLI)

Minimal distributie voor eindgebruikers.

Installatie

- Vereist: Node 18+, en een Notion integration token als user variabele.
- Zet je key als gebruikersvariabele (CMD):
  setx NOTION_API_KEY "secret_xxx_from_notion"

- Installeer in Gemini CLI vanaf dit pad:
  gemini extensions install <pad-naar-deze-map>

Wat zit erin

- gemini-extension.json — start MCP via stdio
- dist/extension.js — gebundelde server zonder extra dependencies

Gebruik

- Herstart Gemini CLI, controleer extensions list
- In chat: /mcp of de Notion tools gebruiken

`;

  await fs.writeFile(path.join(to, 'README.md'), readme, 'utf8');
  console.log('Release gemaakt in', to);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});

