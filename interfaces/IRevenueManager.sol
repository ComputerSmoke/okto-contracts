//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRevenueManager {
    //Emitted when lottery is won
    event LotteryWinner(address winner);
    //Views
    //View amount of funds awaiting payout to devs
    function balance() external view returns(uint256);
    //Pay funds out to devs
    function payout() external;
    //Balance available to pay out to all devs
    function devBalance() external view returns(uint256);
    //Balance available in the lottery
    function lotteryBalance() external view returns(uint256);

    //Actions
    //Recieve funds from mint
    function mintIncome() external payable;
    //Add/remove user to lottery based off their balance. Called by oktoCoin contract
    function updateLottery(address _user, uint256 _balance) external;
    //Run the lottery if it is funded or expire it if it is expired
    function runLottery(uint256 _seed) external
}