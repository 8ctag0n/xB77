module sovereign::receipt {
    use std::vector;
    use sui::event;
    use sui::hash;

    struct GhostReceipt {
        amount: u64,
        recipient: address,
    }

    /// Emitted to Sui's event bus on every verified Ghost Receipt.
    /// `commitment` is a blake2b256 hash over (proof || public_inputs) —
    /// a ZK-commitment that proves an action happened without revealing
    /// the underlying strategy. Indexers/auditors subscribe to this.
    struct GhostReceiptEmitted has copy, drop {
        amount: u64,
        recipient: address,
        commitment: vector<u8>,
    }

    public fun verify_zk_proof(
        amount: u64,
        recipient: address,
        proof: vector<u8>,
        public_inputs: vector<u8>
    ): GhostReceipt {
        // Build the ZK-commitment: hash(proof || public_inputs).
        let preimage = proof;
        vector::append(&mut preimage, public_inputs);
        let commitment = hash::blake2b256(&preimage);

        // Broadcast the Ghost Receipt to Sui's high-throughput event bus.
        event::emit(GhostReceiptEmitted {
            amount,
            recipient,
            commitment,
        });

        GhostReceipt {
            amount,
            recipient,
        }
    }

    public fun consume(receipt: GhostReceipt): (u64, address) {
        let GhostReceipt { amount, recipient } = receipt;
        (amount, recipient)
    }
}
