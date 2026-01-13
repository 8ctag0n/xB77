import { BarretenbergBackend } from '@noir-lang/backend_barretenberg';
import { Noir } from '@noir-lang/noir_js';
import badgeCircuit from './src/artifacts/agent_badge.json';
import { buildPoseidonReference } from 'circomlibjs';

// Explicitly import and initialize WASM if needed
import initACVM from '@noir-lang/acvm_js';
import initNoircAbi from '@noir-lang/noirc_abi';

async function main() {
    console.log("Initializing Ghost Badge System...");

    try {
        // Initialize WASM modules
        await initACVM();
        await initNoircAbi();
    } catch (e) {
        // Some versions might not need explicit init or might fail in specific ways
        // but we try it for stability.
    }

    // 1. Setup Noir & Backend
    // @ts-ignore
    const backend = new BarretenbergBackend(badgeCircuit, {
        threads: 1,
        crsPath: "./.bb-crs",
    });
    // @ts-ignore
    const noir = new Noir(badgeCircuit);

    console.log("Generating Proof Inputs...");

    const poseidon = await buildPoseidonReference();
    const field = poseidon.F;
    const depth = 3;

    const buildInput = (
        secret: bigint,
        salt: bigint,
        path: bigint[],
        merkleIndex: bigint
    ) => {
        let current = poseidon([secret, salt]);

        for (let i = 0; i < depth; i += 1) {
            const bit = (merkleIndex >> BigInt(i)) & 1n;
            const sibling = path[i];
            current = bit === 0n ? poseidon([current, sibling]) : poseidon([sibling, current]);
        }

        return {
            root: field.toString(current),
            agent_secret: secret.toString(),
            agent_salt: salt.toString(),
            merkle_path: path.map((value) => value.toString()),
            merkle_index: merkleIndex.toString(),
        };
    };

    const inputs = [
        buildInput(5n, 99n, [10n, 20n, 30n], 0n),
        buildInput(7n, 123n, [3n, 11n, 19n], 5n),
    ];

    for (const [index, input] of inputs.entries()) {
        console.log(`Generating Witness (${index + 1}/${inputs.length})...`);
        try {
            const { witness } = await noir.execute(input);
            console.log("Witness Generated.");
            
            console.log("Generating Proof...");
            const proof = await backend.generateProof(witness);
            console.log("Proof Generated successfully.");
            console.log("Proof bytes:", proof.proof.slice(0, 32), "...");
            
            console.log("Verifying Proof...");
            const isValid = await backend.verifyProof(proof);
            console.log("Result:", isValid ? "VALID" : "INVALID");
        } catch (e) {
            console.error("Proof/Witness Generation Failed:", e);
            // console.log(e);
        }
    }
}

main();
