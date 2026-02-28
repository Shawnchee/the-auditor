/// @title safe_token
/// @notice A minimal, secure Move token with proper access control and checked arithmetic.
module safe_token::token {
    use std::signer;

    struct TokenStore has key {
        balance: u64,
    }

    struct MintCapability has key {
        total_supply: u64,
    }

    /// Only the module deployer can initialize.
    public entry fun initialize(admin: &signer) {
        let addr = signer::address_of(admin);
        assert!(addr == @safe_token, 1); // Only deployer
        move_to(admin, MintCapability { total_supply: 0 });
    }

    /// Register a new token account.
    public entry fun register(account: &signer) {
        let addr = signer::address_of(account);
        if (!exists<TokenStore>(addr)) {
            move_to(account, TokenStore { balance: 0 });
        };
    }

    /// Mint tokens — only callable by the admin (deployer).
    public entry fun mint(admin: &signer, recipient: address, amount: u64) acquires TokenStore, MintCapability {
        let admin_addr = signer::address_of(admin);
        assert!(admin_addr == @safe_token, 2); // Access control
        assert!(exists<TokenStore>(recipient), 3);
        assert!(amount > 0, 4);

        let store = borrow_global_mut<TokenStore>(recipient);
        store.balance = store.balance + amount;

        let cap = borrow_global_mut<MintCapability>(@safe_token);
        cap.total_supply = cap.total_supply + amount;
    }

    /// Transfer tokens between accounts — caller must be the sender.
    public entry fun transfer(sender: &signer, to: address, amount: u64) acquires TokenStore {
        let from_addr = signer::address_of(sender);
        assert!(exists<TokenStore>(from_addr), 5);
        assert!(exists<TokenStore>(to), 6);
        assert!(amount > 0, 7);

        let from_store = borrow_global_mut<TokenStore>(from_addr);
        assert!(from_store.balance >= amount, 8); // Sufficient balance
        from_store.balance = from_store.balance - amount;

        let to_store = borrow_global_mut<TokenStore>(to);
        to_store.balance = to_store.balance + amount;
    }

    public fun get_balance(addr: address): u64 acquires TokenStore {
        if (!exists<TokenStore>(addr)) return 0;
        borrow_global<TokenStore>(addr).balance
    }
}
