//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
//TODO
interface IAquarium {
    struct Stake {
        uint256 lastClaimEarned;//Total earned per power level on last claim
        bool staked;//True if currently staked
        bool init;//True if nft has ever been staked
    }
    struct RandomRequest {
        address sender;//Sender of transaction
        bool isMint;//False if for unstake, true otherwise
        uint256 id;//0 if mint, id of token if unstake
    }
    //Emitted when stake rewards claimed
    event Claim(uint256 tokenId, uint256 claimAmount, uint256 taxAmount, bool squid, bool unstaked);
    //Emitted on stake
    event Staked(address owner, uint256 tokenId, uint256 startValue);
    //Emitted on mint
    event Mint(address minter, address receiver, uint256 id);
    //Owner functions
    /**
     * Open minting to non-whitelisted addresses
     */
    function setOpenMint() external;
    //Staking
    /**
     * Stake an octopus or squid. Staking earns rewards proportional to power level, 
     * and based off random stealing for squids.
     * @param _tokenId - ID of token to stake
     */
    function stakeNFT(uint256 _tokenId) external;
    /**
     * Claim rewards from a staked octopus or squid, paying a 20% tax if it is an octopus
     * @param _tokenId - ID of staked token whose rewards are to be collected.
     */
    function claimNFT(uint256 _tokenId) external;
    /**
     * Unstake an octopus or squid, and claim rewards - not paying tax, but having a 50% chance 
     * it's all stolen if it is an octopus.
     * @param _tokenId - ID of token to unstake
     * @param _seed - seed to use for random generation of theft
     */
    function unstakeNFT(uint256 _tokenId, uint128 _seed) external payable;

    //Minting
    /**
     * Mint new octopus or squid from gen 0 as a whitelisted address.
     * @param _seed - seed to use for minting
     * @param _merkleProof - Array of adjacent tree nodes to prove sender is in tree
     * @param _leafNum - Index of leaf containing msg.sender address 0-N, where 0 is leftmost leaf
     */
    function mintWhitelist(
        uint128 _seed, 
        bytes32[] calldata _merkleProof, 
        uint256 _leafNum
    ) external payable;
    /**
     * Mint a new octopus or squid with FTM from generation 0
     * @param _seed - seed to use for minting
     */
    function mintGen0(uint128 _seed) external payable;
    /**
     * Mint new octopus or squid from gens 1-3 using $Okto
     * @param _seed - seed to use for minting
     */
    function mintGenX(uint128 _seed) external payable;

    //Pure
    /**
     * Gives the power level of a squid/octopus with the passed traits
     * @param traits - encoding of traits, lowest 4 bits represent features for octopuses and alphas for squids,
     *  next 2 bits represent rarity.
     */
    function powerLevel(uint8 traits) external pure returns (uint8);

    //Views
    //$Okto contract address
    function oktoCoinAddress() external view returns(address);
    //Revenue manager contract address
    function revenueManagerAddress() external view returns(address);
    //NFT contract address
    function oktoNFTAddress() external view returns(address);

    //How many $okto earned per octopus power level per day
    function dailyMintRate() external view returns(uint256);
    //Percentage of okto which goes to squids when okto claimed.
    function claimTax() external view returns(uint256);
    //Percentage chance that all okto goes to squids when octopus unstaked.
    function unstakeRisk() external view returns(uint256);
    //Max supply of okto
    function maxOkto() external view returns(uint256);
    //Max power of a squid
    function maxSquidPower() external view returns(uint8);

    //Total okto earned per octopus power level
    function oktoEarned() external view returns(uint256);
    //Total power level of staked octopi
    function octoPowerStaked() external view returns(uint256);
    //Total amount of octo earned for staking
    function totalOktoEarned() external view returns(uint256);
    
    //Total okto stolen per squid alpha level
    function oktoStolen() external view returns(uint256);
    //Total power level of staked squids
    function squidPowerStaked() external view returns(uint256);

    //Last time okto was claimed
    function lastClaimTimestamp() external view returns(uint256);

    //Array of squid IDs used to randomly select stealer of NFT.
    //NFTs not considered for this until they have been staked once.
    function squids(uint256 index) external view returns(uint256);
    //Cost of minting NFT with FTM
    function mintCost() external view returns(uint256);
    //Cost of minting with Okto
    function oktoMintCost() external view returns(uint256);

    //False if only whitelist can mint
    function openMint() external view returns(bool);

    //Stake info by id
    function stakes(uint256 id) external view returns(uint256 lastClaimEarned, bool staked, bool init); 
}