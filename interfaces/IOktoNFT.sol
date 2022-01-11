//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOktoNFT {
    //Events
    /**
     * Emitted when traits are set for a generation. Useful for community to then check against provenance hash
     * to verify order has not been tampered with.
     */
    event SetTraits(uint8 generation);
}