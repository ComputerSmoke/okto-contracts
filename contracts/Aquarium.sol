//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "./OktoCoin.sol";
import "./RevenueManager.sol";
import "../interfaces/IOktoNFT.sol";

//Mint/stake contract for okto NFTs
contract Aquarium is ERC721Holder {
    //ERC20 token contract
    OktoCoin public immutable oktoCoin;
    //Handles payouts to dev team
    RevenueManager public immutable revenueManager;
    //ERC721 NFT contract
    IOktoNFT public immutable oktoNFT;

    constructor(
        uint256 _totalOkto, 
        address _dev1,
        address _oktoNFT
    ) {
        oktoCoin = new OktoCoin(_totalOkto);
        revenueManager = new RevenueManager(_dev1, msg.sender);
        oktoNFT = IOktoNFT(_oktoNFT);
    }
}