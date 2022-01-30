//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//Necessary methods for oracle user
interface IRandomOracleUser {
    function fulfillRandomness(uint256 _id, uint256 _rand) external;
}