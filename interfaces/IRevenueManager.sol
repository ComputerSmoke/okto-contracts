//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRevenueManager {
    //View amount of funds awaiting payout to devs
    function balance() external view returns(uint256);
    //Pay funds out to devs
    function payout() external;
    //Recieve funds from project
    receive() external payable;
}