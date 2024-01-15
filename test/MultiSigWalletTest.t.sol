// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";

contract MultiSigWalletTest is Test {

    MultiSigWallet wallet;
    function setUp() public {
        address[] memory owners = new address[](3);
        owners[0] = address(0x1);
        owners[1] = address(0x2);
        owners[2] = address(0x3);
        wallet = new MultiSigWallet(owners, 2);
    }

    function testSubmitTransaction() public {
        vm.prank(address(0x3));
        wallet.submitTransaction(address(0x4), 100, "");
        assertEq(wallet.getTransactionTo(0), address(0x4));
        assertEq(wallet.getTransactionValue(0), 100);
        assertEq(wallet.getTransactionData(0), "");
        assertEq(wallet.getTransactionExecuted(0), false);
        assertEq(wallet.getTransactionApprovers(0).length, 0);
    }

    function testApproveTransaction() public {
        vm.startPrank(address(0x3));
        wallet.submitTransaction(address(0x4), 100, "");
        wallet.approveTransaction(0);
        assertEq(wallet.getTransactionApprovers(0).length, 1);
        assertEq(wallet.getTransactionApprovers(0)[0], address(0x3));
    }

    function testCancelTransaction() public {
        vm.startPrank(address(0x3));
        wallet.submitTransaction(address(0x4), 100, "");
        wallet.cancelTransaction(0);
        vm.expectRevert(MultiSigWallet.MultiSigWallet__TransactionAlreadyExecuted.selector);
        wallet.approveTransaction(0);
    }

    function testIsOwner() public {
        assertEq(wallet.isOwner(address(0x1)), true);
        assertEq(wallet.isOwner(address(0x4)), false);
    }

    function testExecuteTransaction() public {
        vm.startPrank(address(0x3));
        wallet.submitTransaction(address(0x4), 100000, "");
        wallet.approveTransaction(0);
        assertEq(wallet.getTransactionExecuted(0), false);
        vm.deal(address(wallet), 100000); // send 100000 to wallet
        vm.startPrank(address(0x2));
        wallet.approveTransaction(0);
        assertEq(wallet.getTransactionExecuted(0), true);
    }
}