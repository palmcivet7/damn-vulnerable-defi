// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {DamnValuableToken} from "../src/DamnValuableToken.sol";
import {UnstoppableVault} from "../src/unstoppable/UnstoppableVault.sol";
import {ReceiverUnstoppable} from "../src/unstoppable/ReceiverUnstoppable.sol";

contract Unstoppable is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address someUser = makeAddr("someUser");

    DamnValuableToken token;
    UnstoppableVault vault;
    ReceiverUnstoppable receiverContract;

    uint256 public constant TOKENS_IN_VAULT = 1000000 * 1e18;
    uint256 public constant INITIAL_PLAYER_TOKEN_BALANCE = 10 * 1e18;

    function setUp() public {
        vm.deal(deployer, INITIAL_PLAYER_TOKEN_BALANCE);

        vm.startPrank(deployer);
        token = new DamnValuableToken();
        vault = new UnstoppableVault(token, deployer, deployer);
        deal(address(token), deployer, TOKENS_IN_VAULT);

        assertEq(address(vault.asset()), address(token));

        token.approve(address(vault), TOKENS_IN_VAULT);
        vault.deposit(TOKENS_IN_VAULT, deployer);
        vm.stopPrank();

        assertEq(token.balanceOf(address(vault)), TOKENS_IN_VAULT);
        assertEq(vault.totalAssets(), TOKENS_IN_VAULT);
        assertEq(vault.totalSupply(), TOKENS_IN_VAULT);
        assertEq(vault.maxFlashLoan(address(token)), TOKENS_IN_VAULT);
        assertEq(vault.flashFee(address(token), TOKENS_IN_VAULT - 1), 0);
        assertEq(vault.flashFee(address(token), TOKENS_IN_VAULT), 50000 * 1e18);

        deal(address(token), player, INITIAL_PLAYER_TOKEN_BALANCE);
        assertEq(token.balanceOf(player), INITIAL_PLAYER_TOKEN_BALANCE);

        vm.startPrank(someUser);
        receiverContract = new ReceiverUnstoppable(address(vault));
        receiverContract.executeFlashLoan(100 * 1e18);
        vm.stopPrank();
    }

    function test_flashLoan_can_be_stopped() public {
        vm.prank(player);
        token.transfer(address(vault), 1);

        vm.startPrank(someUser);
        vm.expectRevert();
        receiverContract.executeFlashLoan(100 * 1e18);
        vm.stopPrank();
    }
}
