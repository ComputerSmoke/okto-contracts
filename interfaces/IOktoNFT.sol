//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IOktoNFT is IERC721 {
    //Events
    /**
     * Emitted when traits are set for a generation. Useful for community to then check against provenance hash
     * to verify order has not been tampered with.
     */
    event SetTraits(uint8 generation);

    //Actions
    /**
     * Mint NFT, see paper for tokenomics.
     */
    function mint(address _receiver, uint256 seed) external;

    //Views
    /**
     * Access trait encoding array
     */
    function traits(uint256 idx) external view returns(uint256);

    /**
     * Get the encoding of a token's attributes by its ID. 
     * Traits are encoded as follows:
     * Each index corresponds to 42 NFTs, 6 bits for each. The values of the first 4 bits determine the number of traits
     * it has (0-5), and a value of 6-9 indicates that it is a squid with alpha N-1. The last 2 bits determine its rarity,
     * 0 least rare, 2 most rare
     */
    function getTraits(uint256 tokenId) external view returns(uint8);
    /**
     * Range of IDs for each generation, value corresponds to the first ID which will not be in that generation.
     */
    function genMintCaps(uint256 gen) external view returns(uint16);
    /**
     * Get the generation of an NFT based off its current ID.
     */
    function getGen(uint256 tokenId) external view returns(uint8);
    /**
     * Get current generation that is minting, 4 corresponds to all generations having been minted.
     */
    function currentGen() external view returns(uint8);
    /**
     * True if aquarium address has been set. This address should be set before minting commences.
     */
    function aquariumSet() external view returns(bool);
}