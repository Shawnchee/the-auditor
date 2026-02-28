use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Serialize, Deserialize)]
struct TokenStore {
    balances: HashMap<String, u64>,
    total_supply: u64,
}

impl TokenStore {
    fn new() -> Self {
        TokenStore {
            balances: HashMap::new(),
            total_supply: 0,
        }
    }

    fn mint(&mut self, to: &str, amount: u64) -> Result<(), &'static str> {
        if amount == 0 {
            return Err("Amount must be greater than zero");
        }
        let new_supply = self.total_supply.checked_add(amount).ok_or("Supply overflow")?;
        let balance = self.balances.entry(to.to_string()).or_insert(0);
        *balance = balance.checked_add(amount).ok_or("Balance overflow")?;
        self.total_supply = new_supply;
        Ok(())
    }

    fn transfer(&mut self, from: &str, to: &str, amount: u64) -> Result<(), &'static str> {
        if amount == 0 {
            return Err("Amount must be greater than zero");
        }
        let from_balance = *self.balances.get(from).ok_or("Sender not found")?;
        if from_balance < amount {
            return Err("Insufficient balance");
        }
        *self.balances.entry(from.to_string()).or_insert(0) -= amount;
        *self.balances.entry(to.to_string()).or_insert(0) += amount;
        Ok(())
    }

    fn balance_of(&self, account: &str) -> u64 {
        *self.balances.get(account).unwrap_or(&0)
    }
}

fn main() {
    let mut store = TokenStore::new();
    store.mint("alice", 1000).expect("Mint failed");
    store.transfer("alice", "bob", 200).expect("Transfer failed");

    println!("Alice: {}", store.balance_of("alice"));
    println!("Bob: {}", store.balance_of("bob"));

    let json = serde_json::to_string_pretty(&store).expect("Serialize failed");
    println!("{}", json);
}
