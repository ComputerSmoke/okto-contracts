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
    uint256[84] public override traitsGen0;
    uint256[120] public override traitsGen1;
    uint256[239] public override traitsGen2;
    uint256[120] public override traitsGen3;
    //Provenance hashes for generation traits
    uint256[4] public override traitProvenance;
    //baseURI of metadata by generation
    bytes32 immutable URIGen0;
    bytes32 immutable URIGen1;
    bytes32 immutable URIGen2;
    bytes32 immutable URIGen3;
    //Next ID to mint
    uint256 nextId;
    //Current 
    uint16[4] genMintCaps;
    uint8 currentGen;
    //Aquarium with perms to mint
    IAquarium aquarium;
    //True ater aquarium has been set, preventing it from changing
    bool squariumSet;
    //Only allow aquarium to call this
    modifier onlyAquarium() {
        require(msg.sender == address(aquarium));
        _;
    }

    /**
     * @param _traitProvenance: array of generation provenance hashes
     */
    constructor(
        uint256[4] memory _traitProvenance,
        address _owner,
        bytes32 _URIGen0,
        bytes32 _URIGen1,
        bytes32 _URIGen2,
        bytes32 _URIGen3
    ) ERC721("Okto", "OKT") Ownable() {
        for(uint i = 0; i < 4; i++) {
            traitProvenance[i] = _traitProvenance[i];
        }
        transferOwnership(_owner);
        URIGen0 = _URIGen0;
        URIGen1 = _URIGen1;
        URIGen2 = _URIGen2;
        URIGen3 = _URIGen3;
        genMintCaps = [3500, 8500, 18500, 23500];
    }
    //Set aquarium pointer
    function setAquarium(address _aquarium) external onlyOwner {
        aquarium = IAquarium(_aquarium);
    }
    //Mint NFT
    function mint(address _recipient) external override onlyAquarium {
        require(currentGen < 4 && nextId < genMintCaps[currentGen], "This generation has been fully minted");
        nextId++;
        _safeMint(_recipient, nextId-1);
    }

    //Get URI of token
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        //Base uri depends on generation
        string memory baseURI;
        if(tokenId < 3500) baseURI = "";//TODO: gen0 URI
        else if(tokenId < 8500) baseURI = "";//TODO: gen1 URI
        else if(tokenId < 18500) baseURI = "";//TODO: gen2 URI
        else baseURI = "";//TODO: gen3 URI
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, uintToString(tokenId))) : "";
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

    //Set generation traits. Should be done once per gen after mints and is verifiable by provenance hashes.
    function setTraitsGen0(uint256[84] memory _traits) external override onlyOwner {
        for(uint i = 0; i < 84; i++) traitsGen0[i] = _traits[i];
        currentGen++;
        emit SetTraits(0);
    }
    function setTraitsGen1(uint256[120] memory _traits) external override onlyOwner {
        for(uint i = 0; i < 120; i++) traitsGen1[i] = _traits[i];
        currentGen++;
        emit SetTraits(1);
    }
    function setTraitsGen2(uint256[239] memory _traits) external override onlyOwner {
        for(uint i = 0; i < 239; i++) traitsGen2[i] = _traits[i];
        currentGen++;
        emit SetTraits(2);
    }
    function setTraitsGen3(uint256[120] memory _traits) external override onlyOwner {
        for(uint i = 0; i < 120; i++) traitsGen3[i] = _traits[i];
        currentGen++;
        emit SetTraits(3);
    }

    //Get compressed attributes of an NFT. 
    function getTraits(uint256 _tokenId) external override view returns(uint8) {
        require(_exists(_tokenId), "This NFT is not minted");

        uint gen = getGen(_tokenId);
        uint relativeId = _tokenId - genMintCaps[gen];
        uint idx = relativeId / 42;//Index of full 256 bit entry containing the data we want
        uint offset = relativeId - idx;//Offset of the data we want within the 256 bit entry

        uint256 fullEntry;//256 bit entry to extract our data from
        if(gen == 0) fullEntry = traitsGen0[idx];
        else if(gen == 1) fullEntry = traitsGen1[idx];
        else if(gen == 2) fullEntry = traitsGen2[idx];
        else fullEntry = traitsGen3[idx];

        return uint8((fullEntry >> (4+(41-offset)*6)) & 0x3f);//Extract 6 bits at offset from entry
    }
    //Get the generation of a token by its ID.
    function getGen(uint256 _tokenId) internal view returns(uint8) {
        for(uint8 i = 0; i < 4; i++) {
            if(_tokenId < genMintCaps[i]) return i;
        }
        revert("tokenId exceeds max ID in last generation");
    }
    
}