const { PublicKey } = require("@solana/web3.js");
const bs58 = require("bs58");
const decode = bs58.decode || bs58.default.decode;

// This is the string from the original script
const str = "namesLPneUptT9mwwHSEiXreK7i3uWz9GZCDD62TVJ";
try {
    const decoded = decode(str);
    console.log("Length:", decoded.length);
    // If length is 31, pad with a leading zero
    let bytes = decoded;
    if (decoded.length === 31) {
        bytes = Buffer.concat([Buffer.alloc(1), decoded]);
    }
    const pk = new PublicKey(bytes);
    console.log("Valid Pubkey:", pk.toBase58());
} catch (e) {
    console.log("Error:", e.message);
}
