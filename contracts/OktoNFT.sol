//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IOktoNFT.sol";
import "../interfaces/IAquarium.sol";

contract OktoNFT is ERC721,Ownable,IOktoNFT {
    /**
     * Traits are encoded as follows:
     * Each index corresponds to 42 NFTs, 6 bits for each. The values of the first 4 bits determine the number of traits
     * it has (0-5), and a value of 6-9 indicates that it is a squid with alpha N-1. The last 2 bits determine its rarity,
     * 0 least rare, 2 most rare
     */
    uint256[655] public override traits;
    //Next ID to mint
    uint256 nextId;
    //Current 
    uint16[4] public override genMintCaps;
    uint8 public override currentGen;
    //Aquarium with perms to mint
    IAquarium aquarium;
    //True after aquarium has been set, preventing it from changing
    bool public override aquariumSet;
    //Only allow aquarium to call this
    modifier onlyAquarium() {
        require(msg.sender == address(aquarium));
        _;
    }

    constructor(
        uint256[655] memory _traits
    ) ERC721("Okto", "OKT") Ownable() {
        genMintCaps = [5000, 15000, 22500, 27500];
        for(uint i = 0; i < 655; i++) traits[i] = _traits[i];
    }
    //Set aquarium pointer
    function setAquarium(address _aquarium) external onlyOwner {
        require(address(aquarium) == address(0), "Aquarium already set.");
        aquarium = IAquarium(_aquarium);
    }
    //Mint NFT
    function mint(address _recipient) external override onlyAquarium {
        require(currentGen < 4 && nextId < genMintCaps[currentGen], "This generation has been fully minted");
        nextId++;
        _safeMint(_recipient, nextId-1);
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

        uint idx = _tokenId / 42;//Index of full 256 bit entry containing the data we want
        uint offset = _tokenId - idx;//Offset of the data we want within the 256 bit entry

        return uint8((traits[idx] >> (4+(41-offset)*6)) & 0x3f);//Extract 6 bits at offset from entry
    }
    //Get the generation of a token by its ID.
    function getGen(uint256 _tokenId) public override view returns(uint8) {
        for(uint8 i = 0; i < 4; i++) {
            if(_tokenId < genMintCaps[i]) return i;
        }
        revert("tokenId exceeds max ID in last generation");
    }
    
}