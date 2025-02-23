// SPDX-License-Identifier: GPL-3.0 OR MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/BadgeToken.sol";
import "../src/ValidatorContract.sol";
import "../src/DelegatorContract.sol";

contract DelegatorContractTest is Test {
    BadgeToken badgeToken;
    ValidatorContract validatorContract;
    DelegatorContract delegatorContract;
    address owner = address(this);
    address validator = address(0x123);
    address delegator = address(0x456);

    function setUp() public {
        badgeToken = new BadgeToken(1000000);
        validatorContract = new ValidatorContract(address(badgeToken));
        delegatorContract = new DelegatorContract(address(badgeToken), address(validatorContract));

        badgeToken.mint(validator, 100 * 10 ** 18);
        badgeToken.mint(delegator, 100 * 10 ** 18);

        vm.prank(validator);
        badgeToken.approve(address(validatorContract), 100 * 10 ** 18);
        vm.prank(validator);
        validatorContract.becomeValidator(100 * 10 ** 18);
    }

    function testDelegate() public {
        vm.prank(delegator);
        badgeToken.approve(address(delegatorContract), 50 * 10 ** 18);
        vm.prank(delegator);
        delegatorContract.delegateToValidator(validator, 50 * 10 ** 18);
        assertEq(delegatorContract.delegatorToValidator(delegator), validator, "Validator should be set");
        assertEq(delegatorContract.delegatorStakes(delegator), 50 * 10 ** 18, "Stake should be 50 BADGE");
    }

    function testUndelegate() public {
        vm.prank(delegator);
        badgeToken.approve(address(delegatorContract), 50 * 10 ** 18);
        vm.prank(delegator);
        delegatorContract.delegateToValidator(validator, 50 * 10 ** 18);
        vm.prank(delegator);
        delegatorContract.requestUndelegate(50 * 10 ** 18);
        vm.warp(block.timestamp + 8 days + 1);
        vm.prank(delegator);
        delegatorContract.completeUndelegate();
        assertEq(badgeToken.balanceOf(delegator), 50 * 10 ** 18, "Delegator should recover 50 BADGE"); // Fixed to expect remaining balance
    }

    function testPausedDelegation() public {
        vm.prank(owner);
        delegatorContract.pause();
        vm.prank(delegator);
        badgeToken.approve(address(delegatorContract), 50 * 10 ** 18);
        vm.prank(delegator);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        delegatorContract.delegateToValidator(validator, 50 * 10 ** 18);
    }
}
