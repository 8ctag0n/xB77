import {
  createKernelAccount,
  createKernelAccountClient,
  createZeroDevPaymasterClient,
} from "@zerodev/sdk";
import { KERNEL_V3_1 } from "@zerodev/sdk/constants";
import { toPermissionValidator, type Policy } from "@zerodev/permissions";
import { toECDSASigner } from "@zerodev/permissions/signers";
import {
  http,
  createPublicClient,
  type PublicClient,
  type Hex,
  type Hash,
  encodePacked,
  encodeAbiParameters,
  decodeAbiParameters,
  concatHex,
  pad,
  toHex,
  keccak256,
} from "viem";
import { grantPermissions as viemGrantPermissions } from "viem/experimental";
import { arbitrumSepolia } from "viem/chains";
import { privateKeyToAccount } from "viem/accounts";

// ── xB77 chain IDs (must match onchain/stylus/main.zig) ───────────────────
export const XB77_CHAIN = {
  SOLANA:   0x01,
  SUI:      0x02,
  ARC:      0x03,
  ARBITRUM: 0x04,
} as const;
export type XB77ChainId = (typeof XB77_CHAIN)[keyof typeof XB77_CHAIN];

// ── Deployed addresses (Arbitrum Sepolia) ─────────────────────────────────
export const ARBITRUM_SEPOLIA_ADDRESSES = {
  USDC:               "0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d" as Hex,
  WETH:               "0x980B62Da83eFf3D4576C647993b0c1D7faf17c73" as Hex,
  CIRCLE_MESSENGER:   "0xaCF1ceeF35caAc005e15888dDb8A3515C41B4872" as Hex,
  ENTRY_POINT_V07:    "0x0000000071727De22E5E9d8BAf0edAc6f37da032" as Hex,
  AAVE_POOL:          "0xBfC91D59fdAA134A4ED45f7B584cAf96D7792Eff" as Hex,
  GMX_ROUTER:         "0x7C68C7866A64FA2160F78EEaE12217FFbf871fa8" as Hex,
  GMX_ORDER_VAULT:    "0x31eF83a530Fde1B38EE9A18093A333D8Bbbc40D5" as Hex,
} as const;

// ── AaveGuard selectors (match onchain/stylus/aave_guard.zig) ────────────
const SEL_AAVE_SUPPLY      = "0xa415bcad" as Hex;
const SEL_AAVE_BORROW      = "0xd65b7976" as Hex;
const SEL_AAVE_REPAY       = "0x573ade81" as Hex;
const SEL_AAVE_WITHDRAW    = "0x69328dec" as Hex;
const SEL_AAVE_FLASH_LOAN  = "0x42b0b77c" as Hex;
const SEL_GUARD_SET_CONST  = "0x5b4f4937" as Hex; // shared by both guards
const SEL_GUARD_GET_GDP    = "0xf4a9e3b1" as Hex; // shared by both guards

// ── GMXGuard selectors (match onchain/stylus/gmx_guard.zig) ──────────────
const SEL_GMX_CREATE_LONG  = "0x2e84a0d6" as Hex;
const SEL_GMX_CREATE_SHORT = "0x8f4c3a91" as Hex;
const SEL_GMX_CANCEL_ORDER = "0x4e2e7a05" as Hex;
const SEL_GMX_MAX_LEVERAGE = "0x9c1a2b3d" as Hex;

// ── Stylus constitution selectors (match onchain/stylus/main.zig) ─────────
const SEL_VALIDATE_SEMANTIC = "0xabcdef01" as Hex;
const SEL_BRIDGE_VERIFY     = "0x3a4b5c6d" as Hex;
const SEL_REGISTER_PEER     = "0x9c0d1e2f" as Hex;
const SEL_SET_CONSTITUTION  = "0x1a2b3c4d" as Hex;
const SEL_GET_CONSTITUTION  = "0x5e6f7a8b" as Hex;

// ── Settlement selectors (match onchain/stylus/settlement.zig) ────────────
const SEL_SETTLE            = "0xd8bff5a5" as Hex;
const SEL_BATCH_SETTLE      = "0x12345678" as Hex;
const SEL_SETTLE_FROM_CHAIN = "0xabcd1234" as Hex;
const SEL_GET_AGENT_GDP     = "0xf4a9e3b1" as Hex;
const SEL_GET_XCHAIN_GDP    = "0xe5b8d2c3" as Hex;

// ── Types ─────────────────────────────────────────────────────────────────
export type IntentVector = readonly number[]; // int32[128]

export interface SemanticCheckResult {
  approved: boolean;
  similarity: number; // 0–10000 (cosine similarity × 10000)
}

export interface BridgeVerifyResult {
  trusted: boolean;
  chainId: XB77ChainId;
  agentId: Hex;
}

// ── ERC-7579 / SmartSessions types ───────────────────────────────────────

export interface EnableSmartSessionOpts {
  /** Biconomy SmartSessions module address on the target chain. */
  smartSessionsModule: Hex;
  /** 32-byte session identifier (keccak256 of session config in SmartSessions). */
  permissionId: Hex;
  /** 128-dim semantic intent vector to enforce on every UserOp within this session. */
  intentVector: IntentVector;
}

export interface SmartSessionEnabledResult {
  hash: Hash;
  permissionId: Hex;
}

// ── ERC-7715 permission types ─────────────────────────────────────────────
export const SEMANTIC_INTENT_PERMISSION_TYPE = "semantic-intent" as const;

