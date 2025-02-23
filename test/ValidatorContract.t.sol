// SPDX-License-Identifier: GPL-3.0 OR MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/BadgeToken.sol";
import "../src/ValidatorContract.sol";

contract ValidatorContractTest is Test {
    BadgeToken badgeToken;
    ValidatorContract validatorContract;
    address owner = address(this);
    address validator1 = address(0x123);

    function setUp() public {
        badgeToken = new BadgeToken(1000000);
        validatorContract = new ValidatorContract(address(badgeToken));
        badgeToken.mint(validator1, 1000 * 10 ** 18);
    }

    function testBecomeValidator() public {
        vm.prank(validator1);
        badgeToken.approve(address(validatorContract), 100 * 10 ** 18);
        vm.prank(validator1);
        validatorContract.becomeValidator(100 * 10 ** 18);
        assertTrue(validatorContract.isValidator(validator1), "Validator1 should be a validator");
        assertEq(validatorContract.validatorStakes(validator1), 100 * 10 ** 18, "Stake should be 100 BADGE");
    }

    function testUnstake() public {
        vm.prank(validator1);
        badgeToken.approve(address(validatorContract), 100 * 10 ** 18);
        vm.prank(validator1);
        validatorContract.becomeValidator(100 * 10 ** 18);
        vm.prank(validator1);
        validatorContract.requestUnstake(100 * 10 ** 18);
        vm.warp(block.timestamp + 8 days + 1);
        vm.prank(validator1);
        validatorContract.completeUnstake();
        assertEq(badgeToken.balanceOf(validator1), 1000 * 10 ** 18, "Validator1 should recover 1000 BADGE");
    }

    function testSlashValidator() public {
        vm.prank(validator1);
        badgeToken.approve(address(validatorContract), 100 * 10 ** 18);
        vm.prank(validator1);
        validatorContract.becomeValidator(100 * 10 ** 18);
        uint256 initialOwnerBalance = badgeToken.balanceOf(owner);
        vm.prank(owner);
        validatorContract.slashValidator(validator1, 50 * 10 ** 18);
        assertEq(validatorContract.validatorStakes(validator1), 50 * 10 ** 18, "Stake should be 50 BADGE");
        assertEq(badgeToken.balanceOf(owner), initialOwnerBalance + 50 * 10 ** 18, "Owner should receive 50 BADGE");
    }

    function testPausedStaking() public {
        vm.prank(owner);
        validatorContract.pause();
        vm.prank(validator1);
        badgeToken.approve(address(validatorContract), 100 * 10 ** 18);
        vm.prank(validator1);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()")); // Updated to match OpenZeppelin v5
        validatorContract.becomeValidator(100 * 10 ** 18);
    }
}
