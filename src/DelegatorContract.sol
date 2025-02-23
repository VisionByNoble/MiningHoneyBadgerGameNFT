// SPDX-License-Identifier: GPL-3.0 OR MIT
pragma solidity ^0.8.27;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./IBadgeToken.sol";

// Interface to check validator status
interface IValidatorContract {
    function isValidator(address validator) external view returns (bool);
}

// Contract for delegating BADGE to validators
contract DelegatorContract is Ownable, ReentrancyGuard, Pausable {
    IBadgeToken public badgeToken; // BADGE token contract
    IValidatorContract public validatorContract; // Validator contract reference
    mapping(address => address) public delegatorToValidator; // Validator per delegator
    mapping(address => uint256) public delegatorStakes; // Staked BADGE per delegator
    mapping(address => uint256) public undelegateRequests; // Undelegation timestamps
    uint256 public undelegateDelay = 8 days; // Delay before undelegating

    // Events for delegation actions
    event Delegated(address indexed delegator, address indexed validator, uint256 amount);
    event UndelegateRequested(address indexed delegator, uint256 amount, uint256 unlockTime);
    event UndelegateCompleted(address indexed delegator, uint256 amount);

    // Constructor links BADGE and Validator contracts
    constructor(address badgeTokenAddress, address validatorContractAddress) Ownable(msg.sender) {
        require(badgeTokenAddress != address(0), "Invalid BadgeToken address");
        require(validatorContractAddress != address(0), "Invalid ValidatorContract address");
        badgeToken = IBadgeToken(badgeTokenAddress);
        validatorContract = IValidatorContract(validatorContractAddress);
    }

    // Delegate BADGE to a validator
    function delegateToValidator(address validator, uint256 amount) public nonReentrant whenNotPaused {
        require(validatorContract.isValidator(validator), "Invalid validator");
        require(amount > 0, "Amount must be greater than 0");
        require(badgeToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        delegatorToValidator[msg.sender] = validator; // Set validator
        delegatorStakes[msg.sender] += amount; // Add to stake
        emit Delegated(msg.sender, validator, amount);
    }

    // Request to undelegate BADGE (8-day delay)
    function requestUndelegate(uint256 amount) public nonReentrant whenNotPaused {
        require(delegatorStakes[msg.sender] >= amount, "Insufficient stake");
        require(undelegateRequests[msg.sender] == 0, "Undelegation already requested");

        undelegateRequests[msg.sender] = block.timestamp + undelegateDelay;
        delegatorStakes[msg.sender] -= amount; // Reduce stake
        emit UndelegateRequested(msg.sender, amount, undelegateRequests[msg.sender]);
    }

    // Complete undelegation after delay
    function completeUndelegate() public nonReentrant whenNotPaused {
        uint256 unlockTime = undelegateRequests[msg.sender];
        require(unlockTime > 0, "No undelegation requested");
        require(block.timestamp >= unlockTime, "Undelegation delay not passed");

        uint256 amount = delegatorStakes[msg.sender];
        delete undelegateRequests[msg.sender]; // Clear request
        delete delegatorToValidator[msg.sender]; // Clear validator
        if (amount > 0) {
            delegatorStakes[msg.sender] = 0; // Reset stake
            require(badgeToken.transfer(msg.sender, amount), "Transfer failed");
            emit UndelegateCompleted(msg.sender, amount);
        }
    }

    // Pause delegation operations
    function pause() public onlyOwner {
        _pause();
    }

    // Resume delegation operations
    function unpause() public onlyOwner {
        _unpause();
    }

    // View undelegation status
    function getUndelegateRequest(address delegator) public view returns (uint256 unlockTime, uint256 amount) {
        return (undelegateRequests[delegator], delegatorStakes[delegator]);
    }
}