export interface SemanticIntentPermissionData {
  intentVector: Hex;     // 512 bytes, int32[128] ABI-packed
  expirySeconds?: number; // default 86400 (24h)
}

export interface GrantPermissionsResult {
  permissionsContext: Hex;
  expiry: number;
  /** Optional wallet-specific routing metadata returned alongside the grant. */
  signerMeta?: {
    userOpBuilder?: Hex;      // ZeroDev / ERC-4337 path
    delegationManager?: Hex;  // MetaMask / ERC-7710 path
  };
}

// ── xB77 cross-chain permission root ─────────────────────────────────────

/** One chain entry in a multi-chain xB77 permission grant. */
export interface CrossChainPermissionEntry {
  /** EVM chain ID (e.g. 421614 for Arbitrum Sepolia) or xB77 chain ID for non-EVM. */
  chainId: number;
  /** The account or guard address on that chain. */
  account: Hex;
}

/**
 * Build a Merkle root over a set of cross-chain permission entries.
 *
 * xB77-specific utility — not part of any ERC standard.
 * Each leaf = keccak256(keccak256(abi.encode(chainId, account))).
 *
 * Compatible with `isBridgeAgentTrusted()` in SovereignPolicy: the Stylus
 * constitution verifies each chain's leaf membership against this root.
 */
export function buildCrossChainRoot(entries: CrossChainPermissionEntry[]): Hex {
  if (entries.length === 0) throw new Error("crossChainRoot: at least one entry required");

  const leaves = entries
    .map((e) => {
      const encoded = encodeAbiParameters(
        [{ type: "uint256" }, { type: "address" }],
        [BigInt(e.chainId), e.account],
      );
      // Double-hash (OpenZeppelin pattern) to prevent second-preimage attacks.
      return keccak256(keccak256(encoded));
    })
    .sort(); // sort for deterministic root regardless of input order

  return _merkleRoot(leaves);
}

function _merkleRoot(leaves: Hex[]): Hex {
  if (leaves.length === 1) return leaves[0];
  const next: Hex[] = [];
  for (let i = 0; i < leaves.length; i += 2) {
    const left  = leaves[i];
    const right = leaves[i + 1] ?? left; // duplicate last leaf for odd count
    // Sort pair so the tree is order-independent at each level.
    const [a, b] = left <= right ? [left, right] : [right, left];
    next.push(keccak256(concatHex([a, b])));
  }
  return _merkleRoot(next);
}

// ── Interest rate modes (Aave v3) ─────────────────────────────────────────
export type AaveRateMode = 1 | 2; // 1 = stable, 2 = variable

export interface AaveSupplyResult {
  hash: Hash;
  asset: Hex;
  amount: bigint;
}

export interface AaveBorrowResult {
  hash: Hash;
  asset: Hex;
  amount: bigint;
  rateMode: AaveRateMode;
}

export interface AaveFlashLoanResult {
  hash: Hash;
  asset: Hex;
  amount: bigint;
}

export interface GMXOrderResult {
  hash: Hash;
  market: Hex;
  sizeUsd: bigint;
  leverageBps: number;
  isLong: boolean;
}

export interface SettleResult {
  hash: Hash;
  amount: bigint;
  commitment: Hex;
}

export interface CrossChainGDP {
  chainId: XB77ChainId;
  agentId: Hex;
  totalSettled: bigint;
}

// ── Intent vector utilities ───────────────────────────────────────────────

/** Safe neutral intent: orthogonal to all-positive toxic vectors. */
export function neutralIntent(): number[] {
  return Array.from({ length: 128 }, (_, i) => (i % 2 === 0 ? 100 : -100));
}

/** Toxic intent: high cosine similarity to the blocked vector. */
export function toxicIntent(): number[] {
  return Array.from({ length: 128 }, () => 10_000);
}

/** Derive a semantic intent vector from a transfer destination and amount. */
export function intentFromTransfer(to: string, amountUsdc: bigint): number[] {
  const suspicious =
    to.includes("toxic") ||
    to.includes("drain") ||
    to.includes("exploit") ||
    amountUsdc > 1_000_000n * 1_000_000n; // > 1M USDC
  return suspicious ? toxicIntent() : neutralIntent();
}

/** Encode a 128-dim intent vector as int32[128] ABI bytes (512 bytes). */
export function encodeIntentVector(vector: IntentVector): Hex {
  if (vector.length !== 128) throw new Error("Intent vector must be 128 dimensions");
  return encodePacked(new Array(128).fill("int32") as "int32"[], vector as number[]);
}

// ── Stylus calldata builders ──────────────────────────────────────────────

function buildValidateSemanticData(vector: IntentVector): Hex {
  return concatHex([SEL_VALIDATE_SEMANTIC, encodeIntentVector(vector)]);
}

function buildBridgeVerifyData(chainId: number, agentId: Hex, proof: Hex): Hex {
  const encoded = encodeAbiParameters(
    [{ type: "uint8" }, { type: "bytes32" }, { type: "bytes32" }],
    [chainId, agentId, proof],
  );
  return concatHex([SEL_BRIDGE_VERIFY, encoded]);
}

function buildRegisterPeerData(chainId: number, peerHash: Hex): Hex {
  const encoded = encodeAbiParameters(
    [{ type: "uint8" }, { type: "bytes32" }],
    [chainId, peerHash],
  );
  return concatHex([SEL_REGISTER_PEER, encoded]);
}

