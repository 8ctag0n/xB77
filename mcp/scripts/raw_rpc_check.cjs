const dotenv = require('dotenv');

dotenv.config();
const HELIUS_KEY = process.env.HELIUS_KEY;
if (!HELIUS_KEY) {
    throw new Error('Missing HELIUS_KEY in environment');
}
const RPC_URL = "https://devnet.helius-rpc.com/?api-key=" + HELIUS_KEY;

const TREE_ADDRESS = "amt2kaJA14v3urZbZvnc5v2np8jqvc4Z8zDep5wbtzx";
const QUEUE_ADDRESS = "aq1S9z4reTSQAdgWHGD2zDaS39sjGrAxbR31vxJ2F4F";
const DERIVED_ADDRESS = "12PtFq7YtaM7dQFeU4TAzrY8gPvBk9j6NnhGcNUgXAYx";

async function main() {
    const payload = {
        jsonrpc: "2.0",
        id: "test",
        method: "getValidityProof",
        params: [
            [], // compressed proofs
            [ DERIVED_ADDRESS ] // Just the address strings for new addresses? Or same format?
        ]
    };

    console.log("Fetching validity proof from Helius (V2 style)...");
    const res = await fetch(RPC_URL, {
        method: "POST",
        body: JSON.stringify(payload),
        headers: { "Content-Type": "application/json" }
    });
    const json = await res.json();
    console.log(JSON.stringify(json, null, 2));
}

main();
