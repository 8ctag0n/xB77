import { buildPoseidon } from "circomlibjs";

async function main() {
    const poseidon = await buildPoseidon();
    const args = process.argv.slice(2);
    
    if (args.length === 0) {
        console.error("Usage: bun scripts/poseidon_helper.ts <input1> <input2> ...");
        process.exit(1);
    }

    const inputs = args.map(x => BigInt(x));
    const hash = poseidon(inputs);
    console.log(poseidon.F.toString(hash));
}

main().catch(console.error);
