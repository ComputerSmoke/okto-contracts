//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOktoNFT {
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
    function mint() external payable;

    //Owner actions
    /**
     * Traits are encoded as follows:
     * Each index corresponds to 42 NFTs, 6 bits for each. The values of the first 4 bits determine the number of traits
     * it has (0-5), and a value of 6-9 indicates that it is a squid with alpha N-1. The last 2 bits determine its rarity,
     * 0 least rare, 2 most rare
     */
    function setTraitsGen0(uint256[84] memory traits) external;
    function setTraitsGen1(uint256[120] memory traits) external;
    function setTraitsGen2(uint256[239] memory traits) external;
    function setTraitsGen3(uint256[120] memory traits) external;

    //Views
    /**
     * Get the traits by generation. The traits for each generation will be uploaded after the minting period,
     * with provenance hash on launch to verify they have not been tampered with. Traits are encoded as follows:
     * Each index corresponds to 64 NFTs, 4 bits for each. The values of the bits determine the number of traits
     * it has (0-5), and a value of 6-9 indicates that it is a squid with alpha N-1.
     */
    function traitsGen0(uint index) external view returns(uint256);
    function traitsGen1(uint index) external view returns(uint256);
    function traitsGen2(uint index) external view returns(uint256);
    function traitsGen3(uint index) external view returns(uint256);
    /**
     * Provenance hashes by generation to verify authenticity of ordering.
     */
    function traitProvenance(uint generation) external view returns(uint256);
    /**
     * Get the encoding of a token's attributes by its ID. 
     * A value 0-5 corresponds to the number of traits the octopus has.
     * A value of 6-9 corresponds to the alpha level of the squid.
     */
    function getTraits(uint256 tokenId) external view returns(uint8);
}