// SPDX-License-Identifier: GPL-3.0 OR MIT
pragma solidity ^0.8.27;

// Interface for BadgeToken interactions, used across contracts
interface IBadgeToken {
    // Transfer BADGE tokens to a recipient
    function transfer(address to, uint256 amount) external returns (bool);

    // Transfer BADGE tokens on behalf of an owner with approval
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    // Check the BADGE balance of an account
    function balanceOf(address account) external view returns (uint256);
}
