import { createServer } from 'http';

const compressionPort = Number(process.env.LIGHT_COMPRESSION_PORT || 8784);
const proverPort = Number(process.env.LIGHT_PROVER_PORT || 3001);

const ADDRESS_TREE_V2 = 'amt2kaJA14v3urZbZvnc5v2np8jqvc4Z8zDep5wbtzx';
const ADDRESS_QUEUE_V2 = 'aq1S9z4reTSQAdgWHGD2zDaS39sjGrAxbR31vxJ2F4F';
const STATE_TREE_V1 = 'smt1NamzXdq4AMqS2fS2F1i5KTYPZRhoHgWx38d8WsT';
const NULLIFIER_QUEUE_V1 = 'nfq1NvQDJ2GEgnS8zt9prAe8rjjpAW1zFkrvZoBR148';
const STATE_TREE_V2 = 'bmt1LryLZUMmF7ZtqESaw7wifBXLfXHQYoE4GAmrahU';
const OUTPUT_QUEUE_V2 = 'oq1na8gojfdUhsfCpyjNt6h4JaDWtHf1yQj4koBWfto';
const ZERO_B58 = '11111111111111111111111111111111';

const treeQueueMap: Record<string, string> = {
  [ADDRESS_TREE_V2]: ADDRESS_QUEUE_V2,
  [STATE_TREE_V1]: NULLIFIER_QUEUE_V1,
  [STATE_TREE_V2]: OUTPUT_QUEUE_V2,
};

// 128 bytes total: a(32) + b(64) + c(32)
const proofFixture = {
  a: Array.from({ length: 32 }, (_, i) => i + 1),
  b: Array.from({ length: 64 }, (_, i) => i + 1),
  c: Array.from({ length: 32 }, (_, i) => i + 1),
};

function buildTreeInfos() {
  return [
    {
      tree: STATE_TREE_V1,
      queue: NULLIFIER_QUEUE_V1,
      treeType: 1,
      nextTreeInfo: null,
    },
    {
      tree: STATE_TREE_V2,
      queue: OUTPUT_QUEUE_V2,
      treeType: 3,
      nextTreeInfo: null,
    },
    {
      tree: ADDRESS_TREE_V2,
      queue: ADDRESS_QUEUE_V2,
      treeType: 4,
      nextTreeInfo: null,
    },
  ];
}

const rpcServer = createServer(async (req, res) => {
  if (req.method !== 'POST') {
    res.statusCode = 405;
    return res.end('Method Not Allowed');
  }

  const chunks: Buffer[] = [];
  for await (const chunk of req) {
    chunks.push(chunk as Buffer);
  }
  const body = Buffer.concat(chunks).toString('utf8');

  let payload: any;
  try {
    payload = JSON.parse(body);
    console.log(`[RPC] method=${payload.method} params:`, JSON.stringify(payload.params));
  } catch {
    res.writeHead(400, { 'content-type': 'application/json' });
    return res.end(JSON.stringify({ error: 'invalid json' }));
  }

  const respond = (result: unknown) => {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ jsonrpc: '2.0', id: payload.id ?? null, result }));
  };

  if (!payload.method) {
    return respond({ error: 'missing method' });
  }

  switch (payload.method) {
    case 'getStateTreeInfos':
      return respond(buildTreeInfos());
    case 'getValidityProofV0':
    case 'getValidityProofV2':
      const requestedAddress =
        payload?.params?.newAddressesWithTrees?.[0] ??
        payload?.params?.newAddresses?.[0] ??
        payload?.params?.[1]?.[0] ??
        {};
      const address = typeof requestedAddress.address === 'string' ? requestedAddress.address : ZERO_B58;
      const tree = typeof requestedAddress.tree === 'string' ? requestedAddress.tree : ADDRESS_TREE_V2;
      const queue = treeQueueMap[tree] ?? ADDRESS_QUEUE_V2;
      const validityResponse = {
        compressedProof: null,
        accounts: [],
        addresses: [
          {
            address,
            merkleContext: {
              tree,
              queue,
              treeType: 4,
              cpiContext: null,
              nextTreeContext: null,
            },
            rootIndex: 0,
            root: ZERO_B58,
          },
        ],
      };
      return respond({
        value: validityResponse,
        context: { slot: 1000 },
      });
    default:
      res.writeHead(501, { 'content-type': 'application/json' });
      return res.end(
        JSON.stringify({
          jsonrpc: '2.0',
          id: payload.id ?? null,
          error: { code: -32601, message: 'not implemented' },
        })
      );
  }
});

const proverServer = createServer(async (req, res) => {
  if (req.method !== 'POST' || req.url !== '/prove') {
    res.writeHead(404);
    return res.end('Not found');
  }
  for await (const _ of req);
  res.writeHead(200, { 'content-type': 'application/json' });
  res.end(JSON.stringify({ proof: proofFixture.toString('base64') }));
});

rpcServer.listen(compressionPort, () => {
  console.log(`[light-local] compression api listening on http://127.0.0.1:${compressionPort}`);
});

proverServer.listen(proverPort, () => {
  console.log(`[light-local] prover service listening on http://127.0.0.1:${proverPort}`);
});
