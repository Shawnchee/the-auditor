use std::collections::HashMap;

/// A deliberately vulnerable token program (for testing PR Auditor).
///
/// Vulnerabilities:
///   1. Integer overflow in mint (unchecked arithmetic)
///   2. No authorization check on transfer
///   3. Hardcoded admin key
///   4. Panics on invalid input instead of returning errors

const ADMIN_SECRET: &str = "super_secret_key_12345"; // ❌ Hardcoded secret

struct TokenState {
    balances: HashMap<String, u64>,
    total_supply: u64,
}

impl TokenState {
    fn new() -> Self {
        TokenState {
            balances: HashMap::new(),
            total_supply: 0,
        }
    }

    // ❌ VULN 1: No overflow protection on older Rust patterns
    fn mint(&mut self, to: &str, amount: u64) {
        let balance = self.balances.entry(to.to_string()).or_insert(0);
        *balance = balance.wrapping_add(amount); // Wrapping add can silently overflow
        self.total_supply = self.total_supply.wrapping_add(amount);
    }

    // ❌ VULN 2: No authorization — anyone can call transfer
    fn transfer(&mut self, from: &str, to: &str, amount: u64) {
        let from_balance = self.balances.get(from).copied().unwrap_or(0);

        // ❌ VULN 3: Panics instead of returning an error
        if from_balance < amount {
            panic!("Insufficient balance!"); // Should return Result<(), Error>
        }

        *self.balances.entry(from.to_string()).or_insert(0) -= amount;
        *self.balances.entry(to.to_string()).or_insert(0) += amount;
    }

    // ❌ VULN 4: Authentication via hardcoded secret comparison
    fn admin_burn(&mut self, account: &str, amount: u64, secret: &str) {
        if secret != ADMIN_SECRET {
            panic!("Unauthorized!");
        }
        let balance = self.balances.entry(account.to_string()).or_insert(0);
        *balance = balance.saturating_sub(amount);
        self.total_supply = self.total_supply.saturating_sub(amount);
    }
}

fn main() {
    let mut state = TokenState::new();
    state.mint("alice", 1000);
    state.mint("bob", 500);
    state.transfer("alice", "bob", 200);
    println!("Alice: {}", state.balances.get("alice").unwrap_or(&0));
    println!("Bob: {}", state.balances.get("bob").unwrap_or(&0));
}