function buildSetConstitutionData(vector: IntentVector): Hex {
  return concatHex([SEL_SET_CONSTITUTION, encodeIntentVector(vector)]);
}

function buildSettleData(amount: bigint, commitment: Hex): Hex {
  const encoded = encodeAbiParameters(
    [{ type: "uint256" }, { type: "bytes32" }],
    [amount, commitment],
  );
  return concatHex([SEL_SETTLE, encoded]);
}

function buildBatchSettleData(amounts: bigint[], commitments: Hex[]): Hex {
  const encoded = encodeAbiParameters(
    [{ type: "uint256[]" }, { type: "bytes32[]" }],
    [amounts, commitments],
  );
  return concatHex([SEL_BATCH_SETTLE, encoded]);
}

function buildSettleFromChainData(
  sourceChain: number,
  agentId: Hex,
  arbitrumAgent: Hex,
  amount: bigint,
  commitment: Hex,
): Hex {
  const encoded = encodeAbiParameters(
    [
      { type: "uint8" },
      { type: "bytes32" },
      { type: "address" },
      { type: "uint256" },
      { type: "bytes32" },
    ],
    [sourceChain, agentId, arbitrumAgent, amount, commitment],
  );
  return concatHex([SEL_SETTLE_FROM_CHAIN, encoded]);
}

// ── Intent-Based Policy for ZeroDev Kernel v3 ─────────────────────────────

/**
 * Creates a ZeroDev Kernel v3 policy that carries the 128-dim intent vector
 * to SovereignPolicy.sol, which validates it on-chain via the Stylus constitution.
 */
export const createSemanticPolicy = (intentVector: IntentVector, policyAddress: Hex): Policy => {
  if (intentVector.length !== 128) throw new Error("Intent vector must be 128 dimensions");

  const encodedVector = encodeIntentVector(intentVector);

  return {
    getPolicyData: () => encodedVector,
    getPolicyInfoInBytes: () => concatHex(["0x0000", policyAddress]),
    policyParams: {
      type: "custom",
      policyAddress,
    } as any,
  } as unknown as Policy;
};

// ── AaveGuard calldata builders ───────────────────────────────────────────

function buildAaveSupplyData(asset: Hex, amount: bigint, onBehalfOf: Hex, referralCode = 0): Hex {
  const encoded = encodeAbiParameters(
    [{ type: "address" }, { type: "uint256" }, { type: "address" }, { type: "uint16" }],
    [asset, amount, onBehalfOf, referralCode],
  );
  return concatHex([SEL_AAVE_SUPPLY, encoded]);
}

function buildAaveBorrowData(
  asset: Hex,
  amount: bigint,
  rateMode: AaveRateMode,
  referralCode = 0,
  onBehalfOf: Hex,
): Hex {
  const encoded = encodeAbiParameters(
    [{ type: "address" }, { type: "uint256" }, { type: "uint256" }, { type: "uint16" }, { type: "address" }],
    [asset, amount, BigInt(rateMode), referralCode, onBehalfOf],
  );
  return concatHex([SEL_AAVE_BORROW, encoded]);
}

function buildAaveRepayData(asset: Hex, amount: bigint, rateMode: AaveRateMode, onBehalfOf: Hex): Hex {
  const encoded = encodeAbiParameters(
    [{ type: "address" }, { type: "uint256" }, { type: "uint256" }, { type: "address" }],
    [asset, amount, BigInt(rateMode), onBehalfOf],
  );
  return concatHex([SEL_AAVE_REPAY, encoded]);
}

function buildAaveWithdrawData(asset: Hex, amount: bigint, to: Hex): Hex {
  const encoded = encodeAbiParameters(
    [{ type: "address" }, { type: "uint256" }, { type: "address" }],
    [asset, amount, to],
  );
  return concatHex([SEL_AAVE_WITHDRAW, encoded]);
}

function buildAaveFlashLoanData(asset: Hex, amount: bigint, params: Hex = "0x"): Hex {
  const encoded = encodeAbiParameters(
    [{ type: "address" }, { type: "uint256" }, { type: "bytes" }],
    [asset, amount, params],
  );
  return concatHex([SEL_AAVE_FLASH_LOAN, encoded]);
}

function buildGuardSetConstitutionData(constitutionAddress: Hex): Hex {
  const encoded = encodeAbiParameters([{ type: "address" }], [constitutionAddress]);
  return concatHex([SEL_GUARD_SET_CONST, encoded]);
}

function buildGuardGetGDPData(agent: Hex): Hex {
  const encoded = encodeAbiParameters([{ type: "address" }], [agent]);
  return concatHex([SEL_GUARD_GET_GDP, encoded]);
}

// ── GMXGuard calldata builders ────────────────────────────────────────────

function buildGMXOrderData(sel: Hex, market: Hex, sizeUsd: bigint, leverageBps: number, nonce: Hex): Hex {
  const encoded = encodeAbiParameters(
    [{ type: "address" }, { type: "uint256" }, { type: "uint256" }, { type: "bytes32" }],
    [market, sizeUsd, BigInt(leverageBps), nonce],
  );
  return concatHex([sel, encoded]);
}

function buildGMXCancelOrderData(orderKey: Hex): Hex {
  const encoded = encodeAbiParameters([{ type: "bytes32" }], [orderKey]);
  return concatHex([SEL_GMX_CANCEL_ORDER, encoded]);
}

// ── AaveGuardClient ───────────────────────────────────────────────────────

