// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title CriticalDeFi
 * @dev This contract simulates a DeFi protocol with CRITICAL vulnerabilities.
 *      Designed to trigger the highest severity findings in Slither and Aderyn.
 *
 * Critical Vulnerabilities:
 *   1. Unprotected selfdestruct — anyone can destroy the contract
 *   2. Unprotected delegatecall — arbitrary code execution
 *   3. Reentrancy via raw .call() — classic drain attack
 *   4. Uninitialized storage pointer — corrupts other state
 *   5. Arbitrary ETH send to user-controlled address
 */

contract CriticalDeFi {
    address public owner;
    mapping(address => uint256) public balances;
    mapping(address => bool) public isWhitelisted;

    uint256 public totalDeposited;
    address public pendingWithdrawal;

    constructor() {
        owner = msg.sender;
    }

    // ❌ CRITICAL 1: Unprotected selfdestruct — anyone can kill the contract
    function shutdown(address payable beneficiary) public {
        // No access control! Any user can call this and steal all ETH
        selfdestruct(beneficiary);
    }

    // ❌ CRITICAL 2: Unprotected delegatecall — arbitrary code execution
    function upgradeAndCall(address newImplementation, bytes calldata data) public {
        // No access control! Attacker can run ANY code in this contract's context
        (bool success, ) = newImplementation.delegatecall(data);
        require(success, "Delegatecall failed");
    }

    // ❌ CRITICAL 3: Reentrancy — state updated after external call
    function withdraw(uint256 amount) public {
        require(balances[msg.sender] >= amount, "Insufficient balance");

        // External call BEFORE state update = classic reentrancy
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        // State update happens AFTER the call — attacker re-enters before this line
        balances[msg.sender] -= amount;
        totalDeposited -= amount;
    }

    // ❌ CRITICAL 4: Arbitrary send — user controls where ETH goes
    function transferTo(address payable recipient, uint256 amount) public {
        // No validation that recipient is legitimate
        // No check that caller owns the funds
        require(address(this).balance >= amount, "Not enough ETH");
        recipient.transfer(amount);
    }

    // ❌ CRITICAL 5: Write to arbitrary storage slot
    function setStorageAt(uint256 slot, uint256 value) public {
        // This allows overwriting ANY storage variable (owner, balances, etc.)
        assembly {
            sstore(slot, value)
        }
    }

    // ❌ HIGH: tx.origin authentication
    function adminWithdraw() public {
        require(tx.origin == owner, "Not admin");
        payable(owner).transfer(address(this).balance);
    }

    // ❌ HIGH: unchecked external call return value
    function batchTransfer(address[] calldata recipients, uint256 amount) public {
        for (uint256 i = 0; i < recipients.length; i++) {
            // Return value ignored — transfers can silently fail
            payable(recipients[i]).send(amount);
        }
    }

    function deposit() public payable {
        require(msg.value > 0, "Zero deposit");
        balances[msg.sender] += msg.value;
        totalDeposited += msg.value;
    }

    receive() external payable {}
}
