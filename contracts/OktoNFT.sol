//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IOktoNFT.sol";
import "../interfaces/IAquarium.sol";

import "./libs/Entropy.sol";
import "hardhat/console.sol";

contract OktoNFT is ERC721Enumerable,Ownable,IOktoNFT {
    /**
     * Traits are encoded as follows:
     * Each index corresponds to 42 NFTs, 6 bits for each. The values of the first 4 bits determine the number of traits
     * it has (0-5), and a value of 6-9 indicates that it is a squid with alpha N-1. The last 2 bits determine its rarity,
     * 0 least rare, 2 most rare
     */
    uint256[655] public override traits;
    //Current 
    uint16[4] public override genMintCaps;
    //Current generation
    uint8 public override currentGen;
    //Aquarium with perms to mint
    IAquarium aquarium;
    //True after aquarium has been set, preventing it from changing
    bool public override aquariumSet;
    //track minted IDs by pointing to the id which replaces them, and keeping track of number of ids
    mapping(uint256 => uint256) idReplacements;
    //remaining to mint this generation
    uint16 public override remainingToMint;

    //Only allow aquarium to call this
    modifier onlyAquarium() {
        require(msg.sender == address(aquarium));
        _;
    }

    constructor(
        uint256[655] memory _traits
    ) ERC721("Okto", "OKT") Ownable() {
        genMintCaps = [5000, 15000, 22500, 27500];
        remainingToMint = genMintCaps[0];
        for(uint i = 0; i < 655; i++) traits[i] = _traits[i];
    }
    //Set aquarium pointer
    function setAquarium(address _aquarium) external onlyOwner {
        require(address(aquarium) == address(0), "Aquarium already set.");
        aquarium = IAquarium(_aquarium);
    }
    //Mint NFT
    function mint(address _recipient, uint256 _seed) external override onlyAquarium returns(uint256) {
        require(currentGen < 4, "This generation has been fully minted");
        uint256 idx = _genStartIdx(currentGen) + Entropy.random(_seed) % remainingToMint;
        uint256 id = idReplacements[idx];
        if(id == 0) {//Id not replaced, so idx is id.
            id = idx;
        }
        remainingToMint--;
        //replace used id with the id that will be excluded by the reduction in remainingToMint
        uint256 excludedId = idReplacements[remainingToMint];
        if(excludedId == 0) excludedId = remainingToMint;
        idReplacements[idx] = excludedId;

        if(remainingToMint == 0) {
            currentGen++;
            remainingToMint = getGenSize(currentGen);
        }

        _safeMint(_recipient, id);
        return id;
    }

    function _baseURI() internal override view returns(string memory) {
        return "";//TODO: add uri
    }

    //Convert int to string
    function uintToString(uint v) internal pure returns (string memory str) {
        uint maxlength = 100;
        bytes memory reversed = new bytes(maxlength);
        uint i = 0;
        while (v != 0) {
            uint remainder = v % 10;
            v = v / 10;
            reversed[i++] = bytes1(uint8(48 + remainder));
        }
        bytes memory s = new bytes(i + 1);
        for (uint j = 0; j <= i; j++) {
            s[j] = reversed[i - j];
        }
        str = string(s);
    }

    //Get compressed attributes of an NFT. 
    function getTraits(uint256 _tokenId) external override view returns(uint8) {
        require(_exists(_tokenId), "This NFT is not minted");

        uint256 idx = _tokenId / 42;//Index of full 256 bit entry containing the data we want
        uint256 offset = _tokenId - idx*42;//Offset of the data we want within the 256 bit entry

        unchecked {
            return uint8(uint256(traits[idx] >> (4+(41-offset)*6)) & 0x3f);//Extract 6 bits at offset from entry
        }
    }
    //Get the generation of a token by its ID.
    function getGen(uint256 _tokenId) public override view returns(uint8) {
        for(uint8 i = 0; i < 4; i++) {
            if(_tokenId < genMintCaps[i]) return i;
        }
        revert("tokenId exceeds max ID in last generation");
    }
    //Get the max number of mints in a generation
    function getGenSize(uint8 _gen) internal view returns(uint16) {
        return _gen < 4 ? genMintCaps[_gen] - _genStartIdx(_gen) : 0;
    } 
    function _genStartIdx(uint8 _gen) internal view returns(uint16) {
        return _gen == 0 ? 0 : genMintCaps[_gen-1];
    }
}