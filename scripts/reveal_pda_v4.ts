import { 
  getProgramDerivedAddress,
  getAddressEncoder
} from "@solana/kit";
import { createHash } from "crypto";
import bs58 from "bs58";

// The 31-byte program ID needs a leading zero to be a valid 32-byte address for @solana/kit
const rawId = bs58.decode("namesLPneUptT9mwwHSEiXreK7i3uWz9GZCDD62TVJ");
const programIdBytes = new Uint8Array(32);
programIdBytes.set(rawId, 32 - rawId.length);
const programId = getAddressEncoder().decode(programIdBytes);

const rawParent = bs58.decode("58PwtjSDuFHuUkYjH9BYnnQKHfwo9reZhC2zMJv9JPkx");
const parentBytes = new Uint8Array(32);
parentBytes.set(rawParent, 32 - rawParent.length);
const parentAddress = getAddressEncoder().decode(parentBytes);

const hashedName = createHash("sha256").update("SPL Name Service" + "bonfida").digest();
const nameClass = new Uint8Array(32);

async function run() {
    try {
        const [pda] = await getProgramDerivedAddress({
            programId,
            seeds: [hashedName, nameClass, parentAddress]
        });
        console.log("RESULT_PDA:", pda);
    } catch (e) {
        console.log("ERROR:", e);
    }
}
run();
