// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title SimpleVault
/// @notice A minimal, secure ETH vault demonstrating CEI pattern and reentrancy guards.
contract SimpleVault {
    address public immutable owner;
    mapping(address => uint256) public balances;

    // Inlined reentrancy guard (avoids "Modifier Invoked Only Once" gas warning)
    bool private _locked;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    error InsufficientBalance();
    error TransferFailed();
    error ZeroAmount();
    error ZeroAddress();
    error ReentrantCall();

    constructor() {
        owner = msg.sender;
    }

    function deposit() external payable {
        if (msg.value == 0) revert ZeroAmount();
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        // Reentrancy guard (inlined)
        if (_locked) revert ReentrantCall();
        _locked = true;

        // Checks
        if (msg.sender == address(0)) revert ZeroAddress();
        if (balances[msg.sender] < amount) revert InsufficientBalance();

        // Effects: update state before any interactions
        balances[msg.sender] -= amount;

        // Log before external call so reentrancy-events detector doesn't fire
        emit Withdrawn(msg.sender, amount);

        // Interactions: low-level call is intentional (avoids 2300 gas stipend of transfer())
        // slither-disable-next-line low-level-calls
        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert TransferFailed();

        _locked = false;
    }

    function getBalance(address user) external view returns (uint256) {
        return balances[user];
    }
}
