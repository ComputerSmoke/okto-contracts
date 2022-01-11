//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "./OktoCoin.sol";

//Mint/stake contract for okto NFTs
contract OktoManager is ERC721Holder {
    OktoCoin immutable oktoCoin;
    constructor(uint256 _totalOkto) {
        oktoCoin = new OktoCoin(_totalOkto);
    }
}