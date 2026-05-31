import { 
  type Hex, 
  type PublicClient, 
  type WalletClient, 
  getContract, 
  encodeFunctionData,
  parseAbi
} from "viem";

/**
 * ERC-8004 Trustless Agents Registry ABI (Simplified for Demo)
 */
const ERC8004_ABI = parseAbi([
  "function registerAgent(string name, string metadataUri) external returns (uint256)",
  "function postReputation(uint256 agentId, bytes32 signal, int8 score) external",
  "function getAgentId(address owner) external view returns (uint256)",
  "event AgentRegistered(uint256 indexed agentId, address indexed owner, string name)"
]);

const IDENTITY_REGISTRY = "0x8004A818BFB912233c491871b3d84c89A494BD9e";
const REPUTATION_REGISTRY = "0x8004B663056A597Dffe9eCcC1965A193B7388713";

export class AgentIdentityManager {
  constructor(private publicClient: PublicClient, private walletClient: WalletClient) {}

  /**
   * Registers the agent as a first-class citizen on Arbitrum via ERC-8004.
   */
  async registerAgent(name: string, metadataUri: string): Promise<bigint> {
    const { request } = await this.publicClient.simulateContract({
      address: IDENTITY_REGISTRY as Hex,
      abi: ERC8004_ABI,
      functionName: "registerAgent",
      args: [name, metadataUri],
      account: this.walletClient.account!,
    });

    const hash = await this.walletClient.writeContract(request);
    console.log(`[IDENTITY] Agent Registered! NFT Minted: ${hash}`);
    
    // In a real scenario, we'd parse the log to get the ID.
    return 1n; // Mock ID
  }

  /**
   * Posts an on-chain reputation signal based on Stylus enforcement.
   */
  async attestCompliance(agentId: bigint, approved: boolean) {
    const signal = approved ? "SEMANTIC_APPROVED" : "SEMANTIC_REJECTED";
    const score = approved ? 1 : -5; // Harsh penalty for toxic intent

    const { request } = await this.publicClient.simulateContract({
      address: REPUTATION_REGISTRY as Hex,
      abi: ERC8004_ABI,
      functionName: "postReputation",
      args: [agentId, signal as any, score],
      account: this.walletClient.account!,
    });

    await this.walletClient.writeContract(request);
    console.log(`[REPUTATION] Attestation Posted: ${signal} (Score Change: ${score})`);
  }
}
