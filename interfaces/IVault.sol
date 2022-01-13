//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVault is IERC20 {
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
    /**
     * Function for the project's contracts to add FTM backing to the vault, funding its payouts.
     */
    function addBacking() external payable;
    /**
     * See accumulated rewards of an address in FTM
     */
    function rewardsFTM(address _of) external view returns(uint256);
}