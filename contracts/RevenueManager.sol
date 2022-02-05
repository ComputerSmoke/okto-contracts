//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IRevenueManager.sol";
import "../interfaces/IOktoCoin.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IRandomOracle.sol";
import "../interfaces/IRandomOracleUser.sol";

import "hardhat/console.sol";

//Split revenue from the project amongst dev team
contract RevenueManager is Ownable,IRevenueManager,IRandomOracleUser {
    //oktoCoin contract
    IOktoCoin public immutable oktoCoin;
    //vault
    IVault public immutable vault;
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
    //Multisig addresses allowed to run lottery
    mapping(address => bool) multisig;
    //Address of randomness oracle
    IRandomOracle randomOracle;
    //Only allow okto coin contract to call this function
    modifier oktoOnly {
        require(msg.sender == address(oktoCoin), "Only okto coin contract can call this function");
        _;
    }
    //Only allow addresses whitelisted for multisig
    modifier onlyMultisig {
        require(multisig[msg.sender], "Only multisig address can call this function");
        _;
    }

    constructor(
        address _dev1, 
        address _oktoCoin, 
        address _vault, 
        address _randomOracle,
        address[] memory _multisig
    ) Ownable() {
        dev1 = _dev1;
        oktoCoin = IOktoCoin(_oktoCoin);
        launchTime = block.timestamp;
        vault = IVault(_vault);
        randomOracle = IRandomOracle(_randomOracle);
        for(uint i = 0; i < _multisig.length; i++) {
            multisig[_multisig[i]] = true;
        }
    }
    //Receive and handle gen0 mint payments
    function mintIncome() external override payable {
        uint256 value = msg.value;
        uint256 vaultPortion;
        if(!lotteryComplete && lotteryBalance < lotteryAmount) {
            lotteryBalance += value;
            if(lotteryBalance > lotteryAmount) {
                value = lotteryBalance - lotteryAmount;
                vaultPortion = value / 5;//20% fee
                devBalance += value - vaultPortion;
                lotteryBalance = lotteryAmount;
                vault.addBacking{value: vaultPortion}();
            }
        } else {
            vaultPortion = value / 5;//20% fee
            devBalance += value - vaultPortion;
            vault.addBacking{value: vaultPortion}();
        }
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
        uint256 idx = positions[_user];
        if(_balance < 50000 ether) {
            if(idx != 0) _removeFromLottery(idx-1);
        } else if(idx == 0) {
            _addToLottery(_user);
        } 
    }
    //Remove user from lottery
    function _removeFromLottery(uint256 _idx) internal {
        positions[participants[_idx]] = 0;
        if(numParticipants > 1) {
            participants[_idx] = participants[numParticipants-1];
            positions[participants[numParticipants-1]] = numParticipants;
        }
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
    function runLottery(uint128 _seed) external override payable onlyMultisig {
        require(!lotteryComplete, "Lottery already run.");
        require(lotteryBalance >= lotteryAmount || block.timestamp - launchTime > minGen0Time, "Gen0 minting not complete.");
        lotteryComplete = true;
        if(lotteryBalance < lotteryAmount || numParticipants == 0) {//Failed to fund lottery or no eligible holders
            
            uint256 vaultPortion = lotteryBalance / 5;//20% fee
            devBalance += lotteryBalance - vaultPortion;
            vault.addBacking{value: vaultPortion}();

            lotteryBalance = 0;
            return;
        }
        randomOracle.requestRandomness{value: msg.value}(_seed);
    }

    //Randomness fulfilled for lottery
    function fulfillRandomness(uint256, uint256 _rand) external override {
        require(msg.sender == address(randomOracle), "Oracle only");
        require(!lotteryComplete, "Lottery already run.");
        console.log("running lottery");
        for(uint i = 0; i < 200; i++) {//Retry for winner until found, odds of hitting 200 fails are like nothing.
            uint256 winIdx = uint256(keccak256(abi.encodePacked(_rand+(i*2)))) % numParticipants;
            address winner = participants[winIdx];
            console.log("winIdx:",winIdx);
            console.log("winnerPrelim:",winner);
            if(oktoCoin.balanceOf(winner) > 500000 ether || uint256(keccak256(abi.encodePacked(_rand+(i*2)+1))) % 10 == 0) {
                payable(winner).transfer(lotteryAmount);
                console.log("winner:",winner);
                emit LotteryWinner(winner);
                return;
            }
        }
        revert("Failed to pick winner, please retry");
    }
}