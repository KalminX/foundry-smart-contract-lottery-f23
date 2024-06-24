// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions


// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";


/**
 * @title A sample Raffle Contract
 * @author Numerous Oriabure
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2Plus{
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle_UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 RaffleState);

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    //** State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    VRFConsumerBaseV2Plus private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    //** Events */
    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
        ) VRFConsumerBaseV2Plus(vrfCoordinator){
       i_entranceFee = entranceFee;
       i_interval = interval;
       i_vrfCoordinator = VRFConsumerBaseV2Plus(vrfCoordinator);
       s_lastTimeStamp = block.timestamp;
       i_gasLane = gasLane;
       i_subscriptionId = subscriptionId;
       i_callbackGasLimit = callbackGasLimit;
       s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        // require(msg.sender >= i_entranceFee, "Not enough funds");
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        // Uses of events
        // 1. Makes migration easier
        // 2. Makes front end "indexing"
        emit EnteredRaffle((msg.sender));
    }

    function checkUpkeep(
        bytes memory
    ) public view returns (bool upkeepNeeded, bytes memory /*performData*/) {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle_UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        s_raffleState = RaffleState.CALCULATING;
        // 1. Request the RNG <-
        // 2. Get the random number
        // uint256 requestId = i_vrfCoordinator.requestRandomWords(
        //     i_gasLane, // gas lane
        //     i_subscriptionId,
        //     REQUEST_CONFIRMATIONS,
        //     i_callbackGasLimit,
        //     NUM_WORDS
        // );
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: true})
                )
            })
        );
        emit RequestedRaffleWinner(requestId);
    }

    // CEI
    function fulfillRandomWords(uint256 /* requestId */, uint256[] calldata randomWords) internal override {
        // Checks
        // Effects (Our own contract)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit PickedWinner(winner);
        // Interactions (Other contracts)
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /** Getter Function **/

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getLengthOfPlayers() external view returns(uint256) {
        return s_players.length;
    }

    function getLastTimeStamp() external view returns(uint256) {
        return s_lastTimeStamp;
    }
}