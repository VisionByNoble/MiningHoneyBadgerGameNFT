// SPDX-License-Identifier: GPL-3.0 OR MIT
pragma solidity ^0.8.27;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./IBadgeToken.sol";

// Validator staking and reward distribution
contract ValidatorContract is Ownable, ReentrancyGuard, Pausable {
    IBadgeToken public badgeToken;
    mapping(address => uint256) public validatorStakes;
    mapping(address => bool) public isValidator;
    mapping(address => uint256) public unstakeRequests;
    uint256 public unstakeDelay = 8 days;
    address[] public validators;

    event ValidatorAdded(address indexed validator, uint256 stakeAmount);
    event ValidatorSlashed(address indexed validator, uint256 slashedAmount);
    event UnstakeRequested(address indexed validator, uint256 amount, uint256 unlockTime);
    event UnstakeCompleted(address indexed validator, uint256 amount);

    constructor(address badgeTokenAddress) Ownable(msg.sender) {
        require(badgeTokenAddress != address(0), "Invalid BadgeToken address");
        badgeToken = IBadgeToken(badgeTokenAddress);
    }

    function becomeValidator(uint256 stakeAmount) public nonReentrant whenNotPaused {
        require(stakeAmount > 0, "Stake amount must be greater than 0");
        require(badgeToken.transferFrom(msg.sender, address(this), stakeAmount), "Transfer failed");
        validatorStakes[msg.sender] += stakeAmount;
        if (!isValidator[msg.sender]) {
            isValidator[msg.sender] = true;
            validators.push(msg.sender);
        }
        emit ValidatorAdded(msg.sender, stakeAmount);
    }

    function requestUnstake(uint256 amount) public nonReentrant whenNotPaused {
        require(isValidator[msg.sender], "Not a validator");
        require(validatorStakes[msg.sender] >= amount, "Insufficient stake");
        require(unstakeRequests[msg.sender] == 0, "Unstake already requested");

        unstakeRequests[msg.sender] = block.timestamp + unstakeDelay;
        // Don’t reduce stake here; handle in completeUnstake
        emit UnstakeRequested(msg.sender, amount, unstakeRequests[msg.sender]);
    }

    function completeUnstake() public nonReentrant whenNotPaused {
        uint256 unlockTime = unstakeRequests[msg.sender];
        require(unlockTime > 0, "No unstake requested");
        require(block.timestamp >= unlockTime, "Unstake delay not passed");

        uint256 amount = validatorStakes[msg.sender]; // Use full stake
        delete unstakeRequests[msg.sender];
        if (amount > 0) {
            validatorStakes[msg.sender] = 0; // Reset stake
            if (isValidator[msg.sender]) {
                isValidator[msg.sender] = false;
                _removeValidator(msg.sender);
            }
            require(badgeToken.transfer(msg.sender, amount), "Transfer failed");
            emit UnstakeCompleted(msg.sender, amount);
        }
    }

    function slashValidator(address validator, uint256 amount) public onlyOwner nonReentrant whenNotPaused {
        require(validator != address(0), "Invalid validator address");
        require(isValidator[validator], "Not a validator");
        require(validatorStakes[validator] >= amount, "Insufficient stake");
        validatorStakes[validator] -= amount;
        badgeToken.transfer(owner(), amount);
        if (validatorStakes[validator] == 0) {
            isValidator[validator] = false;
            _removeValidator(validator);
        }
        emit ValidatorSlashed(validator, amount);
    }

    function distributeValidatorReward(address miner, uint256 amount) external onlyOwner nonReentrant whenNotPaused {
        require(validators.length > 0, "No validators");
        uint256 rewardPerValidator = amount / validators.length;
        for (uint256 i = 0; i < validators.length; i++) {
            if (validators[i] != miner) {
                badgeToken.transfer(validators[i], rewardPerValidator);
            }
        }
    }

    function _removeValidator(address validator) internal {
        for (uint256 i = 0; i < validators.length; i++) {
            if (validators[i] == validator) {
                validators[i] = validators[validators.length - 1];
                validators.pop();
                break;
            }
        }
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function getValidators() public view returns (address[] memory) {
        return validators;
    }
}
