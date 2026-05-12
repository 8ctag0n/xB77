import { 
  address,
  getProgramDerivedAddress 
} from "@solana/kit";

const NAME_PROGRAM_ID = address("namesLPneUptT9mwwHSEiXreK7i3uWz9GZCDD62TVJ");
const ROOT_DOMAIN_ACCOUNT = address("58PwtjSDuFHuUkYjH9BYnnQKHfwo9reZhC2zMJv9JPkx");

const hashedName = Buffer.from("8ee2d25c3d2b2a83a1fc209b90377aed03dc2539e8e238355edda8d1b2edab98", "hex");
const nameClass = Buffer.alloc(32);
const nameParent = Buffer.from(address(ROOT_DOMAIN_ACCOUNT)); // This is likely the issue, @solana/kit uses Uint8Array

async function run() {
    try {
        const [pda] = await getProgramDerivedAddress({
            programId: NAME_PROGRAM_ID,
            seeds: [hashedName, nameClass, ROOT_DOMAIN_ACCOUNT]
        });
        console.log("RESULT_PDA:", pda);
    } catch (e) {
        console.log("ERROR:", e);
    }
}
run();
