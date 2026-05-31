const fs = require('fs');

async function run() {
    const wasmBuffer = fs.readFileSync('zig-out/bin/constitution.wasm');
    const intent_text = process.argv[2] || "safe action";

    const imports = {
        vm_hooks: {
            read_args: (destPtr) => {
                // Return a mock vector based on intent_text
                const mem = new Uint8Array(instance.exports.memory.buffer);
                const selector = Buffer.from([0xab, 0xcd, 0xef, 0x01]);
                const vectorBuf = Buffer.alloc(128 * 4);
                
                const is_toxic = intent_text.includes('toxic');
                for (let i = 0; i < 128; i++) {
                    // Toxic vector is uniform positive [1000, 1000...]
                    // Safe vector is alternating [100, -100, 100, -100...] so dot product is 0
                    let val = is_toxic ? 1000 : (i % 2 === 0 ? 100 : -100);
                    vectorBuf.writeInt32BE(val, i * 4);
                }
                const calldata = Buffer.concat([selector, vectorBuf]);
                mem.set(calldata, destPtr);
            },
            write_result: (ptr, len) => {},
            exit_early: (status) => { process.exit(status); },
            storage_load_bytes32: (keyPtr, destPtr) => {
                const mem = new Uint8Array(instance.exports.memory.buffer);
                mem.set(new Uint8Array(32).fill(0), destPtr);
            },
            storage_cache_bytes32: () => {},
            storage_flush_cache: () => {},
            emit_log: () => {},
            static_call_contract: () => 0,
            return_data_size: () => 0,
            read_return_data: () => {},
            msg_sender: (ptr) => {},
            msg_value: (ptr) => {},
            block_timestamp: () => 0n,
            block_number: () => 0n,
            chainid: () => 0n,
            native_keccak256: (dataPtr, len, destPtr) => {}
        }
    };

    const { instance } = await WebAssembly.instantiate(wasmBuffer, imports);
    const result = instance.exports.user_entrypoint(516); // 4 + 512
    process.exit(result);
}

run().catch(() => process.exit(1));
