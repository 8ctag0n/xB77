import { createServer } from 'http';
import { readFileSync } from 'fs';
import { resolve } from 'path';

const compressionPort = Number(process.env.LIGHT_COMPRESSION_PORT || 8784);
const proverPort = Number(process.env.LIGHT_PROVER_PORT || 3001);
const accountsDir = resolve(__dirname, 'accounts');

// 128 bytes total: a(32) + b(64) + c(32)
const proofFixture = {
  a: Array(32).fill(7),
  b: Array(64).fill(7),
  c: Array(32).fill(7),
};

function buildTreeInfos() {
  return [
    {
      treeId: 'state-tree-1',
      tree: 'bmt1LryLZUMmF7ZtqESaw7wifBXLfXHQYoE4GAmrahU',
      height: 26,
      rootIndex: 0,
      queue: 'oq1na8gojfdUhsfCpyjNt6h4JaDWtHf1yQj4koBWfto',
    },
    {
      treeId: 'address-tree-1',
      tree: 'amt1Ayt45jfbdw5YSo7iz6WZxUmnZsQTYXy82hVwyC2',
      height: 26,
      rootIndex: 0,
      queue: 'aq1S9z4reTSQAdgWHGD2zDaS39sjGrAxbR31vxJ2F4F',
    },
    {
      treeId: 'address-tree-2',
      tree: 'amt2kaJA14v3urZbZvnc5v2np8jqvc4Z8zDep5wbtzx',
      height: 26,
      rootIndex: 0,
      queue: 'aq1S9z4reTSQAdgWHGD2zDaS39sjGrAxbR31vxJ2F4F', // Reuse queue for stub
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
      return respond({ trees: buildTreeInfos() });
    case 'getValidityProofV0':
    case 'getValidityProofV2':
      const trees = buildTreeInfos();
      const validityResponse = {
        compressedProof: proofFixture,
        proof: proofFixture,
        rootIndices: [0],
        merkleTreeRootIndices: [],
        addressMerkleTreeRootIndices: [0],
        leaves: [Array(32).fill(0)],
        roots: [Array(32).fill(0)],
        proveByIndices: [0],
        leafIndices: [0],
        treeInfos: trees,
        accounts: [],
        addresses: [],
        addressMerkleTreeIndices: [],
        addressQueueIndices: [],
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
