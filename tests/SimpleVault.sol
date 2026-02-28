// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title SimpleVault
/// @notice A minimal, secure ETH vault with reentrancy guard and access control.
contract SimpleVault {
    address public immutable owner;
    mapping(address => uint256) public balances;

    bool private _locked;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    error InsufficientBalance();
    error TransferFailed();
    error ZeroAmount();
    error ReentrantCall();

    modifier noReenter() {
        if (_locked) revert ReentrantCall();
        _locked = true;
        _;
        _locked = false;
    }

    constructor() {
        owner = msg.sender;
    }

    function deposit() external payable {
        if (msg.value == 0) revert ZeroAmount();
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external noReenter {
        if (balances[msg.sender] < amount) revert InsufficientBalance();

        // Checks-Effects-Interactions: state update BEFORE external call
        balances[msg.sender] -= amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit Withdrawn(msg.sender, amount);
    }

    function getBalance(address user) external view returns (uint256) {
        return balances[user];
    }
}
