//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
//TODO
interface IAquarium {
    struct Stake {
        uint256 lastClaimEarned;//Total earned per power level on last claim
        bool staked;//True if currently staked
        bool init;//True if nft has ever been staked
    }
}