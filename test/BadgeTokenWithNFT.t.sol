// SPDX-License-Identifier: GPL-3.0 OR MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/BadgeToken.sol";
import "../src/BadgeTokenWithNFT.sol";

// Test suite for BadgeTokenWithNFT (NFT staking and mining)
contract BadgeTokenWithNFTTest is Test {
    BadgeToken badgeToken; // BADGE token instance
    BadgeTokenWithNFT badgeNFT; // NFT game instance
    address owner = address(this); // Test owner (this contract)
    address user1 = address(0x123); // Test player

    // Setup function runs before each test
    function setUp() public {
        badgeToken = new BadgeToken(1000000); // Deploy BADGE with 1M supply
        badgeNFT = new BadgeTokenWithNFT(address(badgeToken), address(this)); // Deploy NFT game, this contract as validator
        badgeToken.mint(address(badgeNFT), 1000 * 10 ** 18); // Fund NFT contract with BADGE
    }

    // Test minting an NFT
    function testMintNFT() public {
        badgeNFT.mintNFT(user1, "https://example.com/nft1", 50); // Mint NFT with 50 power
        assertEq(badgeNFT.ownerOf(1), user1, "User1 should own NFT ID 1");
        assertEq(badgeNFT.miningPower(1), 50, "NFT power should be 50");
    }

    // Test staking ETH to play
    function testStakeETH() public {
        vm.deal(user1, 1 ether); // Give user1 ETH
        vm.prank(user1); // Act as user1
        badgeNFT.stakeETH{value: 0.05 ether}(); // Stake 0.05 ETH
        assertEq(badgeNFT.ethStaked(user1), 500 * 10 ** 18, "User1 should have 500 BADGE staked"); // Expect 500e18
        assertEq(badgeNFT.attemptsLeft(user1), 50, "User1 should have 50 attempts");
    }

    // Test staking an NFT
    function testStakeNFT() public {
        badgeNFT.mintNFT(user1, "https://example.com/nft2", 30); // Mint NFT
        vm.prank(user1); // Act as user1
        badgeNFT.stakeNFT(1); // Stake NFT
        assertEq(badgeNFT.ownerOf(1), address(badgeNFT), "NFT should be owned by contract");
        assertEq(badgeNFT.totalStakedPower(user1), 30, "Total staked power should be 30");
    }

    // Test unstaking an NFT
    function testUnstakeNFT() public {
        badgeNFT.mintNFT(user1, "https://example.com/nft3", 40); // Mint NFT
        vm.prank(user1); // Act as user1
        badgeNFT.stakeNFT(1); // Stake NFT
        vm.prank(user1); // Act as user1
        badgeNFT.unstakeNFT(1); // Unstake NFT
        assertEq(badgeNFT.ownerOf(1), user1, "NFT should be returned to user1");
        assertEq(badgeNFT.totalStakedPower(user1), 0, "Total staked power should reset");
    }

    // Test mining with a successful attempt
    function testMineBlock() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        badgeNFT.stakeETH{value: 0.05 ether}(); // Stake ETH
        badgeNFT.mintNFT(user1, "https://example.com/nft4", 100); // Mint high-power NFT (100% success chance)
        vm.prank(user1);
        badgeNFT.stakeNFT(1);
        vm.warp(block.timestamp + 1 hours + 1); // Advance time past cooldown
        uint256 initialBalance = badgeToken.balanceOf(user1);
        vm.prank(user1);
        badgeNFT.mineBlock();
        assertGt(badgeToken.balanceOf(user1), initialBalance, "User1 should receive BADGE reward");
    }

    // Test upgrading an NFT
    function testUpgradeNFT() public {
        badgeNFT.mintNFT(user1, "https://example.com/nft5", 50); // Mint NFT
        vm.prank(owner);
        badgeToken.mint(user1, 5 * 10 ** 18); // Give user1 BADGE for upgrade
        vm.prank(user1);
        badgeToken.approve(address(badgeNFT), 5 * 10 ** 18); // Approve upgrade cost
        vm.prank(user1);
        badgeNFT.upgradeNFT(1); // Upgrade NFT
        assertEq(badgeNFT.miningPower(1), 60, "NFT power should increase to 60");
    }

    // Test pausing prevents mining
    function testPausedMining() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        badgeNFT.stakeETH{value: 0.05 ether}();
        badgeNFT.mintNFT(user1, "https://example.com/nft6", 50);
        vm.prank(user1);
        badgeNFT.stakeNFT(1);
        vm.prank(owner);
        badgeNFT.pause();
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        badgeNFT.mineBlock();
    }

    // Mock validator reward distribution (since this contract acts as validator)
    function distributeValidatorReward(address, uint256) external {}
}
