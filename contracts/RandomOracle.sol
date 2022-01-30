//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IRandomOracleUser.sol";
import "../interfaces/IRandomOracle.sol";

contract RandomOracle is Ownable,IRandomOracle {
    //Number of hashes ready to be fulfilled
    uint256 public override numPosted;
    //Number of requests
    uint256 public override numPending;
    //Number of fulfilled randomness requests
    uint256 public override numFulfilled;
    //Price of getting random number. Used to cover gas.
    uint256 public constant price = 0.5 ether;
    //Whether a contract is authorized to use this oracle
    mapping(address => bool) auth;
    //The posted hashes ready to be fulfilled
    mapping(uint256 => bytes32) public postedHashes;
    //Address of requester and sent seed for each pending randomness request
    mapping(uint256 => PendingRequest) pendingRequests;
    //Only allow authorized address
    modifier onlyAuth() {
        require(auth[msg.sender], "Not authorized");
        _;
    }
    //Emitted on randomness request
    event ReceivedRequest(uint256 id);
    //Initialize with owner
    constructor() Ownable() {}
    //Authorize a contract to use this oracle
    function addAuthorization(address _address) onlyOwner external override {
        auth[_address] = true;
    }
    //Revoke use authorization
    function removeAuthorization(address _address) onlyOwner external override {
        auth[_address] = false;
    }
    //Request randomness, returns ID of request
    function requestRandomness(uint128 _seed) onlyAuth external override payable returns(uint256) {
        require(msg.value >= price, "Payment required");
        require(numPosted > numPending, "No posted hash. Wait a bit for the oracle to catch up");
        pendingRequests[numPending] = PendingRequest(IRandomOracleUser(msg.sender), _seed);
        numPending++;
        payable(owner()).transfer(msg.value);
        return numPending-1;
    }
    //Oracle fulfills pending randomness request
    function fulfillRandomness(uint128 _seed, uint256 _id) external override onlyOwner {
        require(_id >= numFulfilled, "Request already fulfilled");
        require(_id < numPending, "Request does not exist");
        bytes32 sentHash = keccak256(abi.encodePacked(_seed));
        require(sentHash == postedHashes[_id], "Invalid randomness");
        numFulfilled++;
        pendingRequests[_id].sender.fulfillRandomness(
            _id,
            _random((uint256(_id) << 128) | uint256(pendingRequests[_id].seed))
        );
    }
    //Post hash for later fulfillment
    function postHash(bytes32 _hash, uint256 _id) external override onlyOwner {
        require(_id >= numPosted, "This id already posted");
        postedHashes[_id] = _hash;
        numPosted++;
    }
    //Get pseudo random number
    function _random(uint256 _seed) internal view returns(uint256) {
        return uint256(keccak256(abi.encodePacked(
            blockhash(block.number - 1),
            block.timestamp,
            _seed
        )));
    }
}