/**
 * Client for the xB77 AaveGuard Stylus contract.
 *
 * Every write operation routes through the guard, which validates the agent's
 * semantic intent vector against the on-chain constitution before forwarding
 * to the Aave v3 Pool. GDP is accumulated per-agent on success.
 */
export class AaveGuardClient {
  constructor(
    private publicClient: PublicClient,
    readonly guardAddress: Hex,
  ) {}

  /**
   * Intent vector for a supply action — always neutral (supply is low-risk).
   * Exposed so callers can pre-check before submitting.
   */
  static supplyIntent(): number[] {
    return neutralIntent();
  }

  /**
   * Intent vector for a borrow action.
   * Large (>500k USDC) + variable-rate shifts toward a riskier quadrant.
   * Mirrors `borrowIntent()` in aave_guard.zig.
   */
  static borrowIntent(amount: bigint, rateMode: AaveRateMode): number[] {
    const isLarge    = amount > 500_000n * 1_000_000n;
    const isVariable = rateMode === 2;
    const v = neutralIntent();
    if (isLarge && isVariable) {
      for (let i = 0; i < 32; i++) v[i] = 4_000;
    }
    return v;
  }

  /**
   * Intent vector for a flash loan.
   * Amounts >10M USDC shift toward a suspicious quadrant.
   * Mirrors the intent logic in `handleFlashLoan()` in aave_guard.zig.
   */
  static flashLoanIntent(amount: bigint): number[] {
    const isMassive = amount > 10_000_000n * 1_000_000n;
    const v = neutralIntent();
    if (isMassive) {
      for (let i = 0; i < 64; i++) v[i] = 5_000;
    }
    return v;
  }

  /**
   * Supply an asset to Aave v3 via the guard.
   * The guard validates neutral intent before forwarding to the Aave Pool.
   */
  async supply(
    agentClient: any,
    opts: { asset: Hex; amount: bigint; onBehalfOf: Hex; referralCode?: number },
  ): Promise<AaveSupplyResult> {
    const hash = await agentClient.sendTransaction({
      to: this.guardAddress,
      data: buildAaveSupplyData(opts.asset, opts.amount, opts.onBehalfOf, opts.referralCode),
    });
    return { hash, asset: opts.asset, amount: opts.amount };
  }

  /**
   * Borrow an asset from Aave v3 via the guard.
   * Large variable-rate borrows face a stricter semantic intent check.
   */
  async borrow(
    agentClient: any,
    opts: {
      asset: Hex;
      amount: bigint;
      rateMode: AaveRateMode;
      onBehalfOf: Hex;
      referralCode?: number;
    },
  ): Promise<AaveBorrowResult> {
    const hash = await agentClient.sendTransaction({
      to: this.guardAddress,
      data: buildAaveBorrowData(opts.asset, opts.amount, opts.rateMode, opts.referralCode, opts.onBehalfOf),
    });
    return { hash, asset: opts.asset, amount: opts.amount, rateMode: opts.rateMode };
  }

  /**
   * Repay a debt on Aave v3.
   * No constitution check — repaying is always permitted.
   */
  async repay(
    agentClient: any,
    opts: { asset: Hex; amount: bigint; rateMode: AaveRateMode; onBehalfOf: Hex },
  ): Promise<Hash> {
    return agentClient.sendTransaction({
      to: this.guardAddress,
      data: buildAaveRepayData(opts.asset, opts.amount, opts.rateMode, opts.onBehalfOf),
    });
  }

  /**
   * Withdraw a supplied asset from Aave v3 via the guard.
   * Constitution is checked with neutral intent before withdrawal.
   */
  async withdraw(
    agentClient: any,
    opts: { asset: Hex; amount: bigint; to: Hex },
  ): Promise<Hash> {
    return agentClient.sendTransaction({
      to: this.guardAddress,
      data: buildAaveWithdrawData(opts.asset, opts.amount, opts.to),
    });
  }

  /**
   * Execute a flash loan via the guard.
   * Constitution is validated BEFORE Aave releases the funds.
   * Amounts >10M USDC shift the intent toward a suspicious quadrant.
   */
  async flashLoan(
    agentClient: any,
    opts: { asset: Hex; amount: bigint; params?: Hex },
  ): Promise<AaveFlashLoanResult> {
    const hash = await agentClient.sendTransaction({
      to: this.guardAddress,
      data: buildAaveFlashLoanData(opts.asset, opts.amount, opts.params),
    });
    return { hash, asset: opts.asset, amount: opts.amount };
  }

  /**
   * Set the constitution contract address on the guard.
   * Only the guard's owner (first caller of this function) can call this.
   */
  async setConstitution(agentClient: any, constitutionAddress: Hex): Promise<Hash> {
    return agentClient.sendTransaction({
      to: this.guardAddress,
      data: buildGuardSetConstitutionData(constitutionAddress),
    });
  }

  /**
   * Read total USDC volume accumulated by an agent through this guard.
   * Includes supply and borrow amounts; does not include repay or withdraw.
   */
  async getAgentGDP(agent: Hex): Promise<bigint> {
    const result = await this.publicClient.call({
      to: this.guardAddress,
      data: buildGuardGetGDPData(agent),
    });
    if (!result.data) return 0n;
    const [amount] = decodeAbiParameters([{ type: "uint256" }], result.data);
    return amount as bigint;
  }
}

// ── GMXGuardClient ────────────────────────────────────────────────────────

