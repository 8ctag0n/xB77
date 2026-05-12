const { PublicKey } = require("@solana/web3.js");
const { createHash } = require("crypto");

const NAME_PROGRAM_ID = new PublicKey("namesLPneUptT9mwwHSEiXreK7i3uWz9GZCDD62TVJ");
const ROOT_DOMAIN_ACCOUNT = new PublicKey("58PwtjSDuFHuUkYjH9BYnnQKHfwo9reZhC2zMJv9JPkx");

function getHashedName(name) {
    const input = "SPL Name Service" + name;
    return createHash("sha256").update(input).digest();
}

const domain = "bonfida";
const hashedName = getHashedName(domain);

const [address, bump] = PublicKey.findProgramAddressSync(
    [hashedName, Buffer.alloc(32), ROOT_DOMAIN_ACCOUNT.toBuffer()],
    NAME_PROGRAM_ID
);

console.log("Registry PDA (base58):", address.toBase58());
console.log("Bump:", bump);
