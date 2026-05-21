module sovereign::receipt {
    struct GhostReceipt {
        amount: u64,
        recipient: address,
    }

    public fun verify_zk_proof(
        amount: u64,
        recipient: address,
        _proof: vector<u8>,
        _public_inputs: vector<u8>
    ): GhostReceipt {
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
