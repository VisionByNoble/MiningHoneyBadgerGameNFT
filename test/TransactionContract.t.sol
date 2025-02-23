// SPDX-License-Identifier: GPL-3.0 OR MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/BadgeToken.sol";
import "../src/TransactionContract.sol";

contract TransactionContractTest is Test {
    BadgeToken badgeToken;
    TransactionContract transactionContract;
    address owner = address(this);
    address user1 = address(0x123);
    address user2 = address(0x456);

    function setUp() public {
        badgeToken = new BadgeToken(1000000);
        transactionContract = new TransactionContract(address(badgeToken));
        badgeToken.mint(user1, 101 * 10 ** 18);
    }

    function testPerformTransaction() public {
        vm.prank(user1);
        badgeToken.approve(address(transactionContract), 101 * 10 ** 18);
        vm.prank(user1);
        transactionContract.performTransaction(user2, 100 * 10 ** 18);
        assertEq(badgeToken.balanceOf(user2), 100 * 10 ** 18, "User2 should receive 100 BADGE");
        assertEq(
            badgeToken.balanceOf(address(transactionContract)), 0.5 * 10 ** 18, "Contract should receive 0.5 BADGE fee"
        );
    }

    function testSetTransactionFee() public {
        vm.prank(owner);
        transactionContract.setTransactionFee(1 * 10 ** 18);
        assertEq(transactionContract.transactionFee(), 1 * 10 ** 18, "Transaction fee should be updated to 1 BADGE");
    }

    function testPausedTransaction() public {
        vm.prank(owner);
        transactionContract.pause();
        vm.prank(user1);
        badgeToken.approve(address(transactionContract), 101 * 10 ** 18);
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()")); // Updated to match OpenZeppelin v5
        transactionContract.performTransaction(user2, 100 * 10 ** 18);
    }
}
