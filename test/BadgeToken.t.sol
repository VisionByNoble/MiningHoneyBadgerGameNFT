// SPDX-License-Identifier: GPL-3.0 OR MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/BadgeToken.sol";

contract BadgeTokenTest is Test {
    BadgeToken badgeToken;
    address owner = address(0x123);
    address user1 = address(0x456);

    function setUp() public {
        vm.prank(owner);
        badgeToken = new BadgeToken(1000000);
    }

    function testInitialSupply() public view {
        assertEq(badgeToken.totalSupply(), 1000000 * 10 ** 18, "Total supply should be 1M BADGE");
        assertEq(badgeToken.balanceOf(owner), 1000000 * 10 ** 18, "Owner should have all BADGE");
    }

    function testTransfer() public {
        vm.prank(owner);
        badgeToken.transfer(user1, 1000 * 10 ** 18);
        assertEq(badgeToken.balanceOf(user1), 1000 * 10 ** 18, "User1 should receive 1000 BADGE");
        assertEq(badgeToken.balanceOf(owner), 999000 * 10 ** 18, "Owner balance should decrease");
    }

    function testApproveAndTransferFrom() public {
        vm.prank(owner);
        badgeToken.approve(user1, 500 * 10 ** 18);
        assertEq(badgeToken.allowance(owner, user1), 500 * 10 ** 18, "Allowance should be 500 BADGE");

        vm.prank(user1);
        badgeToken.transferFrom(owner, user1, 500 * 10 ** 18);
        assertEq(badgeToken.balanceOf(user1), 500 * 10 ** 18, "User1 should receive 500 BADGE");
        assertEq(badgeToken.balanceOf(owner), 999500 * 10 ** 18, "Owner balance should decrease");
    }

    function testMint() public {
        vm.prank(owner);
        badgeToken.mint(user1, 1000 * 10 ** 18);
        assertEq(badgeToken.balanceOf(user1), 1000 * 10 ** 18, "User1 should receive 1000 BADGE");
        assertEq(badgeToken.totalSupply(), 1001000 * 10 ** 18, "Total supply should increase");
    }

    function testBurn() public {
        vm.prank(owner);
        badgeToken.burn(1000 * 10 ** 18);
        assertEq(badgeToken.balanceOf(owner), 999000 * 10 ** 18, "Owner balance should decrease");
        assertEq(badgeToken.totalSupply(), 999000 * 10 ** 18, "Total supply should decrease");
    }

    function testBurnFrom() public {
        vm.prank(owner);
        badgeToken.approve(user1, 1000 * 10 ** 18);
        vm.prank(user1);
        badgeToken.burnFrom(owner, 1000 * 10 ** 18);
        assertEq(badgeToken.balanceOf(owner), 999000 * 10 ** 18, "Owner balance should decrease");
        assertEq(badgeToken.totalSupply(), 999000 * 10 ** 18, "Total supply should decrease");
    }

    // Test pausing prevents transfers with correct revert message
    function testPausedTransfer() public {
        vm.prank(owner);
        badgeToken.pause();
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()")); // Updated to match OpenZeppelin v5
        badgeToken.transfer(user1, 1000 * 10 ** 18);
    }
}
