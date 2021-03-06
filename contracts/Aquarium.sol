//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IOktoCoin.sol";
import "../interfaces/IRevenueManager.sol";
import "../interfaces/IOktoNFT.sol";
import "../interfaces/IAquarium.sol";
import "../interfaces/IRandomOracleUser.sol";
import "../interfaces/IRandomOracle.sol";

import "hardhat/console.sol";

//Mint/stake contract for okto NFTs
contract Aquarium is ERC721Holder,IAquarium,Ownable,IRandomOracleUser {
    //ERC20 token contract
    IOktoCoin immutable oktoCoin;
    //Handles payouts to dev team
    IRevenueManager immutable revenueManager;
    //ERC721 NFT contract
    IOktoNFT immutable oktoNFT;
    
    //Base amount okto earned per day for staking per power level of the oktopus.
    uint256 public override constant dailyMintRate = 10000 ether;
    //Percentage of okto which goes to squids when okto claimed.
    uint256 public override constant claimTax = 20;
    //Percentage chance that all okto goes to squids when octopus unstaked.
    uint256 public override constant unstakeRisk = 50;
    //Max supply of okto
    uint256 public override constant maxOkto = 5000000000 ether;
    //Max power of a squid
    uint8 public override constant maxSquidPower = 24;

    //Total okto earned per octopus power level
    uint256 public override oktoEarned;
    //Total power level of staked octopi
    uint256 public override octoPowerStaked;
    //Total rewards given to staked octopi
    uint256 public override totalOktoEarned;
    
    //Total okto stolen per squid power level
    uint256 public override oktoStolen;
    //Total power level of staked squids
    uint256 public override squidPowerStaked;

    //Last time okto was claimed
    uint256 public override lastClaimTimestamp;

    //Token ID to stake data
    mapping(uint256 => Stake) public override stakes;
    //Array of squid IDs used to randomly select stealer of NFT.
    //NFTs not considered for this until they have been staked once.
    uint256[] public override squids;
    //Cost of minting NFT gen0 (FTM)
    uint256 public override constant mintCost = 50 ether;
    //Cost of minting NFT gen1-3 (okto)
    uint256 public override constant oktoMintCost = 100000 ether;

    //Reentrancy lock on mint function
    bool mintLock;
    //False if only whitelist can mint
    bool public override openMint;
    //Root of whitelist merkle tree 
    bytes32 public immutable merkleRoot;

    //Mints pending randomness fulfillment
    mapping(uint256 => RandomRequest) pendingRandom;
    //Number of mints pending randomness fulfillment
    uint256 pendingMintCount;
    //Randomness oracle
    IRandomOracle randomOracle;
    
    //Total number of free mints used (for marketing)
    uint256 freeMintsUsed;
    //Max number of free mints available (for marketing)
    uint256 constant maxFreeMints = 275;

    //Require that msg.sender own the token, and generation is active
    modifier onlyTokenOwner(uint256 _tokenId) {
        require(oktoNFT.ownerOf(_tokenId) == msg.sender, "Message sender does not own this token");
        _;
    }
    //Update total earnings based off current time
    modifier updateEarnings() {
        if(block.timestamp > lastClaimTimestamp) {
            uint256 delta = (block.timestamp - lastClaimTimestamp) * dailyMintRate / 1 days;
            oktoEarned += delta;
            totalOktoEarned += delta*octoPowerStaked;
            if(totalOktoEarned > maxOkto) {
                oktoEarned -= (totalOktoEarned - maxOkto) / octoPowerStaked;
                totalOktoEarned = maxOkto;
            }
            lastClaimTimestamp = block.timestamp;
        } else console.log("insufficient earnings time");
        _;
    }
    //Only random oracle, for fulfillment of randomness:
    modifier onlyRandomOracle() {
        require(msg.sender == address(randomOracle));
        _;
    }
    //Verify merkle proof of whitelist
    modifier verifyProof (
        uint128 _seed, 
        bytes32[] calldata _merkleProof, 
        uint256 _leafNum
    ) {
        //Verify merkle proof
        bytes32 lastNode = bytes32(bytes20(msg.sender));
        unchecked {
            for(uint256 i = 0; i < _merkleProof.length; i++) {
                //Reading bits from lowest to highest tells us if leaf merges left or right this step
                bool right = (_leafNum >> i) == 1;
                lastNode = (right ? 
                    keccak256(abi.encodePacked(_merkleProof[i], lastNode)) : 
                    keccak256(abi.encodePacked(lastNode, _merkleProof[i]))
                );
            }
        }
        require(lastNode == merkleRoot, "Invalid merkle proof");
        _;
    }

    constructor(
        address _oktoNFT,
        address _oktoCoin,
        address _revenueManager,
        address _randomOracle,
        bytes32 _merkleRoot
    ) Ownable() {
        oktoCoin = IOktoCoin(_oktoCoin);
        revenueManager = IRevenueManager(_revenueManager);
        oktoNFT = IOktoNFT(_oktoNFT);
        randomOracle = IRandomOracle(_randomOracle);
        lastClaimTimestamp = block.timestamp;
        merkleRoot = _merkleRoot;
    }
    
    //Stake squid or octo
    function stakeNFT(
        uint256 _tokenId
    ) public override onlyTokenOwner(_tokenId) {
        Stake storage stake = stakes[_tokenId];
        require(!stake.staked, "Token is already staked.");
        uint8 traits = oktoNFT.getTraits(_tokenId);
        bool squid = traits & 0xf > 5;//Squid if first 4 bits of traits > 5.
        if(squid) {
            if(!stake.init) {
                squids.push(_tokenId);//Add to squids array if not already in array
            }
            squidPowerStaked += powerLevel(traits);
        } else {
            octoPowerStaked += powerLevel(traits);
        }
        
        stake.init = true;
        //Stake
        stake.lastClaimEarned = squid ? oktoStolen : oktoEarned;
        stake.staked = true;
        emit Staked(msg.sender, _tokenId, stake.lastClaimEarned);
    }
    //Stake multiple NFTs in one transaction
    function stakeBatch(
        uint256[] calldata _tokenIds
    ) external override {
        for(uint256 i = 0; i < _tokenIds.length; i++) stakeNFT(_tokenIds[i]);
    }

    //Claim rewards from squid or octo
    function claimNFT(
        uint256 _tokenId
    ) public override onlyTokenOwner(_tokenId) {
        require(stakes[_tokenId].staked, "Token is not staked.");
        (uint256 claimAmount, uint256 taxAmount, bool squid,) = _claim(_tokenId, false, 0);
        emit Claim(_tokenId, claimAmount, taxAmount, squid, false);
    }
    //Claim rewards for multiple NFTs in one transaction
    function claimBatch(uint256[] calldata _tokenIds) external override {
        for(uint256 i = 0; i < _tokenIds.length; i++) claimNFT(_tokenIds[i]);
    }

    //Unstake and claim rewards from squid or octo
    function unstakeNFT(
        uint256 _tokenId, 
        uint128 _seed
    ) external override payable onlyTokenOwner(_tokenId) {
        require(stakes[_tokenId].staked, "Token is not staked.");
        uint256 id = randomOracle.requestRandomness{value: msg.value}(_seed);
        pendingRandom[id] = RandomRequest(msg.sender, false, _tokenId);
    }
    //Unstake and claim rewards for multiple NFTs at once
    function unstakeBatch(
        uint256[] calldata _tokenIds, 
        uint128 _seed
    ) external override payable {
        for(uint256 i = 0; i < _tokenIds.length; i++) {
            require(stakes[_tokenIds[i]].staked, "Token is not staked.");
            uint256 id = randomOracle.requestRandomness{value: msg.value / _tokenIds.length}(_seed);
            pendingRandom[id] = RandomRequest(msg.sender, false, _tokenIds[i]);
        }
    }

    /**
     * @param _tokenId - ID of token to stake
     * @param _risk - true if risking (unstaking)
     * @param _rand - random number from oracle
     * @return uint256 - amount claimed
     * @return uint256 - tax amount
     * @return bool - true if token was squid
     */
    function _claim(
        uint256 _tokenId, 
        bool _risk, 
        uint256 _rand
    ) internal updateEarnings returns(uint256, uint256, bool, uint8) {
        Stake storage stake = stakes[_tokenId];
        require(stake.staked, "Token is not staked.");

        uint8 traits = oktoNFT.getTraits(_tokenId);

        uint256 tax;
        if(squidPowerStaked == 0 || (traits & 0xf) > 5) tax = 0;//If no squids staked, tax is always 0
        else if(!_risk) tax = claimTax;
        else if(_rand % 100 < unstakeRisk) tax = 100;

        uint256 totalEarned = ((traits & 0xf) > 5) ? oktoStolen : oktoEarned;
        uint256 claimAmount = (totalEarned - stake.lastClaimEarned) * powerLevel(traits);
        tax = claimAmount * tax / 100;//taxAmount
        stake.lastClaimEarned = totalEarned;
        if(squidPowerStaked > 0) oktoStolen += tax / squidPowerStaked;

        oktoCoin.mint(oktoNFT.ownerOf(_tokenId), claimAmount - tax);

        return (claimAmount, tax, ((traits & 0xf) > 5), powerLevel(traits));
    }

    //Mint
    function mintWhitelist(
        uint128 _seed, 
        bytes32[] calldata _merkleProof, 
        uint256 _leafNum
    ) external override payable verifyProof(_seed, _merkleProof, _leafNum) {
        require(msg.value >= mintCost, "Insufficient transfer value");
        require(oktoNFT.currentGen() == 0, "Active generation is not 0, use mintGenX");
        _mint(_seed, msg.sender);
        revenueManager.mintIncome{value: msg.value - 0.5 ether}();
    }
    function mintWhitelistBatch(
        uint128 _seed, 
        bytes32[] calldata _merkleProof, 
        uint256 _leafNum,
        uint256 _mintNum
    ) external override payable verifyProof(_seed, _merkleProof, _leafNum) {
        require(msg.value >= mintCost * _mintNum, "Insufficient transfer value");
        for(uint256 i = 0; i < _mintNum; i++) {
            require(oktoNFT.currentGen() == 0, "Active generation is not 0, use mintGenX");
            _mint(_seed, msg.sender);
        }
        revenueManager.mintIncome{value: msg.value - (0.5 ether * _mintNum)}();
    }
    //Mint from gen 0 not on whitelist
    function mintGen0(uint128 _seed) public override payable {
        require(msg.value >= mintCost, "Insufficient transfer value");
        require(oktoNFT.currentGen() == 0, "Active generation is not 0, use mintGenX");
        _mint(_seed, msg.sender);
        revenueManager.mintIncome{value: msg.value - 0.5 ether}();
    }
    //Mint multiple from gen0 in one transaction
    function mintGen0Batch(uint128 _seed, uint256 _mintNum) external override payable {
        require(msg.value >= mintCost*_mintNum, "Insufficient transfer value");
        for(uint256 i = 0; i < _mintNum; i++) {
            require(oktoNFT.currentGen() == 0, "Active generation is not 0, use mintGenX");
            _mint(_seed, msg.sender);
        }
        revenueManager.mintIncome{value: msg.value - (0.5 ether * _mintNum)}();
    }
    //Mint gens 1-3
    function mintGenX(uint128 _seed) external override payable {
        require(!mintLock, "Reentrancy lock is active");
        require(oktoNFT.currentGen() > 0, "Active generation is 0, use mintGen0");
        mintLock = true;
        _mint(_seed, msg.sender);
        oktoCoin.burn(msg.sender, oktoMintCost);
        mintLock = false;
    }
    //Mint multiple from gens 1-3
    function mintGenXBatch(uint128 _seed, uint256 _mintNum) external override payable {
        require(!mintLock, "Reentrancy lock is active");
        mintLock = true;
        for(uint256 i = 0; i < _mintNum; i++) {
            require(oktoNFT.currentGen() > 0, "Active generation is 0, use mintGen0");
            _mint(_seed, msg.sender);
        }
        oktoCoin.burn(msg.sender, oktoMintCost * _mintNum);
        mintLock = false;
    }
    //Do a free mint for marketing (airdrop)
    function freeMint(uint128 _seed, address _receiver) external override onlyOwner {
        require(freeMintsUsed < maxFreeMints, "All free mints used");
        _mint(_seed, _receiver);
    }
    //Internal minting function
    function _mint(uint128 _seed, address _sender) internal {
        require(oktoNFT.remainingToMint() - pendingMintCount > 0, "This generation has been fully minted");
        require(msg.value >= 0.5 ether, "Insufficient transfer amount for randomness");
        uint256 id = randomOracle.requestRandomness{value: 0.5 ether}(_seed);
        pendingMintCount++;
        pendingRandom[id] = RandomRequest(_sender, true, 0);
    }
    //On randomness fulfilled
    function fulfillRandomness(uint256 _id, uint256 _rand) external override onlyRandomOracle {
        RandomRequest storage randomRequest = pendingRandom[_id];
        require(randomRequest.sender != address(0), "request does not exist");
        address sender = randomRequest.sender;
        randomRequest.sender = address(0);
        randomRequest.isMint ? 
            _completeMint(sender, _rand) : 
            _completeUnstake(randomRequest.id, _rand);
    }
    //Complete minting process when randomness received
    function _completeMint(address _sender, uint256 _rand) internal {
        //Use random number like a seed
        uint256 num = uint256(keccak256(abi.encodePacked(_rand)));
        bool stolen = num % 10 == 0;
        address receiver;
        if(squids.length > 0 && stolen) {
            receiver = oktoNFT.ownerOf(randomSquid(num));
            num = uint256(keccak256(abi.encodePacked(_rand+1)));
        }
        else receiver = _sender;
        uint256 id = oktoNFT.mint(receiver, _rand);
        pendingMintCount--;
        emit Mint(_sender, receiver, id);
    }
    //Complete unstake process when randomness received
    function _completeUnstake(uint256 _tokenId, uint256 _rand) internal {
        (uint256 claimAmount, uint256 taxAmount, bool squid, uint8 power) = _claim(_tokenId, true, _rand);
        stakes[_tokenId].staked = false;
        squid ? squidPowerStaked -= power : octoPowerStaked -= power;//reduce power staked by amount
        emit Claim(_tokenId, claimAmount, taxAmount, squid, true);
    }

    //Get a random squid, weighted by alpha level
    function randomSquid(uint256 _rand) internal view returns(uint256) {
        uint256 numSquids = squids.length;
        require(numSquids > 0, "No squids to choose from.");
        //Loop until we decide to keep the squid we land on. If all squids have min power, we expect about 5 iterations.
        //Stop if we somehow reach 200 iterations, which is orders of magnitude less likely than being hit by lightning tomorrow.
        for(uint i = 0; i < 200; i++) {
            uint256 tokenId = squids[uint256(keccak256(abi.encodePacked(_rand+i*2))) % numSquids];
            uint8 power = powerLevel(oktoNFT.getTraits(tokenId));
            //Keep this token with likelyhood proportional to its power level, giving those with higher power
            //proportionally higher chance of being chosen.
            if(uint256(keccak256(abi.encodePacked(_rand+i*2+1))) % maxSquidPower < power) return tokenId;
        }
        revert("Failed to pick squid");
    }

    //Open minting to all, not just whitelist
    function setOpenMint() external override onlyOwner {
        openMint = true;
    }

    //Get the power level of an octopus or squid based off its traits. This determines how efficiently they collect stakes.
    function powerLevel(uint8 traits) public override pure returns(uint8) {
        bool squid = traits & 0xf > 5;//Squid if first 4 bits of traits > 5.
        uint8 rarity = traits >> 4;
        /*Min/Max powers
        Squid: Min: 5 Max: 24
        Octo: Min: 5 Max: 30
        */
        return (squid ? (traits & 0xf) - 1 : (traits & 0xf) + 5) * (rarity+1);
    }
    
    //$Okto contract address
    function oktoCoinAddress() external override view returns(address) {
        return address(oktoCoin);
    }
    //Revenue manager contract address
    function revenueManagerAddress() external override view returns(address) {
        return address(revenueManager);
    }
    //NFT contract address
    function oktoNFTAddress() external override view returns(address) {
        return address(oktoNFT);
    }
}