// ⚠️  THIS FILE IS INTENTIONALLY VULNERABLE — for testing PR Auditor only.
//    DO NOT use in production.
//
// Vulnerabilities:
//   1. Hardcoded private key (CRITICAL — immediate secret exposure)
//   2. Unsafe pointer dereference with no bounds check (CRITICAL — memory corruption)
//   3. SQL injection via raw string concatenation (CRITICAL — data breach)
//   4. Unsanitized user input passed to std::process::Command (CRITICAL — arbitrary code execution)
//   5. Integer overflow in reward calculation
//   6. Use-after-free pattern in unsafe block
//   7. Debug credentials left in production code

use std::process::Command;
use std::collections::HashMap;

// ❌ CRITICAL 1: Hardcoded private key
const PRIVATE_KEY: &str = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
const JWT_SECRET: &str   = "super_secret_jwt_key_do_not_share_abc123";
const DB_PASSWORD: &str  = "admin:password123@localhost/prod_db";

// ❌ CRITICAL 2: Command injection — user input straight into shell
fn run_audit(contract_path: &str) {
    // Attacker passes: ".; rm -rf /" as contract_path
    let output = Command::new("sh")
        .arg("-c")
        .arg(format!("slither {}", contract_path)) // ← unsanitized!
        .output()
        .expect("Failed to execute");
    println!("{}", String::from_utf8_lossy(&output.stdout));
}

// ❌ CRITICAL 3: SQL injection — raw string concatenation
fn get_user_balance(username: &str) -> String {
    // Attacker passes: "' OR '1'='1" as username
    format!("SELECT balance FROM users WHERE username = '{}'", username)
    // Should use parameterized queries
}

// ❌ CRITICAL 4: Unsafe raw pointer dereference — no bounds check
fn read_memory_at(offset: usize) -> u8 {
    let buffer: Vec<u8> = vec![0u8; 256];
    unsafe {
        // Attacker controls `offset` — reads arbitrary memory
        let ptr = buffer.as_ptr().add(offset);
        *ptr // ← no bounds check, will read outside buffer
    }
}

// ❌ CRITICAL 5: Use-after-free pattern
fn process_tokens(tokens: Vec<u64>) -> *const u64 {
    let slice = tokens.as_slice();
    let ptr = slice.as_ptr();
    drop(tokens); // tokens is dropped here!
    ptr           // but we return a pointer to freed memory
}

// ❌ HIGH: Integer overflow in reward
fn calculate_reward(balance: u64, multiplier: u64) -> u64 {
    balance * multiplier // wraps on overflow without unchecked
}

// ❌ HIGH: Debug backdoor left in production
fn authenticate(username: &str, password: &str) -> bool {
    // Debug backdoor — always lets "admin"/"debug" in
    if username == "admin" && password == "debug123" {
        return true;
    }
    password == "correct_password"
}

struct TokenStore {
    balances: HashMap<String, u64>,
}

impl TokenStore {
    fn new() -> Self {
        TokenStore { balances: HashMap::new() }
    }

    fn mint(&mut self, to: &str, amount: u64) {
        let balance = self.balances.entry(to.to_string()).or_insert(0);
        *balance = balance.wrapping_add(amount); // silent overflow
    }

    fn transfer(&mut self, from: &str, to: &str, amount: u64) {
        let from_balance = *self.balances.get(from).unwrap_or(&0);
        if from_balance < amount {
            panic!("Insufficient balance"); // should return Result
        }
        *self.balances.entry(from.to_string()).or_insert(0) -= amount;
        *self.balances.entry(to.to_string()).or_insert(0) += amount;
    }
}

fn main() {
    println!("Private key: {}", PRIVATE_KEY); // ❌ logs secret to stdout!

    let mut store = TokenStore::new();
    store.mint("alice", 1000);
    store.transfer("alice", "bob", 200);

    // ❌ Calling vulnerable functions
    run_audit("/tmp/user_input_contract.sol");
    let query = get_user_balance("alice' OR '1'='1");
    println!("Query: {}", query);

    let reward = calculate_reward(u64::MAX, 2); // overflows
    println!("Reward: {}", reward);
}
