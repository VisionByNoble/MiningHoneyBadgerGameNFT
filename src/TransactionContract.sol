// SPDX-License-Identifier: GPL-3.0 OR MIT
pragma solidity ^0.8.27;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./IBadgeToken.sol";

// Contract for BADGE transactions with fees
contract TransactionContract is Ownable, ReentrancyGuard, Pausable {
    IBadgeToken public badgeToken; // BADGE token contract
    uint256 public transactionFee = 0.5 * 10 ** 18; // Fee per transaction (0.5 BADGE)

    // Events for transaction actions
    event TransactionCompleted(address indexed from, address indexed to, uint256 amount, uint256 fee);
    event TransactionFeeUpdated(uint256 newFee);

    // Constructor links BADGE contract
    constructor(address badgeTokenAddress) Ownable(msg.sender) {
        require(badgeTokenAddress != address(0), "Invalid BadgeToken address");
        badgeToken = IBadgeToken(badgeTokenAddress);
    }

    // Perform a BADGE transaction with fee
    function performTransaction(address to, uint256 amount) public nonReentrant whenNotPaused {
        require(to != address(0), "Cannot transfer to zero address");
        require(amount > 0, "Amount must be greater than 0");
        require(badgeToken.transferFrom(msg.sender, address(this), transactionFee), "Fee transfer failed");
        require(badgeToken.transferFrom(msg.sender, to, amount), "Transfer failed");
        emit TransactionCompleted(msg.sender, to, amount, transactionFee);
    }

    // Update transaction fee (only owner)
    function setTransactionFee(uint256 newFee) public onlyOwner whenNotPaused {
        require(newFee > 0, "Fee must be greater than 0");
        transactionFee = newFee;
        emit TransactionFeeUpdated(newFee);
    }

    // Pause transaction operations
    function pause() public onlyOwner {
        _pause();
    }

    // Resume transaction operations
    function unpause() public onlyOwner {
        _unpause();
    }
}
