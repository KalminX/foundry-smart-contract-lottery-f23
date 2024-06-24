// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        (,,address vrfCoordinator,,,,,uint256 deployerKey) = helperConfig.activeNetworkConfig();
        return createSubscription(vrfCoordinator, deployerKey);
    }

    function createSubscription(
        address vrfCoordinator,
        uint256 deployerKey
    ) public returns (uint256, address) {
        console.log("Creating subscription", block.chainid);
        vm.startBroadcast(deployerKey);
        uint256 subId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
        uint64 sub_id = uint64(subId);
        console.log("Your sub id is", subId);
        vm.stopBroadcast();
        console.log("Your sub Id: ", subId);
        return (sub_id, vrfCoordinator);
    }

    function run() external returns (uint256, address) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (,,address vrfCoordinator,, uint64 subId,, address link, uint256 deployerKey) = helperConfig.activeNetworkConfig();
        fundSubscription(vrfCoordinator, subId, link, deployerKey);
    }

    function fundSubscription(address vrfCoordinator, uint256 subId, address link, uint256 deployerKey) public {
        console.log("Funding subscription: ", subId);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainID: ", block.chainid);
        if (block.chainid == 31337){
            vm.startBroadcast(deployerKey);
            uint64 sub_Id = uint64(subId);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(sub_Id, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            console.log(LinkToken(link).balanceOf(msg.sender));
            console.log(msg.sender);
            console.log(LinkToken(link).balanceOf(address(this)));
            console.log(address(this));
            vm.startBroadcast(deployerKey);
            LinkToken(link).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subId));
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(address raffle, address vrfCoordinator, uint64 subId, uint256 deployerKey) public {
        console.log("Adding consumer to raffle: ", raffle);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainID: ", block.chainid);
        vm.startBroadcast(deployerKey);
        uint64 sub_Id = uint64(subId);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(sub_Id, raffle);
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address raffle) public {
        HelperConfig helperConfig = new HelperConfig();
        (,,address vrfCoordinator,, uint256 subId,,, uint256 deployerKey) = helperConfig.activeNetworkConfig();
        uint64 sub_Id = uint64(subId);
        addConsumer(raffle, vrfCoordinator, sub_Id, deployerKey);
    }

    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(raffle);
    }
}