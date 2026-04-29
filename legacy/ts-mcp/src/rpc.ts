export function buildHeliusUrl(url?: string, fallback?: string): string | undefined {
  const heliusKey = process.env.HELIUS_API_KEY;
  let target = url ?? fallback;

  if (!target && heliusKey) {
    return `https://devnet.helius-rpc.com/?api-key=${heliusKey}`;
  }

  if (target && heliusKey && target.includes('helius-rpc.com') && !target.includes('api-key=')) {
    const separator = target.includes('?') ? '&' : '?';
    return `${target}${separator}api-key=${heliusKey}`;
  }

  return target;
}

export function resolveRpcUrls(options: {
  rpcUrl?: string;
  compressionUrl?: string;
  proverUrl?: string;
  fallbackRpc?: string;
}): { rpcUrl: string; compressionUrl: string; proverUrl: string } {
  const heliusKey = process.env.HELIUS_API_KEY;
  const fallbackRpc = options.fallbackRpc ?? 'http://localhost:8899';

  let rpcUrl =
    options.rpcUrl ??
    (heliusKey ? `https://devnet.helius-rpc.com/?api-key=${heliusKey}` : undefined) ??
    fallbackRpc;

  rpcUrl = buildHeliusUrl(rpcUrl, fallbackRpc) ?? fallbackRpc;
  const compressionUrl = buildHeliusUrl(options.compressionUrl, rpcUrl) ?? rpcUrl;
  const proverUrl = buildHeliusUrl(options.proverUrl, rpcUrl) ?? rpcUrl;

  return { rpcUrl, compressionUrl, proverUrl };
}
