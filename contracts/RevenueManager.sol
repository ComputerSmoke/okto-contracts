//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IRevenueManager.sol";
import "../interfaces/IOktoCoin.sol";
import "./libs/Entropy.sol";

//Split revenue from the project amongst dev team
contract RevenueManager is Ownable,IRevenueManager {
    //oktoCoin contract
    IOktoCoin public immutable oktoCoin;
    //Address of dev to pay dev commission to
    address immutable dev1;
    //Balance available to pay out to all devs
    uint256 public override devBalance;
    //Balance available in the lottery
    uint256 public override lotteryBalance;
    //Amount of FTM to be won in lottery
    uint256 public constant lotteryAmount = 10000 ether;
    //Time at which contract was launched
    uint256 public immutable launchTime;
    //true if lottery has been completed or cancelled
    bool public override lotteryComplete;
    //Minimum amount of time for minting before lottery cancelation is possible
    uint256 public constant minGen0Time = 7 days;
    //Index plus one of address in participants array
    mapping(address => uint256) positions;
    //Array of addresses in lottery
    address[] participants;
    //Number of lottery participants
    uint256 numParticipants;
    //Only allow okto coin contract to call this function
    modifier oktoOnly {
        require(msg.sender == address(oktoCoin), "Only okto coin contract can call this function");
        _;
    }

    constructor(address _dev1, address _oktoCoin) Ownable() {
        dev1 = _dev1;
        oktoCoin = IOktoCoin(_oktoCoin);
        launchTime = block.timestamp;
    }

    function mintIncome() external override payable {
        uint256 value = msg.value;
        if(!lotteryComplete && lotteryBalance < 10000 ether) {
            lotteryBalance += value;
            if(lotteryBalance > lotteryAmount) {
                value = lotteryBalance - lotteryAmount;
                devBalance += value;
                lotteryBalance = lotteryAmount;
            } else {
                value = 0;
            }
        }
        devBalance += value;
    }
    //payout to devs
    function payout() external override {
        uint256 dev1Payout = devBalance * 3 / 10;
        uint256 ownerPayout = devBalance - dev1Payout;
        payable(dev1).transfer(dev1Payout);
        payable(owner()).transfer(ownerPayout);
    }

    //Remove/add user from lottery
    function updateLottery(address _user, uint256 _balance) external override oktoOnly {
        if(_user == address(0)) return;
        int256 idx = int256(positions[_user])-1;
        if(_balance < 50000 ether) {
            if(idx != -1) _removeFromLottery(idx);
        } else if(idx == -1) {
            _addToLottery(_user);
        } 
    }
    //Remove user from lottery
    function _removeFromLottery(int256 _idx) internal {
        uint256 idx = uint256(_idx);
        if(numParticipants > 1) participants[idx] = participants[numParticipants-1];
        numParticipants--;
    }
    //Add user to lottery
    function _addToLottery(address _user) internal {
        if(participants.length > numParticipants) {
            participants[numParticipants] = _user;
        } else {
            participants.push(_user);
        }
        numParticipants++;
        positions[_user] = numParticipants;
    }

    //Run FTM lottery after gen0 minting
    function runLottery(uint256 _seed) external override onlyOwner {
        require(!lotteryComplete, "Lottery already run.");
        require(lotteryBalance >= lotteryAmount || block.timestamp - launchTime > minGen0Time, "Gen0 minting not complete.");
        lotteryComplete = true;
        if(lotteryBalance < lotteryAmount || numParticipants == 0) {//Failed to fund lottery or no eligible holders
            devBalance += lotteryBalance;
            lotteryBalance = 0;
            return;
        }
        for(uint i = 0; i < 200; i++) {//Retry for winner until found, odds of hitting 200 fails are like nothing.
            uint256 winIdx = Entropy.random(_seed) % numParticipants;
            address winner = participants[winIdx];
            if(oktoCoin.balanceOf(winner) > 500000 ether || Entropy.random(_seed+i+1) % 10 == 0) {
                payable(winner).transfer(lotteryAmount);
                emit LotteryWinner(winner);
                return;
            }
        }
        revert("Failed to pick winner, please retry.");
    }
}