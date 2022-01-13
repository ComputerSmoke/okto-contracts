//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IRevenueManager.sol";

//Split revenue from the project amongst dev team
contract RevenueManager is Ownable,IRevenueManager {
    address immutable dev1;
    uint256 public override balance;
    constructor(address _dev1, address _ownerWallet) Ownable() {
        dev1 = _dev1;
        transferOwnership(_ownerWallet);
    }

    function mintIncome() external override payable {
        balance += msg.value;
    }

    function payout() external override {
        uint256 dev1Payout = balance * 3 / 10;
        uint256 ownerPayout = balance - dev1Payout;
        payable(dev1).transfer(dev1Payout);
        payable(owner()).transfer(ownerPayout);
    }
}