/**
 * Client for the xB77 GMXGuard Stylus contract.
 *
 * All position creation routes through the guard, which enforces:
 *   1. Hard leverage cap (default 20x, configurable via setConstitution)
 *   2. Hard position size cap (1M USDC)
 *   3. Semantic intent check against the on-chain constitution
 *
 * GDP is accumulated as notional collateral (sizeUsd / leverageBps * 100).
 */
export class GMXGuardClient {
  constructor(
    private publicClient: PublicClient,
    readonly guardAddress: Hex,
  ) {}

  /**
   * Intent vector for a position.
   * Higher leverage and larger size shift toward a riskier (but not toxic) quadrant.
   * Mirrors `positionIntent()` in gmx_guard.zig.
   */
  static positionIntent(sizeUsd: bigint, leverageBps: number, isLong: boolean): number[] {
    const v = neutralIntent();
    const leverageFactor = Math.min(Math.floor(leverageBps / 100), 100);
    const sizeFactor = sizeUsd > 100_000n * 1_000_000n ? 50 : 10;
    for (let i = 0; i < 32; i++) {
      v[i] = isLong
        ? 100 + leverageFactor * sizeFactor
        : -(100 + leverageFactor * sizeFactor);
    }
    return v;
  }

  /**
   * Open a long position on GMX v2 via the guard.
   * Reverts if leverage > maxLeverage or sizeUsd > 1M USDC.
   */
  async createLong(
    agentClient: any,
    opts: { market: Hex; sizeUsd: bigint; leverageBps: number; nonce?: Hex },
  ): Promise<GMXOrderResult> {
    const nonce = opts.nonce ?? pad(toHex(Date.now()), { size: 32 });
    const hash = await agentClient.sendTransaction({
      to: this.guardAddress,
      data: buildGMXOrderData(SEL_GMX_CREATE_LONG, opts.market, opts.sizeUsd, opts.leverageBps, nonce),
    });
    return { hash, market: opts.market, sizeUsd: opts.sizeUsd, leverageBps: opts.leverageBps, isLong: true };
  }

  /**
   * Open a short position on GMX v2 via the guard.
   * Same leverage and size caps as long; constitution intent is negated for shorts.
   */
  async createShort(
    agentClient: any,
    opts: { market: Hex; sizeUsd: bigint; leverageBps: number; nonce?: Hex },
  ): Promise<GMXOrderResult> {
    const nonce = opts.nonce ?? pad(toHex(Date.now()), { size: 32 });
    const hash = await agentClient.sendTransaction({
      to: this.guardAddress,
      data: buildGMXOrderData(SEL_GMX_CREATE_SHORT, opts.market, opts.sizeUsd, opts.leverageBps, nonce),
    });
    return { hash, market: opts.market, sizeUsd: opts.sizeUsd, leverageBps: opts.leverageBps, isLong: false };
  }

  /**
   * Cancel an existing GMX order by key.
   * No constitution check — cancelling is always permitted.
   */
  async cancelOrder(agentClient: any, orderKey: Hex): Promise<Hash> {
    return agentClient.sendTransaction({
      to: this.guardAddress,
      data: buildGMXCancelOrderData(orderKey),
    });
  }

  /**
   * Read the maximum leverage allowed by the constitution (in basis points).
   * Default is 2000 (20x). Returns 0 if the guard is unreachable.
   */
  async getMaxLeverage(): Promise<number> {
    const result = await this.publicClient.call({
      to: this.guardAddress,
      data: SEL_GMX_MAX_LEVERAGE,
    });
    if (!result.data) return 0;
    const [val] = decodeAbiParameters([{ type: "uint256" }], result.data);
    return Number(val as bigint);
  }

  /**
   * Set the constitution contract address on the guard.
   * Only the guard's owner (first caller of this function) can call this.
   */
  async setConstitution(agentClient: any, constitutionAddress: Hex): Promise<Hash> {
    return agentClient.sendTransaction({
      to: this.guardAddress,
      data: buildGuardSetConstitutionData(constitutionAddress),
    });
  }

  /**
   * Read notional collateral volume accumulated by an agent through this guard.
   * Collateral per order = sizeUsd / leverageBps * 100.
   */
  async getAgentGDP(agent: Hex): Promise<bigint> {
    const result = await this.publicClient.call({
      to: this.guardAddress,
      data: buildGuardGetGDPData(agent),
    });
    if (!result.data) return 0n;
    const [amount] = decodeAbiParameters([{ type: "uint256" }], result.data);
    return amount as bigint;
  }
}

// ── ArbitrumAgentAccount ──────────────────────────────────────────────────

export class ArbitrumAgentAccount {
  constructor(
    private publicClient: PublicClient,
    private zerodevProjectId: string,
    private entryPoint: Hex = ARBITRUM_SEPOLIA_ADDRESSES.ENTRY_POINT_V07,
  ) {}

