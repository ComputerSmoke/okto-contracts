//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IOktoNFT.sol";

contract OktoNFT is ERC721Enumerable,Ownable,IOktoNFT {
    /*Each entry holds the number traits for 80 NFTs with 3 bits each.
    Values 0-5 correspond to number of traits, the power level of this NFT.
    A value of 6 correponds to a squid.*/
    uint240[44] public traitsGen0;
    uint240[63] public traitsGen1;
    uint240[125] public traitsGen2;
    uint240[63] public traitsGen3;
    //Provenance hashes for generation traits
    uint256[4] public traitProvenance;
    //baseURI of metadata by generation
    bytes32 immutable URIGen0;
    bytes32 immutable URIGen1;
    bytes32 immutable URIGen2;
    bytes32 immutable URIGen3;

    constructor(
        uint256[4] memory _traitProvenance
    ) ERC721("Okto", "OKT") {
        for(uint i = 0; i < 4; i++) {
            traitProvenance[i] = _traitProvenance[i];
        }
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI;
        if(tokenId < 3500) baseURI = "";//TODO: gen0 URI
        else if(tokenId < 8500) baseURI = "";//TODO: gen1 URI
        else if(tokenId < 18500) baseURI = "";//TODO: gen2 URI
        else baseURI = "";//TODO: gen3 URI
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    //Set generation traits. Should be done once per gen after mints and is verifiable by provenance hashes.
    function setTraitsGen0(uint240[44] memory _traits) external onlyOwner {
        for(uint i = 0; i < 44; i++) traitsGen0[i] = _traits[i];
        emit SetTraits(0);
    }
    function setTraitsGen1(uint240[63] memory _traits) external onlyOwner {
        for(uint i = 0; i < 44; i++) traitsGen1[i] = _traits[i];
        emit SetTraits(1);
    }
    function setTraitsGen2(uint240[125] memory _traits) external onlyOwner {
        for(uint i = 0; i < 44; i++) traitsGen2[i] = _traits[i];
        emit SetTraits(2);
    }
    function setTraitsGen3(uint240[63] memory _traits) external onlyOwner {
        for(uint i = 0; i < 44; i++) traitsGen3[i] = _traits[i];
        emit SetTraits(3);
    }

}