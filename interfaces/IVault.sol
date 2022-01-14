//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVault is IERC20 {
    /**
     * Struct for tracking deposits to flag whether they exist or not
     * initialAmount - rewards per deposited Okto ether on last claim
     * deposited - true if deposit exists
    */
    struct Deposit {
        uint256 initialAmount;
        bool deposited;
    }

    //Users
    /**
     * Deposit OKT into vault to start earning rewards.
     * Amount must already be approved for this contract to transfer.
     */
    function depositOKT(uint256 _amount) external;
    /**
     * Withdraw OKT from the vault
     */
    function withdrawOKT(uint256 _amount) external;
    /**
     * Claim FTM rewards accumulated from deposit
     */
    function claimFTM() external;

    //Project
    /**
     * Function for the project's contracts to add FTM backing to the vault, funding its payouts.
     */
    function addBacking() external payable;

    //Views
    /**
     * See accumulated rewards of an address in FTM
     */
    function rewardsFTM(address _of) external view returns(uint256);
    //Total FTM in vault
    function backing() external view returns(uint256);
    //Amount to payout per staked okto ether per day
    function dailyRewards() external view returns(uint256);
    //Total amount to pay out per staked ether
    function payoutAmount() external view returns(uint256);
    //Total amount owed as payouts
    function totalPayout() external view returns(uint256);
    //Total amount of okto deposited in vault
    function totalDeposits() external view returns(uint256);
    //Last time rewards were updated
    function lastUpdateTimestamp() external view returns(uint256);
    //Claimable FTM debt by address
    function debts(address _of) external view returns(uint256);
}