// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title VulnerableVault
 * @dev This contract contains MULTIPLE vulnerabilities for testing PR Auditor.
 *
 * Vulnerabilities:
 *   1. Reentrancy in withdrawAll()
 *   2. Unchecked return value on token transfer
 *   3. tx.origin authentication (phishing risk)
 *   4. Denial of Service via unbounded loop
 *   5. Integer overflow in reward calculation (pre-0.8 pattern)
 *   6. Missing access control on setFeeRecipient
 *   7. Frontrunning vulnerability on setPrice
 */

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract VulnerableVault {
    address public owner;
    address public feeRecipient;
    uint256 public pricePerToken;

    mapping(address => uint256) public deposits;
    mapping(address => uint256) public rewards;
    address[] public depositors;

    IERC20 public token;

    constructor(address _token) {
        owner = msg.sender;
        feeRecipient = msg.sender;
        token = IERC20(_token);
        pricePerToken = 1 ether;
    }

    // ❌ VULN 1: Reentrancy — state updated after external call
    function withdrawAll() public {
        uint256 amount = deposits[msg.sender];
        require(amount > 0, "No deposits");

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        deposits[msg.sender] = 0; // State updated AFTER call
    }

    // ❌ VULN 2: Unchecked return value — token.transfer can silently fail
    function withdrawTokens(uint256 amount) public {
        require(deposits[msg.sender] >= amount, "Insufficient");
        deposits[msg.sender] -= amount;
        token.transfer(msg.sender, amount); // Return value not checked!
    }

    // ❌ VULN 3: tx.origin for authentication — vulnerable to phishing
    function emergencyWithdraw() public {
        require(tx.origin == owner, "Not owner"); // Should use msg.sender!
        payable(owner).transfer(address(this).balance);
    }

    // ❌ VULN 4: DoS via unbounded loop — will revert if too many depositors
    function distributeRewards() public {
        require(msg.sender == owner, "Not owner");
        uint256 totalBalance = address(this).balance;

        for (uint256 i = 0; i < depositors.length; i++) {
            uint256 share = (deposits[depositors[i]] * totalBalance) / getTotalDeposits();
            rewards[depositors[i]] += share;
        }
    }

    // ❌ VULN 5: Dangerous delegatecall — arbitrary code execution
    function execute(address target, bytes calldata data) public {
        require(msg.sender == owner, "Not owner");
        (bool success, ) = target.delegatecall(data); // Can destroy contract!
        require(success, "Execution failed");
    }

    // ❌ VULN 6: Missing access control — anyone can change fee recipient
    function setFeeRecipient(address _newRecipient) public {
        feeRecipient = _newRecipient; // No onlyOwner modifier!
    }

    // ❌ VULN 7: Frontrunning — price can be sandwiched
    function setPrice(uint256 _newPrice) public {
        require(msg.sender == owner, "Not owner");
        pricePerToken = _newPrice; // No timelock or slippage protection
    }

    function deposit() public payable {
        require(msg.value > 0, "Zero deposit");
        if (deposits[msg.sender] == 0) {
            depositors.push(msg.sender);
        }
        deposits[msg.sender] += msg.value;
    }

    function getTotalDeposits() public view returns (uint256) {
        uint256 total;
        for (uint256 i = 0; i < depositors.length; i++) {
            total += deposits[depositors[i]];
        }
        return total;
    }

    receive() external payable {}
}
