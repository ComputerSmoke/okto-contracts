//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract OktoCoin is ERC20,Ownable {

    constructor() ERC20("Oktopus", "$OKT") Ownable() {
        
    }
    //Mint new tokens to an address. Owner is Aquarium, so only Aquarium can mint like this.
    function mint(address _recipient, uint256 _amount) external onlyOwner {
        _mint(_recipient, _amount);
    }
    //Toast some tokens. Only Aquarium can do this.
    function burn(address _loser, uint256 _amount) external onlyOwner {
        _burn(_loser, _amount);
    }
}