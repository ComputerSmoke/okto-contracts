//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * Function to use for hashing to aid in development of merkle tree
 */
contract Hasher {
    constructor() {}

    function toBytes(address _in) external pure returns (bytes32) {
        return bytes32(bytes20(_in));
    }
    function hashTogether(bytes32 v1, bytes32 v2) external pure returns(bytes32) {
        return keccak256(abi.encodePacked(v1, v2));
    }
}