  /**
   * Creates a ZeroDev Kernel v3.1 smart account client with:
   *   - ECDSA session key signer (agent operates without owner's constant presence)
   *   - Semantic policy (intent vector validated on-chain by SovereignPolicy → Stylus)
   *   - ZeroDev paymaster (gas sponsored — agent pays NO ETH)
   */
  async createAgentClient(
    ownerPrivateKey: Hex,
    sessionKeyPrivateKey: Hex,
    policyAddress: Hex,
    intentVector: IntentVector,
  ) {
    const sessionKeySigner = await toECDSASigner({
      signer: privateKeyToAccount(sessionKeyPrivateKey),
    });

    const semanticPolicy = createSemanticPolicy(intentVector, policyAddress);

    const permissionPlugin = await toPermissionValidator(this.publicClient, {
      signer: sessionKeySigner,
      policies: [semanticPolicy],
      entryPoint: this.entryPoint as any,
      kernelVersion: KERNEL_V3_1,
    });

    const kernelAccount = await createKernelAccount(this.publicClient, {
      plugins: { regular: permissionPlugin },
      entryPoint: this.entryPoint as any,
      kernelVersion: KERNEL_V3_1,
    });

    return createKernelAccountClient({
      account: kernelAccount,
      chain: arbitrumSepolia,
      bundlerTransport: http(`https://rpc.zerodev.app/api/v2/bundler/${this.zerodevProjectId}`),
      paymaster: {
        getPaymasterData: async (userOperation: any) => {
          const paymasterClient = createZeroDevPaymasterClient({
            chain: arbitrumSepolia,
            transport: http(`https://rpc.zerodev.app/api/v2/paymaster/${this.zerodevProjectId}`),
          });
          return paymasterClient.sponsorUserOperation({ userOperation });
        },
      },
    });
  }
}

// ── XB77ArbitrumClient — the main integration class ───────────────────────

/**
 * High-level client for xB77 on Arbitrum.
 *
 * Wraps:
 *   - Stylus Constitution (semantic validation, cross-chain bridge registry)
 *   - Stylus Settlement (USDC settlement, cross-chain GDP tracking)
 *   - ZeroDev AA (agent client creation, gas sponsoring)
 *   - ProtocolRegistry (interop with other Arbitrum protocols)
 */
export class XB77ArbitrumClient {
  private agentAccount: ArbitrumAgentAccount;

  /** Aave v3 sovereign guard — available when `aaveGuardAddress` is provided. */
  readonly aaveGuard?: AaveGuardClient;
  /** GMX v2 sovereign guard — available when `gmxGuardAddress` is provided. */
  readonly gmxGuard?: GMXGuardClient;

  constructor(
    private publicClient: PublicClient,
    private constitutionAddress: Hex,
    private settlementAddress: Hex,
    private zerodevProjectId: string,
    private registryAddress?: Hex,
    aaveGuardAddress?: Hex,
    gmxGuardAddress?: Hex,
  ) {
    this.agentAccount = new ArbitrumAgentAccount(publicClient, zerodevProjectId);
    if (aaveGuardAddress) this.aaveGuard = new AaveGuardClient(publicClient, aaveGuardAddress);
    if (gmxGuardAddress)  this.gmxGuard  = new GMXGuardClient(publicClient, gmxGuardAddress);
  }

  static create(opts: {
    constitutionAddress: Hex;
    settlementAddress: Hex;
    zerodevProjectId: string;
    rpcUrl?: string;
    registryAddress?: Hex;
    aaveGuardAddress?: Hex;
    gmxGuardAddress?: Hex;
  }): XB77ArbitrumClient {
    const publicClient = createPublicClient({
      chain: arbitrumSepolia,
      transport: http(opts.rpcUrl ?? "https://sepolia-rollup.arbitrum.io/rpc"),
    }) as PublicClient;

    return new XB77ArbitrumClient(
      publicClient,
      opts.constitutionAddress,
      opts.settlementAddress,
      opts.zerodevProjectId,
      opts.registryAddress,
      opts.aaveGuardAddress,
      opts.gmxGuardAddress,
    );
  }

  // ── ERC-7715 — wallet_grantPermissions ───────────────────────────────────

  /**
   * Request a semantic-intent permission grant from a wallet via ERC-7715.
   *
   * The wallet client must be extended with viem experimental actions:
   *   `walletClient.extend(experimental())` or support `wallet_grantPermissions` natively.
   *
   * The returned `permissionsContext` replaces the flow of building a ZeroDev
   * Kernel client directly — any ERC-7715-compatible wallet can issue the grant
   * without custom xB77 integration.
   */
  async grantPermissions(
    walletClient: any,
    sessionKeyPubkey: Hex,
    intentVector: IntentVector,
    opts?: {
      expiry?: number;
    },
  ): Promise<GrantPermissionsResult> {
    const expiry = opts?.expiry ?? Math.floor(Date.now() / 1000) + 86_400;
    // viem/experimental types model only the built-in ERC-7715 permission types.
    // Custom types ("semantic-intent") and the secp256k1 signer shape are valid
    // per the JSON-RPC spec but require a cast here.
    const result = await viemGrantPermissions(walletClient, {
      chainId: toHex(421614), // Arbitrum Sepolia — required field per ERC-7715 spec
      expiry,
      signer: { type: "key", data: { type: "secp256k1", publicKey: sessionKeyPubkey } },
      permissions: [{
        type: { custom: SEMANTIC_INTENT_PERMISSION_TYPE },
        data: { intentVector: encodeIntentVector(intentVector) } satisfies SemanticIntentPermissionData,
      }],
    } as any);
    return {
      permissionsContext: result.permissionsContext as Hex,
      expiry: result.expiry,
      ...(result.signerMeta ? { signerMeta: result.signerMeta } : {}),
    };
  }

  // ── ERC-7579 SmartSessions ────────────────────────────────────────────────

