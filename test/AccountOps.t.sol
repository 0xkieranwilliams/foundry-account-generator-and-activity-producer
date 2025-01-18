// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {AccountOps} from "../script/AccountOps.s.sol";

contract AccountOpsTest is Test {
    AccountOps private ops;

    uint256 constant MASTER_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address constant CONSOLIDATION_TARGET = address(0x1234567890123456789012345678901234567890);
    uint256 constant INITIAL_BALANCE = 100 ether;
    uint256 constant ACCOUNTS_COUNT = 50;
    uint256 constant MIN_TRANSFER = 10000000000000000; // 0.01 ether
    uint256 constant ACTIVITY_ROUNDS = 5; // 5 rounds of interactions per account

    function setUp() public {
        vm.setEnv("MASTER_KEY", vm.toString(MASTER_KEY));
        vm.setEnv("CONSOLIDATION_TARGET", vm.toString(CONSOLIDATION_TARGET));

        vm.setEnv("ACCOUNTS_COUNT", vm.toString(ACCOUNTS_COUNT));
        vm.setEnv("MIN_TRANSFER", vm.toString(MIN_TRANSFER));
        vm.setEnv("ACTIVITY_ROUNDS", vm.toString(ACTIVITY_ROUNDS));

        ops = new AccountOps();
        ops.setUp();

        // Prime master account with test ether
        vm.deal(vm.addr(MASTER_KEY), INITIAL_BALANCE);
    }

    function test_genAccounts_DeterministicDerivation() public {
        ops.genAccounts();
        address[] memory firstBatch = extractAddresses();

        ops = new AccountOps();
        ops.setUp();
        ops.genAccounts();
        address[] memory secondBatch = extractAddresses();

        for (uint256 i = 0; i < firstBatch.length; i++) {
            assertEq(firstBatch[i], secondBatch[i], "Non-deterministic account generation");
            console2.log("Verified deterministic account", i, ":", firstBatch[i]);
        }
    }

    function test_distribute_InitialFundDistribution() public {
        ops.genAccounts();
        uint256 preBalance = vm.addr(MASTER_KEY).balance;

        ops.distribute();

        address[] memory accounts = extractAddresses();
        uint256 totalDistributed = 0;

        for (uint256 i = 0; i < accounts.length; i++) {
            uint256 balance = accounts[i].balance;
            assertTrue(balance >= 0.01 ether, "Insufficient distribution");
            totalDistributed += balance;
            console2.log("Account", i, "received:", balance);
        }

        assertEq(vm.addr(MASTER_KEY).balance, preBalance - totalDistributed, "Distribution accounting error");
    }

    function test_simulate_ActivityPatterns() public {
        ops.genAccounts();
        ops.distribute();

        address[] memory accounts = extractAddresses();
        uint256[] memory preBalances = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) {
            preBalances[i] = accounts[i].balance;
        }

        ops.simulateActivity();

        bool activityDetected = false;
        for (uint256 i = 0; i < accounts.length; i++) {
            if (accounts[i].balance != preBalances[i]) {
                activityDetected = true;
                console2.log("Activity detected for account ", i, ". ", accounts[i]);
                console2.log("Balance change:", int256(accounts[i].balance) - int256(preBalances[i]));
            }
        }
        assertTrue(activityDetected, "No activity detected");
    }

    function test_consolidate_FundRecovery() public {
        uint256 gasPerTransfer = 0.0001 ether; // 10^14 wei
        uint256 baseTransfer = 0.01 ether; // 10^16 wei per account

        ops.genAccounts();
        ops.distribute();
        ops.simulateActivity();

        uint256 preConsolidationBalance = CONSOLIDATION_TARGET.balance;

        ops.consolidate();

        address[] memory accounts = extractAddresses();

        // Calculate initial distribution total
        uint256 initialTotal = accounts.length * baseTransfer; // 50 * 0.01 = 0.5 ETH
        uint256 totalGasReserved = accounts.length * gasPerTransfer; // 50 * 0.0001 = 0.005 ETH
        uint256 expectedConsolidation = initialTotal - totalGasReserved; // 0.495 ETH

        uint256 actualConsolidation = CONSOLIDATION_TARGET.balance - preConsolidationBalance;

        assertEq(actualConsolidation, expectedConsolidation, "Consolidated amount mismatch");

        // Granular balance validation
        for (uint256 i = 0; i < accounts.length; i++) {
            assertEq(accounts[i].balance, gasPerTransfer, "Account gas reserve mismatch");
        }

        console2.log("\nConsolidation Analysis:");
        console2.log("Initial Distribution:", initialTotal);
        console2.log("Total Gas Reserved:", totalGasReserved);
        console2.log("Expected Consolidation:", expectedConsolidation);
        console2.log("Actual Consolidation:", actualConsolidation);
    }

    function test_fullLifecycle_AccountOperations() public {
        uint256 gasPerTransfer = 0.0001 ether; // Critical gas reservation constant

        // Initial state validation with precise balance tracking
        uint256 initialMasterBalance = vm.addr(MASTER_KEY).balance;
        console2.log("\nInitial Master Account State");
        console2.log("Address:", vm.addr(MASTER_KEY));
        console2.log("Balance:", initialMasterBalance);

        assertEq(initialMasterBalance, INITIAL_BALANCE);
        assertEq(CONSOLIDATION_TARGET.balance, 0);

        console2.log("\n=== Starting Full Lifecycle Test ===");
        console2.log("Initial master balance:", INITIAL_BALANCE);

        // Account generation validation
        ops.genAccounts();
        address[] memory accounts = extractAddresses();
        assertEq(accounts.length, ACCOUNTS_COUNT, "Account generation failed");

        console2.log("Generated", accounts.length, "accounts");

        // Distribution phase with delta tracking
        uint256 preDist = vm.addr(MASTER_KEY).balance;
        ops.distribute();
        uint256 postDist = vm.addr(MASTER_KEY).balance;

        console2.log("Total distributed:", preDist - postDist);

        // Activity simulation with granular balance monitoring
        uint256[] memory preSimBalances = new uint256[](accounts.length);
        uint256[] memory postSimBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; i++) {
            preSimBalances[i] = accounts[i].balance;
        }

        ops.simulateActivity();

        for (uint256 i = 0; i < accounts.length; i++) {
            postSimBalances[i] = accounts[i].balance;
            if (preSimBalances[i] != postSimBalances[i]) {
                console2.log("Account: ", i, ". ", accounts[i]);
                console2.log("Balance change:", int256(postSimBalances[i]) - int256(preSimBalances[i]));
            }
        }

        // Consolidation phase with gas reservation validation
        uint256 preConsolidation = CONSOLIDATION_TARGET.balance;
        ops.consolidate();
        uint256 postConsolidation = CONSOLIDATION_TARGET.balance;

        console2.log("Total consolidated:", postConsolidation - preConsolidation);

        // Critical: Validate gas reservation rather than zero balance
        for (uint256 i = 0; i < accounts.length; i++) {
            assertEq(accounts[i].balance, gasPerTransfer, "Incorrect gas reservation amount");
        }

        // System-wide balance reconciliation
        uint256 totalGasReserved = accounts.length * gasPerTransfer;
        uint256 expectedSystemBalance = initialMasterBalance;
        uint256 actualSystemBalance = vm.addr(MASTER_KEY).balance + CONSOLIDATION_TARGET.balance + totalGasReserved;

        console2.log("\nFinal System State:");
        console2.log("Master Account Balance:", vm.addr(MASTER_KEY).balance);
        console2.log("Consolidation Target Balance:", CONSOLIDATION_TARGET.balance);
        console2.log("Total Gas Reserved:", totalGasReserved);
        console2.log("System Balance Delta:", int256(actualSystemBalance - expectedSystemBalance));

        // Validate perfect system-wide balance conservation
        assertEq(actualSystemBalance, expectedSystemBalance, "System balance conservation violation");

        console2.log("\n=== Lifecycle Test Complete ===");
    }

    function extractAddresses() internal returns (address[] memory) {
        AccountOps.ContractCreatedAccount[] memory contractAccounts = ops.getAccounts();
        address[] memory addrs = new address[](contractAccounts.length);
        for (uint256 i = 0; i < contractAccounts.length; i++) {
            addrs[i] = contractAccounts[i].addr;
        }
        return addrs;
    }
}
