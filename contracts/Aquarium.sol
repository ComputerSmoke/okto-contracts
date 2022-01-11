//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "./OktoCoin.sol";
import "./RevenueManager.sol";

//Mint/stake contract for okto NFTs
contract Aquarium is ERC721Holder {
    OktoCoin public immutable oktoCoin;
    RevenueManager public immutable revenueManager;
    constructor(uint256 _totalOkto, address _dev1) {
        oktoCoin = new OktoCoin(_totalOkto);
        revenueManager = new RevenueManager(_dev1, msg.sender);
    }
}