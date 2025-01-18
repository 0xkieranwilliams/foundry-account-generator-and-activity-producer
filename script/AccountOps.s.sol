// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

contract AccountOps is Script {
   uint256 constant ACCOUNTS_COUNT = 50;
   uint256 constant MIN_TRANSFER = 0.01 ether;
   uint256 constant ACTIVITY_ROUNDS = 5;
   
   struct ContractCreatedAccount {
       address addr;
       uint256 privateKey;
   }

   ContractCreatedAccount[] accounts;
   uint256 masterKey;
   address consolidationTarget;

   function setUp() public {
       masterKey = vm.envUint("MASTER_KEY");
       consolidationTarget = vm.envAddress("CONSOLIDATION_TARGET");
       require(masterKey != 0 && consolidationTarget != address(0), "Invalid setup");
   }

   function genAccounts() public {
       bytes32 masterSeed = keccak256(abi.encodePacked(masterKey, block.chainid));
       
       for (uint256 i; i < ACCOUNTS_COUNT; ++i) {
           uint256 privateKey = uint256(keccak256(abi.encodePacked(masterSeed, i)));
           address addr = vm.addr(privateKey);
           accounts.push(ContractCreatedAccount(addr, privateKey));
           
           console2.log("ContractCreatedAccount[", i, "]:");
           console2.log("  Address:", addr);
           console2.log("  PrivateKey:", privateKey);
       }
   }

   function exportAccounts() public view {
       require(accounts.length == ACCOUNTS_COUNT, "Generate accounts first");
       console2.log("[");
       for (uint256 i; i < accounts.length; ++i) {
           console2.log("{");
           console2.log("  \"index\":", i, ",");
           console2.log("  \"address\":\"", accounts[i].addr, "\",");
           console2.log("  \"privateKey\":\"", vm.toString(accounts[i].privateKey), "\"");
           if (i == accounts.length - 1) {
               console2.log("}");
           } else {
               console2.log("},");
           }
       }
       console2.log("]");
   }

   function getAccounts() public view returns (ContractCreatedAccount[] memory) {
       return accounts;
   }

   function distribute() public {
       require(accounts.length == ACCOUNTS_COUNT, "Generate accounts first");
       vm.startBroadcast(masterKey);

       for (uint256 i; i < accounts.length; ++i) {
           payable(accounts[i].addr).transfer(MIN_TRANSFER);
           vm.warp(block.timestamp + 300 + (uint256(keccak256(abi.encodePacked(i))) % 900));
       }

       vm.stopBroadcast();
   }

   function simulateActivity() public {
       for (uint256 round; round < ACTIVITY_ROUNDS; ++round) {
           for (uint256 i; i < accounts.length; ++i) {
               if (accounts[i].addr.balance >= MIN_TRANSFER / 2) {
                   uint256 targetIdx = uint256(keccak256(abi.encodePacked(round, i))) % accounts.length;
                   
                   vm.startBroadcast(accounts[i].privateKey);
                   payable(accounts[targetIdx].addr).transfer(accounts[i].addr.balance / 2);
                   vm.stopBroadcast();
                   
                   vm.warp(block.timestamp + 1800 + (uint256(keccak256(abi.encodePacked(i, round))) % 3600));
               }
           }
           vm.warp(block.timestamp + 3600);
       }
   }

   function consolidate() public {
       for (uint256 i; i < accounts.length; ++i) {
           uint256 balance = accounts[i].addr.balance;
           if (balance > 0) {
               vm.startBroadcast(accounts[i].privateKey);
               payable(consolidationTarget).transfer(balance);
               vm.stopBroadcast();
           }
       }
   }
}
