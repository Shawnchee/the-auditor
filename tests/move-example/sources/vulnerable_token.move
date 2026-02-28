/// ⚠️  THIS MODULE IS INTENTIONALLY VULNERABLE — for testing PR Auditor only.
///    DO NOT deploy on Aptos mainnet.
///
/// Critical Vulnerabilities:
///   1. Unrestricted minting — anyone can print unlimited tokens (CRITICAL)
///   2. Admin private key hardcoded in module constant (CRITICAL)
///   3. Reentrancy-equivalent: state not updated before cross-module call (CRITICAL)
///   4. Integer overflow in transfer — no checked arithmetic (HIGH)
///   5. No capability check on burn — anyone can burn other users' tokens (CRITICAL)
///   6. Flash loan attack surface — borrow without collateral check (CRITICAL)
///   7. Missing signer check — accepting any address as "authorized" (HIGH)

module vulnerable_token::token {
    use std::signer;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;

    // ❌ CRITICAL 1: Hardcoded admin key in source — anyone can read it
    const ADMIN_PRIVATE_KEY: vector<u8> = b"5KJvsngHeMpm884wtkJNzQGaCErckhHJBGFsvd3VyK5qMZXj3hS";
    const MAX_UINT64: u64 = 18446744073709551615;

    struct TokenStore has key {
        balance: u64,
        debt: u64,       // for flash loans
        is_frozen: bool,
    }

    struct MintCapability has key {
        total_supply: u64,
    }

    struct FlashLoan has key {
        active: bool,
        amount: u64,
    }

    // ❌ CRITICAL 2: No access control — ANY account can call initialize and get MintCapability
    public entry fun initialize(account: &signer) {
        move_to(account, MintCapability { total_supply: 0 });
        move_to(account, FlashLoan { active: false, amount: 0 });
    }

    // ❌ CRITICAL 3: Unrestricted minting — no cap, no auth check at all
    public entry fun mint(
        _admin: &signer,   // signer is accepted but NEVER validated!
        recipient: address,
        amount: u64
    ) acquires TokenStore, MintCapability {
        // Anyone can call this and mint unlimited tokens for any address
        if (!exists<TokenStore>(recipient)) {
            // Can't move_to without recipient's signer — logic error will panic
            abort 100
        };

        let store = borrow_global_mut<TokenStore>(recipient);
        // ❌ CRITICAL 4: Unchecked overflow — wraps silently in Move
        store.balance = store.balance + amount;

        // Update supply without checking who approved this
        if (exists<MintCapability>(@vulnerable_token)) {
            let cap = borrow_global_mut<MintCapability>(@vulnerable_token);
            cap.total_supply = cap.total_supply + amount;
        };
        // ❌ No event emitted — can't track supply inflation off-chain
    }

    // ❌ CRITICAL 5: Anyone can burn ANY user's tokens — no owner check
    public entry fun burn(
        _caller: &signer,  // caller is NEVER matched against the account being burned!
        victim: address,
        amount: u64
    ) acquires TokenStore, MintCapability {
        let store = borrow_global_mut<TokenStore>(victim);
        // Subtracting without checking caller == victim
        store.balance = store.balance - amount; // aborts on underflow but still dangerous
        if (exists<MintCapability>(@vulnerable_token)) {
            let cap = borrow_global_mut<MintCapability>(@vulnerable_token);
            if (cap.total_supply >= amount) {
                cap.total_supply = cap.total_supply - amount;
            };
        };
    }

    // ❌ CRITICAL 6: Flash loan with no repayment check
    public entry fun flash_borrow(
        account: &signer,
        amount: u64
    ) acquires TokenStore, FlashLoan {
        let addr = signer::address_of(account);
        // Issue tokens to borrower
        if (exists<TokenStore>(addr)) {
            let store = borrow_global_mut<TokenStore>(addr);
            store.balance = store.balance + amount;
            store.debt = store.debt + amount;
        };
        // ❌ Never checks if loan was repaid — this function ends here.
        // Repayment is "optional" with no enforcement mechanism.
        let loan = borrow_global_mut<FlashLoan>(addr);
        loan.active = true;
        loan.amount = amount;
    }

    // ❌ CRITICAL 7: Transfer with no authorization — any signer can drain any account
    public entry fun admin_transfer(
        _any_account: &signer,  // Not validated against from_addr at all!
        from_addr: address,
        to_addr: address,
        amount: u64
    ) acquires TokenStore {
        // State update happens, but caller is NEVER verified to be from_addr
        let from_store = borrow_global_mut<TokenStore>(from_addr);
        from_store.balance = from_store.balance - amount;  // underflow on attack

        let to_store = borrow_global_mut<TokenStore>(to_addr);
        to_store.balance = to_store.balance + amount;  // overflow possible
    }

    public fun get_balance(addr: address): u64 acquires TokenStore {
        if (!exists<TokenStore>(addr)) return 0;
        borrow_global<TokenStore>(addr).balance
    }

    public entry fun register(account: &signer) {
        let addr = signer::address_of(account);
        if (!exists<TokenStore>(addr)) {
            move_to(account, TokenStore {
                balance: 0,
                debt: 0,
                is_frozen: false,
            });
        };
    }
}