  /**
   * Enable an xB77 semantic session on a Biconomy SmartSessions-powered account.
   *
   * Calls `SovereignSessionValidator.enableSession(account, permissionId, enableData)`
   * where `enableData = abi.encode(encodeIntentVector(intentVector))`.
   *
   * Prerequisites:
   *   1. The account must have the SmartSessions module (ERC-7579) installed.
   *   2. `opts.validatorAddress` must be a deployed `SovereignSessionValidator`.
   *   3. The `agentClient` must be authorized to call the validator on behalf of the account.
   */
  async enableSmartSession(
    agentClient: Awaited<ReturnType<typeof this.createAgentClient>>,
    validatorAddress: Hex,
    opts: EnableSmartSessionOpts,
  ): Promise<SmartSessionEnabledResult> {
    const encodedVector = encodeIntentVector(opts.intentVector);

    // enableSession(address account, bytes32 permissionId, bytes enableData)
    const encoded = encodeAbiParameters(
      [
        { type: "address" },
        { type: "bytes32" },
        { type: "bytes" },
      ],
      [
        opts.smartSessionsModule,
        opts.permissionId,
        encodeAbiParameters([{ type: "bytes" }], [encodedVector]),
      ],
    );

    // selector = keccak256("enableSession(address,bytes32,bytes)")[0:4]
    const sel = "0x9ee16db3" as Hex; // pre-computed
    const hash = await agentClient.sendTransaction({
      to: validatorAddress,
      data: concatHex([sel, encoded]),
    });

    return { hash, permissionId: opts.permissionId };
  }

  // ── Agent account ────────────────────────────────────────────────────────

  async createAgentClient(
    ownerPrivateKey: Hex,
    sessionKeyPrivateKey: Hex,
    intentVector: IntentVector,
  ) {
    return this.agentAccount.createAgentClient(
      ownerPrivateKey,
      sessionKeyPrivateKey,
      this.constitutionAddress,
      intentVector,
    );
  }

  // ── Stylus constitution — read ────────────────────────────────────────────

  /** Check an agent's intent vector against the on-chain Stylus constitution. */
  async checkConstitution(intentVector: IntentVector): Promise<SemanticCheckResult> {
    const data = buildValidateSemanticData(intentVector);
    const result = await this.publicClient.call({
      to: this.constitutionAddress,
      data,
    });

    const approved =
      result.data !== undefined &&
      result.data.length >= 66 &&
      result.data[result.data.length - 1] === "1"[0];

    // Compute similarity locally (mirrors Zig cosine similarity logic)
    const similarity = cosineSimilarityFixed(
      intentVector as number[],
      new Array(128).fill(10_000),
    );

    return { approved, similarity };
  }

  /** Get the current constitution vector stored on-chain. */
  async getConstitution(): Promise<number[]> {
    const result = await this.publicClient.call({
      to: this.constitutionAddress,
      data: SEL_GET_CONSTITUTION,
    });
    if (!result.data || result.data.length < 2 + 512 * 2) return neutralIntent();

    const raw = result.data.slice(2); // strip 0x
    return Array.from({ length: 128 }, (_, i) => {
      const chunk = raw.slice(i * 8, i * 8 + 8);
      const val = parseInt(chunk, 16);
      // Convert unsigned to signed int32
      return val > 0x7fffffff ? val - 0x100000000 : val;
    });
  }

  // ── Stylus constitution — write (via agent client) ────────────────────────

  /**
   * Set the agent's constitution on-chain.
   * Must be called by the admin (deployer) of the Stylus contract.
   */
  async setConstitution(
    agentClient: Awaited<ReturnType<typeof this.createAgentClient>>,
    blockedVector: IntentVector,
  ): Promise<Hash> {
    return agentClient.sendTransaction({
      to: this.constitutionAddress,
      data: buildSetConstitutionData(blockedVector),
    });
  }

  // ── Cross-chain bridge ────────────────────────────────────────────────────

  /**
   * Register a trusted peer from another chain on the Stylus constitution.
   *
   * @param chainId    xB77 chain ID (XB77_CHAIN.SOLANA, etc.)
   * @param peerHash   keccak256(programId) for Solana | objectId hash for Sui | address for Arc
   */
  async registerPeer(
    agentClient: Awaited<ReturnType<typeof this.createAgentClient>>,
    chainId: XB77ChainId,
    peerHash: Hex,
  ): Promise<Hash> {
    return agentClient.sendTransaction({
      to: this.constitutionAddress,
      data: buildRegisterPeerData(chainId, peerHash),
    });
  }

  /**
   * Verify that a cross-chain agent is trusted on the Stylus constitution.
   *
   * @param chainId  Source chain (XB77_CHAIN.SOLANA | SUI | ARC)
   * @param agentId  Chain-specific agent ID (pubkey hash for Solana, object ID for Sui)
   * @param proof    Ghost receipt hash or PTB digest from the source chain
   */
  async bridgeVerify(
    chainId: XB77ChainId,
    agentId: Hex,
    proof: Hex,
  ): Promise<BridgeVerifyResult> {
    const data = buildBridgeVerifyData(chainId, agentId, proof);
    const result = await this.publicClient.call({
      to: this.constitutionAddress,
      data,
    });

    const trusted =
      result.data !== undefined &&
      result.data.length >= 66 &&
      result.data[result.data.length - 1] === "1"[0];

    return { trusted, chainId, agentId };
  }

  /**
   * Derive the agentId for a Solana agent: keccak256 of the Ed25519 pubkey bytes.
   * Use this to register or verify Solana agents on Arbitrum.
   */
  static solanaAgentId(pubkeyBytes: Uint8Array): Hex {
    return keccak256(pubkeyBytes);
  }

