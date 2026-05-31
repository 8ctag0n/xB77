module sovereign::policy {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;

    struct AdminCap has key, store {
        id: UID,
    }

    struct Policy has key, store {
        id: UID,
        withdrawal_limit: u64,
    }

    fun init(ctx: &mut TxContext) {
        let admin_cap = AdminCap {
            id: object::new(ctx),
        };
        transfer::transfer(admin_cap, tx_context::sender(ctx));
    }

    public fun create_policy(_cap: &AdminCap, limit: u64, ctx: &mut TxContext): Policy {
        Policy {
            id: object::new(ctx),
            withdrawal_limit: limit,
        }
    }

    public fun limit(policy: &Policy): u64 {
        policy.withdrawal_limit
    }
}
