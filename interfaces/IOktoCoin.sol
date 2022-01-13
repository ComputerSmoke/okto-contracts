//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IOktoCoin is IERC20 {
    /**
    Mint new tokens to an address. Owner is Aquarium, so only Aquarium can mint like this.
    */
    function mint(address _recipient, uint256 _amount) external;
    /**
    Toast some tokens. Only Aquarium can do this.
    */
    function burn(address _loser, uint256 _amount) external;
}