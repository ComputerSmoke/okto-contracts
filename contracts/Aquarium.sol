//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "./OktoCoin.sol";
import "./RevenueManager.sol";
import "../interfaces/IOktoNFT.sol";
import "../interfaces/IAquarium.sol";

//Mint/stake contract for okto NFTs
contract Aquarium is ERC721Holder,IAquarium {
    //ERC20 token contract
    OktoCoin public immutable oktoCoin;
    //Handles payouts to dev team
    RevenueManager public immutable revenueManager;
    //ERC721 NFT contract
    IOktoNFT public immutable oktoNFT;
    
    //Base amount okto earned per day for staking per power level of the oktopus.
    uint256 public constant dailyMintRate = 10000 ether;
    //Percentage of okto which goes to squids when okto claimed.
    uint256 public constant claimTax = 20;
    //Percentage chance that all okto goes to squids when octopus unstaked.
    uint256 public constant unstakeRisk = 50;
    //Max supply of okto
    uint256 public constant maxOkto = 5000000000 ether;
    //Max power of a squid
    uint8 public constant maxSquidPower = 24;

    //Total okto earned per octopus power level
    uint256 public oktoEarned;
    //Total power level of staked octopi
    uint256 public octoPowerStaked;
    
    //Total okto stolen per squid alpha level
    uint256 public oktoStolen;
    //Total power level of staked squids
    uint256 public squidPowerStaked;

    //Last time okto was claimed
    uint256 public lastClaimTimestamp;

    //Token ID to stake data
    mapping(uint256 => Stake) stakes;
    //Array of squid IDs used to randomly select stealer of NFT.
    //NFTs not considered for this until they have been staked once.
    uint256[] public squids;
    //Cost of minting NFT
    uint256 public constant mintCost = 25 ether;

    //Require that msg.sender own the token
    modifier onlyTokenOwner(uint256 _tokenId) {
        require(oktoNFT.ownerOf(_tokenId) == msg.sender, "Message sender does not own this token");
        _;
    }
    //Do not let tokens be staked until timestamp exceeds last timestamp, protection against block timestamp manipulation.
    modifier noTimetravel() {
        require(block.timestamp > lastClaimTimestamp, "Block timestamp too low, please wait a bit.");
        _;
    }
    //Update total earnings based off current time
    modifier updateEarnings() {
        oktoEarned += (block.timestamp - lastClaimTimestamp) * dailyMintRate / 1 days;
        lastClaimTimestamp = block.timestamp;
        _;
    }

    constructor(
        uint256 _totalOkto, 
        address _dev1,
        address _oktoNFT
    ) {
        oktoCoin = new OktoCoin(_totalOkto);
        revenueManager = new RevenueManager(_dev1, msg.sender);
        oktoNFT = IOktoNFT(_oktoNFT);
    }
    
    //Staking
    function stakeNFT(uint256 _tokenId) external onlyTokenOwner(_tokenId) noTimetravel {
        uint8 traits = oktoNFT.getTraits(_tokenId);
        bool squid = traits & 0xf > 5;//Squid if first 4 bits of traits > 5.
        Stake storage stake = stakes[_tokenId];
        if(!stake.init) {
            squids.push(_tokenId);//Add to squids array if not already in array
            stake.init = true;
        }
        //Stake
        stake.lastClaimEarned = squid ? oktoStolen : oktoEarned;
        stake.staked = true;
    }
    function claimNFT(uint256 _tokenId) external onlyTokenOwner(_tokenId) noTimetravel {
        _claim(_tokenId, false, 0);
    }
    function unstake(uint256 _tokenId, uint256 _seed) external onlyTokenOwner(_tokenId) noTimetravel {
        _claim(_tokenId, true, _seed);
        stakes[_tokenId].staked = false;
    }
    function _claim(uint256 _tokenId, bool _risk, uint256 _seed) internal updateEarnings {
        Stake storage stake = stakes[_tokenId];
        require(stake.staked, "Token is not staked.");

        uint8 traits = oktoNFT.getTraits(_tokenId);
        bool squid = traits & 0xf > 5;//Squid if first 4 bits of traits > 5.

        uint256 tax;
        if(squidPowerStaked == 0) tax = 0;//If no squids staked, tax is always 0
        else if(!_risk) tax = claimTax;
        else if(_random(_seed) % 100 < unstakeRisk) tax = 100;

        uint256 totalEarned = squid ? oktoStolen : oktoEarned;
        uint256 claimAmount = (totalEarned - stake.lastClaimEarned) * powerLevel(traits);
        uint256 taxAmount = claimAmount * tax / 100;
        stake.lastClaimEarned = totalEarned;
        if(squidPowerStaked > 0) oktoStolen += taxAmount / squidPowerStaked;
        oktoCoin.mint(oktoNFT.ownerOf(_tokenId), claimAmount - taxAmount);
    }

    //Mint
    function mint(uint256 _seed) external payable {
        require(msg.value >= mintCost, "Insufficient transfer value");
        bool stolen = _random(_seed) % 10 == 0;
        address receiver;
        if(squids.length > 0 && stolen) receiver = oktoNFT.ownerOf(randomSquid(_seed+1));
        else receiver = msg.sender;
        oktoNFT.mint(receiver);
        revenueManager.mintIncome{value: msg.value}();
    }

    //Get a random squid, weighted by alpha level
    function randomSquid(uint256 _seed) internal view returns(uint256) {
        uint256 numSquids = squids.length;
        require(numSquids > 0, "No squids to choose from.");
        //Loop until we decide to keep the squid we land on. If all squids have min power, we expect about 5 iterations.
        //Stop if we somehow reach 200 iterations, which is orders of magnitude less likely than being hit by lightning tomorrow.
        for(uint i = 0; i < 200; i++) {
            uint256 tokenId = squids[_random(_seed+i*2) % numSquids];
            uint8 power = powerLevel(oktoNFT.getTraits(tokenId));
            //Keep this token with likelyhood proportional to its power level, giving those with higher power
            //proportionally higher chance of being chosen.
            if(_random(_seed+i*2+1) % maxSquidPower < power) return tokenId;
        }
        revert("Failed to pick squid");
    }

    //Get the power level of an octopus or squid based off its traits. This determines how efficiently they collect stakes.
    function powerLevel(uint8 traits) public pure returns(uint8) {
        bool squid = traits & 0xf > 5;//Squid if first 4 bits of traits > 5.
        uint8 rarity = traits >> 4;
        /*Min/Max powers
        Squid: Min: 5 Max: 24
        Octo: Min: 5 Max: 30
        */
        return (squid ? (traits & 0xf) - 1 : (traits & 0xf) + 5) * (rarity+1);
    }

    //Get pseudo random number
    function _random(uint256 _seed) internal view returns(uint256) {
        return uint256(keccak256(abi.encodePacked(
            msg.sender,
            tx.origin,
            blockhash(block.number - 1),
            block.timestamp,
            _seed
        )));
    }
    
}