//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IRandomOracleUser.sol";

interface IRandomOracle {
    //Randomness request pending fulfillment
    struct PendingRequest {
        IRandomOracleUser sender;
        uint128 seed;
    }
    /**
     * Request randomness from the contract. Seed should be something not predictable
     * by randomness supplier (randomly generated off-chain)
     */
    function requestRandomness(uint128 _seed) external payable returns(uint256);
    //Owner functions
    /**
     * Fulfill a randomness request. Calls fulfillRandomness in the contract that created the request.
     */
    function fulfillRandomness(uint128 _seed, uint256 _id) external;
    /** 
     * Fulfill multiple requests in one transaction
    */
    function fulfillBatch(uint128[] memory _seeds, uint256[] memory _ids) external;
    /**
     * Post a hash to fulfill future randomness requests with
     */
    function postHash(bytes32 _hash, uint256 _id) external;
    /**
     * Post multiple hashes in one transaction
     */
    function postBatch(bytes32[] memory _hashes, uint256[] memory _ids) external;
    /**
     * Whitelist an address of using this oracle
     */
    function addAuthorization(address _address) external;
    /**
     * Remove an address from the use whitelist
     */
    function removeAuthorization(address _address) external;
    
    //Number of hashes ready to be fulfilled
    function numPosted() external view returns(uint256);
    //Number of requests sent in
    function numPending() external view returns(uint256);
    //Number of fulfilled randomness requests
    function numFulfilled() external view returns(uint256);
}