/// Vulnerable Move Token Module (for testing PR Auditor)
///
/// Vulnerabilities:
///   1. No access control on mint — anyone can create tokens
///   2. No overflow check on balance addition
///   3. Missing signer validation on transfer
///   4. Publicly exposed internal function
///   5. No event emissions for tracking

module vulnerable_token::token {
    use std::signer;

    struct TokenStore has key {
        balance: u64,
    }

    struct MintCapability has key, store {
        total_minted: u64,
    }

    // ❌ VULN 1: No access control — anyone can initialize and mint
    public entry fun initialize(account: &signer) {
        move_to(account, MintCapability { total_minted: 0 });
    }

    // ❌ VULN 2: No cap on minting, no authorization check
    public entry fun mint(account: &signer, amount: u64) acquires TokenStore, MintCapability {
        let addr = signer::address_of(account);

        if (!exists<TokenStore>(addr)) {
            move_to(account, TokenStore { balance: 0 });
        };

        let store = borrow_global_mut<TokenStore>(addr);
        // ❌ VULN 3: Potential overflow — no checked arithmetic
        store.balance = store.balance + amount;

        // Update mint cap without checking who is calling
        if (exists<MintCapability>(addr)) {
            let cap = borrow_global_mut<MintCapability>(addr);
            cap.total_minted = cap.total_minted + amount;
        };

        // ❌ VULN 5: No event emitted for mint
    }

    // ❌ VULN 4: Transfer doesn't validate the 'from' signer properly
    // Anyone who can construct the transaction can move tokens
    public entry fun transfer(
        from: &signer,
        to_addr: address,
        amount: u64
    ) acquires TokenStore {
        let from_addr = signer::address_of(from);
        let from_store = borrow_global_mut<TokenStore>(from_addr);

        // Will abort if underflow, but no friendly error message
        from_store.balance = from_store.balance - amount;

        if (!exists<TokenStore>(to_addr)) {
            // ❌ Can't move_to without signer for 'to' — this will fail at runtime
            // This is a logic bug: we can't create storage for another account
            abort 1
        };

        let to_store = borrow_global_mut<TokenStore>(to_addr);
        to_store.balance = to_store.balance + amount;

        // ❌ VULN 5: No event emitted for transfer
    }

    // ❌ VULN 6: Public function exposes internal balance — information leak
    public fun get_balance(addr: address): u64 acquires TokenStore {
        if (!exists<TokenStore>(addr)) {
            return 0
        };
        borrow_global<TokenStore>(addr).balance
    }

    // ❌ VULN 7: Burn without proper authorization
    public entry fun burn(account: &signer, amount: u64) acquires TokenStore {
        let addr = signer::address_of(account);
        let store = borrow_global_mut<TokenStore>(addr);
        store.balance = store.balance - amount; // Will abort on underflow, no error handling
    }
}
