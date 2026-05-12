import { 
  getAddressEncoder, 
  getProgramDerivedAddress 
} from "@solana/kit";
import { createHash } from "crypto";

// SNS Program ID (v2 format)
const NAME_PROGRAM_ID = "namesLPneUptT9mwwHSEiXreK7i3uWz9GZCDD62TVJ";
const SOL_TLD_REGISTRY = "58PwtjSDuFHuUkYjH9BYnnQKHfwo9reZhC2zMJv9JPkx";

function getHashedName(name: string) {
    const input = "SPL Name Service" + name;
    return createHash("sha256").update(input).digest();
}

const domain = "bonfida";
const hashedName = getHashedName(domain);

console.log("Hashed Name (hex):", hashedName.toString("hex"));

// En @solana/kit v2, derivamos manualmente para SNS porque no usa bump
const addressEncoder = getAddressEncoder();

// Replicamos la lógica de SNS: [hashed_name, class (32 zeros), parent]
// Nota: SNS usa createProgramAddress, NO findProgramAddress (no hay bump al final)
// Pero para el test, vamos a ver qué nos da el calculador de PDA.
async function run() {
    console.log("SNS Program ID:", NAME_PROGRAM_ID);
    console.log("SOL TLD Registry:", SOL_TLD_REGISTRY);
}

run();
