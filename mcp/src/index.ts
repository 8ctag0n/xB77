import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  type CallToolRequest,
} from '@modelcontextprotocol/sdk/types.js';
import type { AgentContext } from './agent_tools.ts';
import { buildAgentContext, handleToolCall, listTools } from './agent_tools.ts';

let context: AgentContext;
try {
  context = await buildAgentContext();
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`[xb77-mcp] startup failed: ${message}`);
  process.exit(1);
}

const server = new Server(
  {
    name: 'xb77-agent-mcp',
    version: '0.1.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: listTools(),
  };
});

server.setRequestHandler(CallToolRequestSchema, async (request: CallToolRequest) => {
  const { name, arguments: args } = request.params;
  return await handleToolCall(context, name, args);
});

const transport = new StdioServerTransport();
await server.connect(transport);
console.error('[xb77-mcp] Agent MCP server running over stdio.');
