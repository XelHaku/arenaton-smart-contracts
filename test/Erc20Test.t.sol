// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

import {USDC} from "../src/USDC.sol";
// import {USDT} from "../src/USDT.sol";
// import {DAI} from "../src/DAI.sol";
// import {ATON} from "../src/ATON.sol";
// import {Vault} from "../src/Vault.sol";
// import {Arenaton} from "../src/Arenaton.sol";
// import {PVT} from "../src/PVT.sol";
// import {Canvas} from "../src/Canvas.sol";
// import {SwapController} from "../src/SwapController.sol";

contract Erc20Test is Test {
    USDC public usdc; //Contract name
    address aliceAddr = makeAddr("alice"); // player 1
    address bobAddr = makeAddr("bob");
    address charlieAddr = makeAddr("charlie");
    address damianAddress = makeAddr("damianAddress");
    address owner = makeAddr("owner");

    function setUp() public {
        //before each test
        vm.warp(1692547800);
        vm.startPrank(owner);
        usdc = new USDC(); //gpt: how to get owner. foundry
        vm.stopPrank();

        // console.log("Balance: \n");
        // emit log_address(aliceAddr); // 0x328809bc894f92807417d2dad6b7c998c1afdac6
    }

    function test_Faucet() public {
        // Assume `usdc` is already deployed and is an instance of the USDC contract
        // Assume `someAddress` is the address you want to impersonate

        // Set up the environment
        uint256 balanceBefore = usdc.balanceOf(aliceAddr);

        // Start the prank with a specific balance
        vm.startPrank(aliceAddr); // Impersonate Alice
        vm.deal(aliceAddr, 2 ** 128); // Set Alice's balance to 2^128 wei
        // Call the faucet method as if `someAddress` is calling it

        console.log("\n\n\n\n\n\nblock.timestamp", block.timestamp);
        usdc.faucet();

        // Stop the prank
        vm.stopPrank();

        // Check the balance after the faucet call
        uint256 balanceAfter = usdc.balanceOf(aliceAddr);
        console.log("\n\n\n\n\n\nbalanceAfter", balanceAfter);

        // Assert that the balance has increased by the expected amount
        assertEq(balanceAfter - balanceBefore, 100 * (10 ** 6), "Faucet did not dispense the correct amount of USDC");
    }
}
