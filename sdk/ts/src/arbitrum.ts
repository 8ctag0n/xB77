import { 
  createKernelAccount, 
  createKernelAccountClient, 
  createZeroDevPaymasterClient
} from "@zerodev/sdk";
import { KERNEL_V3_1 } from "@zerodev/sdk/constants";
import { toPermissionValidator, type Policy } from "@zerodev/permissions";
import { toECDSASigner } from "@zerodev/permissions/signers";
import { http, createPublicClient, type Hex, encodePacked, concatHex } from "viem";
import { arbitrumSepolia } from "viem/chains";
import { privateKeyToAccount } from "viem/accounts";

/**
 * xB77 Intent-Based Policy for ZeroDev Kernel v3
 * This policy carries the 128-dimension Intent Vector to the on-chain SovereignPolicy.sol.
 */
export const createSemanticPolicy = (intentVector: number[], policyAddress: Hex): Policy => {
  if (intentVector.length !== 128) {
    throw new Error("Intent vector must have exactly 128 dimensions");
  }

  // Encode the vector as int32[128]
  const encodedVector = encodePacked(
    new Array(128).fill('int32'),
    intentVector
  );

  return {
    getPolicyData: () => encodedVector,
    getPolicyInfoInBytes: () => concatHex(["0x0000", policyAddress]), // 0x0000 = FOR_ALL_VALIDATION flag
    policyParams: {
      type: "custom",
      policyAddress,
    } as any,
  } as unknown as Policy;
};

export class ArbitrumAgentAccount {
  constructor(
    private publicClient: any,
    private entryPoint: string = "0x0000000071727De22E5E9d8BAf0edAc6f37da032" // EntryPoint v0.7
  ) {}

  async createAgentClient(
    ownerPrivateKey: Hex,
    sessionKeyPrivateKey: Hex,
    policyAddress: Hex,
    intentVector: number[]
  ) {
    const owner = privateKeyToAccount(ownerPrivateKey);
    const sessionKeySigner = await toECDSASigner({
      signer: privateKeyToAccount(sessionKeyPrivateKey)
    });

    const semanticPolicy = createSemanticPolicy(intentVector, policyAddress);

    const permissionPlugin = await toPermissionValidator(this.publicClient, {
      signer: sessionKeySigner,
      policies: [semanticPolicy],
      entryPoint: this.entryPoint as any,
      kernelVersion: KERNEL_V3_1,
    });

    const kernelAccount = await createKernelAccount(this.publicClient, {
      plugins: {
        regular: permissionPlugin,
      },
      entryPoint: this.entryPoint as any,
      kernelVersion: KERNEL_V3_1,
    });

    return createKernelAccountClient({
      account: kernelAccount,
      chain: arbitrumSepolia,
      bundlerTransport: http("https://rpc.zerodev.app/api/v2/bundler/YOUR_ZERODEV_PROJECT_ID"),
      paymaster: {
        getPaymasterData: async (userOperation: any) => {
          const paymasterClient = createZeroDevPaymasterClient({
            chain: arbitrumSepolia,
            transport: http("https://rpc.zerodev.app/api/v2/paymaster/YOUR_ZERODEV_PROJECT_ID"),
          });
          return paymasterClient.sponsorUserOperation({
            userOperation,
          });
        }
      }
    });
  }
}