  /**
   * Derive the agentId for a Sui agent: keccak256 of the object ID bytes.
   */
  static suiAgentId(objectIdHex: Hex): Hex {
    return keccak256(objectIdHex);
  }

  // ── Settlement ────────────────────────────────────────────────────────────

  /**
   * Settle a completed mission in USDC.
   * Gas is sponsored by the ZeroDev paymaster — agent pays NO ETH.
   */
  async settle(
    agentClient: Awaited<ReturnType<typeof this.createAgentClient>>,
    amountUsdc: bigint,
    commitment: Hex,
  ): Promise<SettleResult> {
    const hash = await agentClient.sendTransaction({
      to: this.settlementAddress,
      data: buildSettleData(amountUsdc, commitment),
    });
    return { hash, amount: amountUsdc, commitment };
  }

  /**
   * Batch settle multiple missions in a single transaction.
   * Gas-efficient: one UserOp for N settlements.
   */
  async batchSettle(
    agentClient: Awaited<ReturnType<typeof this.createAgentClient>>,
    settlements: Array<{ amount: bigint; commitment: Hex }>,
  ): Promise<Hash> {
    const amounts = settlements.map((s) => s.amount);
    const commitments = settlements.map((s) => s.commitment);
    return agentClient.sendTransaction({
      to: this.settlementAddress,
      data: buildBatchSettleData(amounts, commitments),
    });
  }

  /**
   * Settle on behalf of an agent from Solana, Sui, or Arc.
   * The caller must hold USDC and have approved the Settlement contract.
   */
  async settleFromChain(
    agentClient: Awaited<ReturnType<typeof this.createAgentClient>>,
    opts: {
      sourceChain: XB77ChainId;
      agentId: Hex;
      arbitrumAgent: Hex;
      amount: bigint;
      commitment: Hex;
    },
  ): Promise<SettleResult> {
    const hash = await agentClient.sendTransaction({
      to: this.settlementAddress,
      data: buildSettleFromChainData(
        opts.sourceChain,
        opts.agentId,
        opts.arbitrumAgent,
        opts.amount,
        opts.commitment,
      ),
    });
    return { hash, amount: opts.amount, commitment: opts.commitment };
  }

  // ── GDP queries ───────────────────────────────────────────────────────────

  /** Total USDC settled by an Arbitrum agent across all sessions. */
  async getAgentGDP(agent: Hex): Promise<bigint> {
    const encoded = encodeAbiParameters([{ type: "address" }], [agent]);
    const data = concatHex([SEL_GET_AGENT_GDP, encoded]);
    const result = await this.publicClient.call({ to: this.settlementAddress, data });
    if (!result.data) return 0n;
    const [amount] = decodeAbiParameters([{ type: "uint256" }], result.data);
    return amount as bigint;
  }

  /** Total USDC settled by a chain-native agent (Solana/Sui/Arc) on Arbitrum. */
  async getCrossChainGDP(chainId: XB77ChainId, agentId: Hex): Promise<CrossChainGDP> {
    const encoded = encodeAbiParameters(
      [{ type: "uint8" }, { type: "bytes32" }],
      [chainId, agentId],
    );
    const data = concatHex([SEL_GET_XCHAIN_GDP, encoded]);
    const result = await this.publicClient.call({ to: this.settlementAddress, data });
    const totalSettled = result.data
      ? (decodeAbiParameters([{ type: "uint256" }], result.data)[0] as bigint)
      : 0n;
    return { chainId, agentId, totalSettled };
  }

  // ── Protocol registry interop ─────────────────────────────────────────────

  /**
   * Forward an agent action to a registered Arbitrum protocol via ProtocolRegistry.
   * The registry validates the agent's constitution and capability before forwarding.
   */
  async forwardToProtocol(
    agentClient: Awaited<ReturnType<typeof this.createAgentClient>>,
    opts: {
      protocol: Hex;
      intentVector: IntentVector;
      capability: bigint;
      actionData: Hex;
    },
  ): Promise<Hash> {
    if (!this.registryAddress) throw new Error("registryAddress not configured");

    // forwardAgentAction(address protocol, bytes intentVector, uint256 capability, bytes actionData)
    const encoded = encodeAbiParameters(
      [
        { type: "address" },
        { type: "bytes" },
        { type: "uint256" },
        { type: "bytes" },
      ],
      [opts.protocol, encodeIntentVector(opts.intentVector), opts.capability, opts.actionData],
    );
    // selector = keccak256("forwardAgentAction(address,bytes,uint256,bytes)")[0:4]
    const sel = "0x8f4b45a2" as Hex; // pre-computed
    return agentClient.sendTransaction({
      to: this.registryAddress,
      data: concatHex([sel, encoded]),
    });
  }
}

// ── Math helpers ──────────────────────────────────────────────────────────

function dotFixed(a: number[], b: number[]): number {
  let sum = 0;
  for (let i = 0; i < 128; i++) sum += a[i] * b[i];
  return sum;
}

function normFixed(a: number[]): number {
  let sum = 0;
  for (let i = 0; i < 128; i++) sum += a[i] * a[i];
  return Math.sqrt(sum);
}

/** Cosine similarity × 10000 (mirrors Zig Semantic.cosineSimilarityFixed). */
export function cosineSimilarityFixed(a: number[], b: number[]): number {
  const d = dotFixed(a, b);
  const na = normFixed(a);
  const nb = normFixed(b);
  if (na === 0 || nb === 0) return 0;
  return Math.round((d * 10_000) / (na * nb));
}
