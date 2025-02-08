// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DirectFundingConsumer} from "./DirectFundingConsumer.sol";
import {LinkTokenInterface} from "@chainlink/contracts@1.2.0/src/v0.8/shared/interfaces/LinkTokenInterface.sol";

contract Coinflip is Ownable {
    // A mapping of the player to their corresponding requestId.
    mapping(address => uint256) public playerRequestID;
    // A mapping that stores the player's 3 coinflip guesses.
    mapping(address => uint8[3]) public bets;
    // An instance of the random number requestor.
    DirectFundingConsumer private vrfRequestor;

    /// @dev Each Coinflip deployment spawns its own VRF instance.
    constructor() Ownable(msg.sender) {
        vrfRequestor = new DirectFundingConsumer();
        // IMPORTANT: Make sure the DirectFundingConsumer contract’s variable `numWords` is updated to 3.
    }

    /// @notice Funds the VRF instance with 5 LINK tokens.
    /// @return Whether the funding was successful.
    function fundOracle() external returns(bool) {
        // LINK token address (do not change)
        address Link_addr = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
        LinkTokenInterface linkToken = LinkTokenInterface(Link_addr);
        // Amount: 5 LINK tokens (assuming 18 decimals)
        uint256 amount = 5 * 10**18;
        // Transfer 5 LINK tokens from this contract to the VRF instance.
        bool success = linkToken.transfer(address(vrfRequestor), amount);
        return success;
    }

    /// @notice Accepts 3 coinflip guesses (each guess must be 0 or 1) from the user.
    /// @dev Validates input, stores the guesses, and calls the VRF instance to request 3 random words.
    function userInput(uint8[3] memory Guesses) external {
        // Ensure each guess is either 0 or 1.
        require(Guesses[0] <= 1 && Guesses[1] <= 1 && Guesses[2] <= 1, "Guesses must be 0 or 1");
        // Store the player's guesses.
        bets[msg.sender] = Guesses;
        // Request 3 random words from the VRF instance.
        uint256 requestId = vrfRequestor.requestRandomWords(false);
        // Store the requestId corresponding to the player.
        playerRequestID[msg.sender] = requestId;
    }

    /// @notice Returns whether the random number request has been fulfilled.
    function checkStatus() external view returns(bool) {
        uint256 requestId = playerRequestID[msg.sender];
        (, bool fulfilled, ) = vrfRequestor.getRequestStatus(requestId);
        return fulfilled;
    }

    /// @notice Determines if the user won by comparing their guesses to the coinflip outcomes.
    /// @dev Converts each random number into a coinflip result (even -> 0, odd -> 1) and checks against the stored bets.
    /// @return True if the user wins (all outcomes match), false otherwise.
    function determineFlip() external view returns(bool) {
        uint256 requestId = playerRequestID[msg.sender];
        (, bool fulfilled, uint256[] memory randomWords) = vrfRequestor.getRequestStatus(requestId);
        require(fulfilled, "Random numbers not yet fulfilled");
        require(randomWords.length == 3, "Expected 3 random numbers");
        
        uint8[3] memory outcomes;
        for(uint8 i = 0; i < 3; i++){
            outcomes[i] = (randomWords[i] % 2 == 0) ? 0 : 1;
        }
        
        uint8[3] memory playerBets = bets[msg.sender];
        bool win = true;
        for(uint8 i = 0; i < 3; i++){
            if(outcomes[i] != playerBets[i]){
                win = false;
                break;
            }
        }
        return win;
    }
}
