/* Copyright 2022 Andrey Novikov

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License. */


// SPDX-License-Identifier: MIT

/*_________________________________________CRYPTOTRON_________________________________________*/

pragma solidity ^0.8.10;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "hardhat/console.sol";
import "./CryptoFlipperTicket.sol";

interface CryptoTicketInterface {
    function ownerOf(uint256 tokenId) external view returns (address);
    function sold() external view returns (uint256 ammount);
}

error CryptoFlipper__OwnerFailure();
error CryptoFlipper__TransferFailure();
error CryptoFlipper__OwnerRightsFailure();
error CryptoFlipper__DetectedFailure();
error CryptoFlipper__ZeroingFailure();

contract CryptoFlipper is VRFConsumerBaseV2 {

    enum cryptoFlipState {
        OPEN,
        CALCULATING
    }

    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    cryptoFlipState private s_cryptoFlipState;
    bytes32 private immutable i_gasLane;
    uint256 private s_lastTimeStamp;
    uint256 private recentResult;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUM_WORDS = 1;
    uint16 private constant REQUEST_CONFIRMATIONS = 4;
    address payable public immutable owner;
    address private currentContract;
    address payable private headsPlayer;
    address payable private tailsPlayer;
    address payable private winner;
    address private immutable nullAddress = address(0x0);
    address private s_recentWinner;
    address[] private s_allWinners;
    address[] private s_funders;
    address[] private deprecatedContracts;
    bool private failure = false;

    event HeadsEnter(address indexed headsPlayer);
    event TailsEnter(address indexed tailsPlayer);
    event WinnerPicked(address indexed winner);
    event RequestedCryptoFlipWinner(uint256 indexed requestId);
    event AddressChanged(address indexed newAddress);
    event NewFunder(address indexed funder);

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert CryptoFlipper__OwnerRightsFailure();
        }
        _;
    }

    modifier checkFailure() {
        if (failure != false) {
            revert CryptoFlipper__DetectedFailure();
        }
        _;
    }

    modifier contractRestriction() {
        if (currentContract != nullAddress) {
            revert CryptoFlipper__ZeroingFailure();
        }
        _;
    }

    constructor(
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        address vrfCoordinatorV2
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_cryptoFlipState = cryptoFlipState.OPEN;
        s_lastTimeStamp = block.timestamp;
        owner = payable(msg.sender);
        currentContract = nullAddress;
    }

    function changeAddress(address newAddress) public onlyOwner checkFailure contractRestriction {
        currentContract = newAddress;
        emit AddressChanged(newAddress);
    }

    function fundCryptotron() public payable checkFailure {
        s_funders.push(payable(msg.sender));
        emit NewFunder(msg.sender);
    }

    function enterFlipper(uint256 tokenId) public {
        CryptoTicketInterface cti = CryptoTicketInterface(currentContract);
        if (cti.ownerOf(tokenId) != msg.sender) {
            revert CryptoFlipper__OwnerRightsFailure();
        } else if (tokenId == 0) {
            headsPlayer = payable(msg.sender);
            emit HeadsEnter(msg.sender);
        } else if (tokenId % 2 == 0) {
            headsPlayer = payable(msg.sender);
            emit HeadsEnter(msg.sender);
        } else {
            tailsPlayer = payable(msg.sender);
            emit TailsEnter(msg.sender);
        }
        flip();
    }

    function flip() internal {
        s_cryptoFlipState = cryptoFlipState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestedCryptoFlipWinner(requestId);
    }

    function fulfillRandomWords(
        uint256, 
        uint256[] memory randomWords
    ) internal override {
        uint256 headsOrTails = randomWords[0] % 2;
        recentResult = headsOrTails;
        if (headsOrTails == 0) {
            winner = headsPlayer;
        } else {
            winner = tailsPlayer;
        }
        s_recentWinner = winner;
        s_allWinners.push(winner);
        deprecatedContracts.push(currentContract);
        currentContract = nullAddress;
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            failure = true;
            revert CryptoFlipper__TransferFailure();
        }
        s_lastTimeStamp = block.timestamp;
        s_cryptoFlipState = cryptoFlipState.OPEN;
        emit WinnerPicked(winner);
    }

    function getLastFlip() public view returns (string memory) {
        if (recentResult == 0) {
            return "Heads";
        } else {
            return "Tails";
        }
    }

    function getCryptoFlipBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getCurrentContract() public view returns (address) {
        return currentContract;
    }

    function getDeprecatedContracts() public view returns (address[] memory) {
        return deprecatedContracts;
    }

    function getCryptoFlipState() public view returns (cryptoFlipState) {
        return s_cryptoFlipState;
    }

    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getLastTimestamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getWinners() public view returns (address[] memory) {
        return s_allWinners;
    }

    function isFailed() public view returns (bool) {
        return failure;
    }

}