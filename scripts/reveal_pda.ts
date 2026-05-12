import { Connection, PublicKey } from "@solana/web3.js";
import { getDomainKeySync } from "@bonfida/spl-name-service";

const domain = "bonfida";
const { pubkey } = getDomainKeySync(domain);

console.log("REAL_SNS_PDA:", pubkey.toBase58());
