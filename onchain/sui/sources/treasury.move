module sovereign::treasury {
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::TxContext;
    use sui::balance::{Self, Balance};
    use sovereign::policy::{Self, Policy};
    use sovereign::receipt::{Self, GhostReceipt};

    struct OwnedTreasury has key, store {
        id: UID,
        balance: Balance<SUI>,
    }

    const EAmountExceedsLimit: u64 = 0;

    public fun new_treasury(ctx: &mut TxContext): OwnedTreasury {
        OwnedTreasury {
            id: object::new(ctx),
            balance: balance::zero<SUI>(),
        }
    }

    public fun deposit(treasury: &mut OwnedTreasury, coin: Coin<SUI>) {
        balance::join(&mut treasury.balance, coin::into_balance(coin));
    }

    public fun withdraw_with_receipt(
        treasury: &mut OwnedTreasury,
        policy: &Policy,
        receipt: GhostReceipt,
        ctx: &mut TxContext
    ): Coin<SUI> {
        let (amount, _recipient) = receipt::consume(receipt);
        
        assert!(amount <= policy::limit(policy), EAmountExceedsLimit);

        let withdrawn = balance::split(&mut treasury.balance, amount);
        coin::from_balance(withdrawn, ctx)
    }

    public fun execute_withdrawal(
        treasury: &mut OwnedTreasury,
        policy: &Policy,
        amount: u64,
        recipient: address,
        proof: vector<u8>,
        public_inputs: vector<u8>,
        ctx: &mut TxContext
    ) {
        let receipt = receipt::verify_zk_proof(amount, recipient, proof, public_inputs);
        let coin = withdraw_with_receipt(treasury, policy, receipt, ctx);
        transfer::public_transfer(coin, recipient);
    }
}
