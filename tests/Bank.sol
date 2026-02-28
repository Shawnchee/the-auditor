// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Vulnerable Bank
 * @dev This contract contains a classic REENTRANCY vulnerability.
 */
contract VulnerableBank {
    mapping(address => uint256) public balances;

    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    // ❌ VULNERABLE: This function is susceptible to reentrancy
    function withdraw() public {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "Insufficient balance");

        // The state is updated AFTER the external call
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        balances[msg.sender] = 0;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
