//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Entropy {
    //Get pseudo random number
    function random(uint256 _seed) external view returns(uint256) {
        return uint256(keccak256(abi.encodePacked(
            msg.sender,
            tx.origin,
            blockhash(block.number - 1),
            block.timestamp,
            _seed
        )));
    }
}