import { 
  getAddressEncoder, 
  getProgramDerivedAddress 
} from "@solana/kit";

const NAME_PROGRAM_ID = "namesLPneUptT9mwwHSEiXreK7i3uWz9GZCDD62TVJ";
const ROOT_DOMAIN_ACCOUNT = "58PwtjSDuFHuUkYjH9BYnnQKHfwo9reZhC2zMJv9JPkx";

const hashedName = Buffer.from("8ee2d25c3d2b2a83a1fc209b90377aed03dc2539e8e238355edda8d1b2edab98", "hex");
const nameClass = Buffer.alloc(32);
const nameParent = getAddressEncoder().encode(ROOT_DOMAIN_ACCOUNT);

async function run() {
    try {
        const [pda] = await getProgramDerivedAddress({
            programId: NAME_PROGRAM_ID,
            seeds: [hashedName, nameClass, nameParent]
        });
        console.log("RESULT_PDA:", pda);
    } catch (e) {
        console.log("ERROR:", e);
    }
}
run();
