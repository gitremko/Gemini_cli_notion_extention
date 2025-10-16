import { Client as NotionClient } from '@notionhq/client';
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { z } from 'zod';
import { completable } from '@modelcontextprotocol/sdk/server/completable.js';

function getNotionApiKey(): string | undefined {
  return (
    process.env.NOTION_API_KEY ||
    process.env.GEMINI_NOTION_API_KEY ||
    process.env.GEMINI_API_KEY ||
    process.env.NOTION_TOKEN ||
    process.env.NOTION_SECRET
  );
}

export function buildNotionServer(): McpServer {
  const NOTION_API_KEY = getNotionApiKey();
  if (!NOTION_API_KEY) {
    console.error(
      'No Notion API key found. Set one of: NOTION_API_KEY, GEMINI_NOTION_API_KEY, NOTION_TOKEN, NOTION_SECRET.'
    );
    process.exit(1);
  }

  const notion = new NotionClient({ auth: NOTION_API_KEY });

  const server = new McpServer({
    name: 'notion-mcp-server',
    version: '0.1.0'
  });

  // Tool: search Notion (pages and databases)
  server.registerTool(
    'notion_search',
    {
      title: 'Notion Search',
      description: "Zoek naar Notion pagina's en databases",
      inputSchema: {
        query: z.string().min(1, 'query is verplicht'),
        filter: z
          .object({ value: z.enum(['page', 'database']), property: z.literal('object') })
          .optional(),
        page_size: z.number().int().min(1).max(100).optional()
      },
      outputSchema: {
        results: z.array(
          z.object({ id: z.string(), object: z.string(), title: z.string().optional(), url: z.string().optional() })
        ),
        has_more: z.boolean()
      }
    },
    async ({ query, filter, page_size }) => {
      const res = await notion.search({
        query,
        filter: filter as any,
        page_size
      });

      const results = res.results.map((r: any) => {
        if (r.object === 'page') {
          const title = extractTitleFromPage(r);
          return { id: r.id, object: r.object, title, url: r.url };
        }
        if (r.object === 'database') {
          const title = r.title?.[0]?.plain_text;
          return { id: r.id, object: r.object, title, url: r.url };
        }
        return { id: (r as any).id, object: (r as any).object };
      });

      const output = { results, has_more: !!res.has_more };
      return {
        content: [{ type: 'text', text: JSON.stringify(output, null, 2) }],
        structuredContent: output
      };
    }
  );

  // Tool: get page properties
  server.registerTool(
    'notion_get_page',
    {
      title: 'Get Notion Page',
      description: 'Lees meta/properties van een Notion pagina',
      inputSchema: { page_id: z.string().min(1) }
      // No strict output schema; returns full Notion page object
    },
    async ({ page_id }) => {
      const page = await notion.pages.retrieve({ page_id });
      const output = page as unknown as Record<string, unknown>;
      return {
        content: [{ type: 'text', text: JSON.stringify(output, null, 2) }],
        structuredContent: output
      };
    }
  );

  // Tool: list child blocks of a page or block
  server.registerTool(
    'notion_list_blocks',
    {
      title: 'List Notion Blocks',
      description: 'Haal blokken (content) op van een Notion pagina of block',
      inputSchema: {
        block_id: z.string().min(1),
        page_size: z.number().int().min(1).max(100).optional()
      }
      // No strict output schema; returns Notion blocks response
    },
    async ({ block_id, page_size }) => {
      const res = await notion.blocks.children.list({ block_id, page_size });
      const output = res as unknown as Record<string, unknown>;
      return {
        content: [{ type: 'text', text: JSON.stringify(output, null, 2) }],
        structuredContent: output
      };
    }
  );

  // Tool: append simple paragraph text to a page or block
  server.registerTool(
    'notion_append_paragraph',
    {
      title: 'Append Paragraph',
      description: 'Voeg een paragraaf tekst toe aan een pagina of block',
      inputSchema: {
        parent_block_id: z.string().min(1),
        text: z.string().min(1)
      },
      outputSchema: { success: z.boolean(), added_block_id: z.string().optional() }
    },
    async ({ parent_block_id, text }) => {
      const res = await notion.blocks.children.append({
        block_id: parent_block_id,
        children: [
          {
            object: 'block',
            type: 'paragraph',
            paragraph: { rich_text: [{ type: 'text', text: { content: text } }] }
          }
        ]
      } as any);

      const added = (res as any).results?.[0]?.id as string | undefined;
      const output = { success: true, added_block_id: added };
      return {
        content: [{ type: 'text', text: JSON.stringify(output, null, 2) }],
        structuredContent: output
      };
    }
  );

  // Tool: create a page in a database
  server.registerTool(
    'notion_create_page',
    {
      title: 'Create Page In Database',
      description:
        'Maak een pagina aan in een Notion database. Geeft de property-naam voor de titel door (default: "Name").',
      inputSchema: {
        database_id: z.string().min(1),
        title: z.string().min(1),
        title_property: z.string().min(1).default('Name'),
        properties: z.record(z.any()).optional()
      }
      // No strict output schema; returns created page
    },
    async ({ database_id, title, title_property, properties }) => {
      const page = await notion.pages.create({
        parent: { database_id },
        properties: {
          [title_property ?? 'Name']:
            {
              title: [
                {
                  text: { content: title }
                }
              ]
            },
          ...(properties ?? {})
        }
      } as any);

      const output = page as unknown as Record<string, unknown>;
      return {
        content: [{ type: 'text', text: JSON.stringify(output, null, 2) }],
        structuredContent: output
      };
    }
  );

  // Tool: create a child page under an existing page
  server.registerTool(
    'notion_create_subpage',
    {
      title: 'Create Subpage',
      description:
        'Maak een subpagina aan onder een bestaande Notion pagina (parent page_id).',
      inputSchema: {
        parent_page_id: z.string().min(1),
        title: z.string().min(1),
        title_property: z.string().min(1).default('title'),
        properties: z.record(z.any()).optional()
      }
      // No strict output schema; returns created page
    },
    async ({ parent_page_id, title, title_property, properties }) => {
      // Notion accepteert subpage-creatie door parent: { page_id }
      // Voor de titel gebruiken we een 'title' property (standaard key: 'title')
      const page = await notion.pages.create({
        parent: { page_id: parent_page_id },
        properties: {
          [title_property ?? 'title']:
            {
              title: [
                {
                  text: { content: title }
                }
              ]
            },
          ...(properties ?? {})
        }
      } as any);

      const output = page as unknown as Record<string, unknown>;
      return {
        content: [{ type: 'text', text: JSON.stringify(output, null, 2) }],
        structuredContent: output
      };
    }
  );

  // Tool: query a database (filter/sorts)
  server.registerTool(
    'notion_query_database',
    {
      title: 'Query Database',
      description: 'Voer een Notion database query uit met filter/sorts/start_cursor/page_size',
      inputSchema: {
        database_id: z.string().min(1),
        filter: z.record(z.any()).optional(),
        sorts: z.array(z.record(z.any())).optional(),
        start_cursor: z.string().optional(),
        page_size: z.number().int().min(1).max(100).optional()
      }
    },
    async ({ database_id, filter, sorts, start_cursor, page_size }) => {
      const res = await notion.databases.query({
        database_id,
        filter: filter as any,
        sorts: sorts as any,
        start_cursor,
        page_size
      } as any);
      const output = res as unknown as Record<string, unknown>;
      return {
        content: [{ type: 'text', text: JSON.stringify(output, null, 2) }],
        structuredContent: output
      };
    }
  );

  // Tool: update page properties
  server.registerTool(
    'notion_update_page',
    {
      title: 'Update Page Properties',
      description: 'Werk properties bij van een bestaande Notion pagina',
      inputSchema: {
        page_id: z.string().min(1),
        properties: z.record(z.any())
      }
    },
    async ({ page_id, properties }) => {
      const page = await notion.pages.update({
        page_id,
        properties: properties as any
      } as any);
      const output = page as unknown as Record<string, unknown>;
      return {
        content: [{ type: 'text', text: JSON.stringify(output, null, 2) }],
        structuredContent: output
      };
    }
  );

  // Tool: get a single block
  server.registerTool(
    'notion_get_block',
    {
      title: 'Get Block',
      description: 'Lees één Notion block op basis van block_id',
      inputSchema: { block_id: z.string().min(1) }
    },
    async ({ block_id }) => {
      const block = await notion.blocks.retrieve({ block_id });
      const output = block as unknown as Record<string, unknown>;
      return {
        content: [{ type: 'text', text: JSON.stringify(output, null, 2) }],
        structuredContent: output
      };
    }
  );

  // Tool: append multiple blocks (generic)
  server.registerTool(
    'notion_append_blocks',
    {
      title: 'Append Blocks',
      description: 'Voeg één of meer blokken toe onder een parent block/pagina',
      inputSchema: {
        parent_block_id: z.string().min(1),
        blocks: z.array(z.record(z.any())).min(1)
      },
      outputSchema: { success: z.boolean(), added_block_ids: z.array(z.string()).optional() }
    },
    async ({ parent_block_id, blocks }) => {
      const res = await notion.blocks.children.append({
        block_id: parent_block_id,
        children: blocks as any
      } as any);
      const ids = ((res as any).results || []).map((b: any) => b?.id).filter(Boolean);
      const output = { success: true, added_block_ids: ids };
      return {
        content: [{ type: 'text', text: JSON.stringify(output, null, 2) }],
        structuredContent: output
      };
    }
  );

  // Tool: archive/unarchive page
  server.registerTool(
    'notion_archive_page',
    {
      title: 'Archive Page',
      description: 'Archiveer een bestaande Notion pagina',
      inputSchema: { page_id: z.string().min(1) }
    },
    async ({ page_id }) => {
      const page = await notion.pages.update({ page_id, archived: true } as any);
      const output = page as unknown as Record<string, unknown>;
      return { content: [{ type: 'text', text: JSON.stringify(output, null, 2) }], structuredContent: output };
    }
  );

  server.registerTool(
    'notion_unarchive_page',
    {
      title: 'Unarchive Page',
      description: 'Zet een gearchiveerde pagina terug naar actief',
      inputSchema: { page_id: z.string().min(1) }
    },
    async ({ page_id }) => {
      const page = await notion.pages.update({ page_id, archived: false } as any);
      const output = page as unknown as Record<string, unknown>;
      return { content: [{ type: 'text', text: JSON.stringify(output, null, 2) }], structuredContent: output };
    }
  );

  // Tool: delete block
  server.registerTool(
    'notion_delete_block',
    {
      title: 'Delete Block',
      description: 'Verwijder een block (archiveer)',
      inputSchema: { block_id: z.string().min(1) }
    },
    async ({ block_id }) => {
      const res = await notion.blocks.delete({ block_id } as any);
      const output = res as unknown as Record<string, unknown>;
      return { content: [{ type: 'text', text: JSON.stringify(output, null, 2) }], structuredContent: output };
    }
  );

  // Tool: update simple text in a paragraph/heading block
  server.registerTool(
    'notion_update_block_text',
    {
      title: 'Update Block Text',
      description: 'Werk de rich_text van paragraph of heading (1/2/3) bij',
      inputSchema: {
        block_id: z.string().min(1),
        type: z.enum(['paragraph', 'heading_1', 'heading_2', 'heading_3']),
        text: z.string().min(1)
      }
    },
    async ({ block_id, type, text }) => {
      const payload: any = { [type]: { rich_text: [{ type: 'text', text: { content: text } }] } };
      const res = await notion.blocks.update({ block_id, ...payload } as any);
      const output = res as unknown as Record<string, unknown>;
      return { content: [{ type: 'text', text: JSON.stringify(output, null, 2) }], structuredContent: output };
    }
  );

  // Convenience tools to append headings and checkboxes
  server.registerTool(
    'notion_append_heading',
    {
      title: 'Append Heading',
      description: 'Voeg een heading toe (1/2/3)',
      inputSchema: {
        parent_block_id: z.string().min(1),
        level: z.enum(['heading_1', 'heading_2', 'heading_3']).default('heading_2'),
        text: z.string().min(1)
      }
    },
    async ({ parent_block_id, level, text }) => {
      const res = await notion.blocks.children.append({
        block_id: parent_block_id,
        children: [
          { object: 'block', type: level, [level]: { rich_text: [{ type: 'text', text: { content: text } }] } }
        ]
      } as any);
      const output = res as unknown as Record<string, unknown>;
      return { content: [{ type: 'text', text: JSON.stringify(output, null, 2) }], structuredContent: output };
    }
  );

  server.registerTool(
    'notion_append_todo',
    {
      title: 'Append To-do',
      description: 'Voeg een to_do item toe (checkbox)',
      inputSchema: {
        parent_block_id: z.string().min(1),
        text: z.string().min(1),
        checked: z.boolean().default(false)
      }
    },
    async ({ parent_block_id, text, checked }) => {
      const res = await notion.blocks.children.append({
        block_id: parent_block_id,
        children: [
          { object: 'block', type: 'to_do', to_do: { checked: !!checked, rich_text: [{ type: 'text', text: { content: text } }] } }
        ]
      } as any);
      const output = res as unknown as Record<string, unknown>;
      return { content: [{ type: 'text', text: JSON.stringify(output, null, 2) }], structuredContent: output };
    }
  );

  // Tools: list databases, list pages in a database
  server.registerTool(
    'notion_list_databases',
    {
      title: 'List Databases',
      description: 'Zoek naar databases in de workspace',
      inputSchema: { query: z.string().optional(), page_size: z.number().int().min(1).max(100).optional() }
    },
    async ({ query, page_size }) => {
      const res = await notion.search({ query, filter: { property: 'object', value: 'database' } as any, page_size });
      const results = res.results.map((r: any) => ({ id: r.id, object: r.object, title: r.title?.[0]?.plain_text, url: r.url }));
      const output = { results, has_more: !!res.has_more };
      return { content: [{ type: 'text', text: JSON.stringify(output, null, 2) }], structuredContent: output };
    }
  );

  server.registerTool(
    'notion_list_pages_in_database',
    {
      title: 'List Pages In Database',
      description: 'Haal pagina\'s op uit een database (zonder filter)',
      inputSchema: { database_id: z.string().min(1), page_size: z.number().int().min(1).max(100).optional() }
    },
    async ({ database_id, page_size }) => {
      const res = await notion.databases.query({ database_id, page_size } as any);
      const results = (res.results || []).map((p: any) => ({ id: p.id, url: p.url, title: extractTitleFromPage(p) }));
      const output = { results, has_more: !!(res as any).has_more };
      return { content: [{ type: 'text', text: JSON.stringify(output, null, 2) }], structuredContent: output };
    }
  );

  // Tool: append image from external URL
  server.registerTool(
    'notion_append_image_url',
    {
      title: 'Append Image (URL)',
      description: 'Voeg een image block toe met external URL',
      inputSchema: { parent_block_id: z.string().min(1), url: z.string().url() }
    },
    async ({ parent_block_id, url }) => {
      const res = await notion.blocks.children.append({
        block_id: parent_block_id,
        children: [
          { object: 'block', type: 'image', image: { type: 'external', external: { url } } }
        ]
      } as any);
      const output = res as unknown as Record<string, unknown>;
      return { content: [{ type: 'text', text: JSON.stringify(output, null, 2) }], structuredContent: output };
    }
  );

  // Helper prompts
  server.registerPrompt(
    'notion_build_filter',
    {
      title: 'Build Database Filter',
      description: 'Stel eenvoudig een filter op voor database queries',
      argsSchema: {
        property: completable(z.string(), (v) => ['Name','Title','Status','Assignee','Tags','Priority','Done'].filter(x => x.toLowerCase().startsWith((v||'').toLowerCase()))),
        operator: completable(z.string(), (v) => ['equals','does_not_equal','contains','does_not_contain','starts_with','ends_with','greater_than','less_than','on_or_after','on_or_before','is_empty','is_not_empty'].filter(x => x.startsWith(v||''))),
        value: z.string().optional()
      }
    },
    ({ property, operator, value }) => ({
      messages: [
        {
          role: 'assistant',
          content: {
            type: 'text',
            text: `Use this filter in notion_query_database:\n\n${JSON.stringify({ filter: { property, rich_text: { contains: value || '' } } }, null, 2)}\n\nOperators supported vary by property type. Adjust 'rich_text' to e.g. 'title', 'status', 'select', etc., and operator to 'equals', 'contains', ...`
          }
        }
      ]
    })
  );

  server.registerPrompt(
    'notion_blocks_snippet',
    {
      title: 'Blocks Snippet',
      description: 'Genereer blocks JSON voor append',
      argsSchema: {
        type: completable(z.string(), (v) => ['paragraph','heading_1','heading_2','to_do','quote','bulleted_list_item'].filter(x => x.startsWith(v||''))),
        text: z.string()
      }
    },
    ({ type, text }) => ({
      messages: [
        {
          role: 'assistant',
          content: {
            type: 'text',
            text: `Blocks JSON:\n\n${JSON.stringify([{ object: 'block', type, [type]: type === 'to_do' ? { checked: false, rich_text: [{ type:'text', text:{ content:text } }]} : { rich_text: [{ type:'text', text:{ content:text } }]} }], null, 2)}`
          }
        }
      ]
    })
  );

  server.registerPrompt(
    'notion_create_page_snippet',
    {
      title: 'Create Page Snippet',
      description: 'Genereer properties JSON voor pagina creatie',
      argsSchema: { title_property: z.string(), title: z.string() }
    },
    ({ title_property, title }) => ({
      messages: [
        {
          role: 'assistant',
          content: { type: 'text', text: `Properties JSON:\n\n${JSON.stringify({ [title_property || 'Name']: { title: [{ text: { content: title } }] } }, null, 2)}` }
        }
      ]
    })
  );

  return server;
}

function extractTitleFromPage(page: any): string | undefined {
  if (!page || !page.properties) return undefined;
  const props = page.properties;
  for (const key of Object.keys(props)) {
    const prop = props[key];
    if (prop?.type === 'title' && Array.isArray(prop.title)) {
      const first = prop.title[0];
      if (first?.plain_text) return first.plain_text;
      if (first?.text?.content) return first.text.content;
    }
  }
  return undefined;
}
