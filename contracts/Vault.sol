//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IOktoCoin.sol";
import "../interfaces/IVault.sol";

import "hardhat/console.sol";
//TODO: Debug overflow on claim / withdraw
contract Vault is ERC20,IVault {
    using SafeERC20 for IOktoCoin;
    //Okto token
    IOktoCoin public immutable okto;
    //Total FTM in vault
    uint256 public override backing;
    //Total FTM ever held in vault
    uint256 totalEverBacking;
    //Time to payout 1 FTM per staked Okto
    uint256 public override constant payoutTime = (5*10**9)/48000 * 360 days;//1 year to pay out total gen 0 mint fee amount
    //Total amount to pay out per staked ether
    uint256 public override payoutAmount;
    //Total amount owed as payouts
    uint256 public override totalPayout;
    //Last time rewards were updated
    uint256 public override lastUpdateTimestamp;
    //Claimable FTM debts
    mapping(address => uint256) public override debts;
    
    //Track deposits of each address
    mapping(address => Deposit) deposits;

    //Update payout amount
    modifier updatePayout() {
        if(lastUpdateTimestamp < block.timestamp) {
            uint256 delta = block.timestamp - lastUpdateTimestamp;
            uint256 amount = 1 ether * delta / payoutTime;
            console.log("amount:",amount);
            uint256 supply = 1 + (totalSupply() / 1 ether);
            console.log("supply:",supply);
            console.log("totalPayout:",totalPayout);
            console.log("totalEverBacking:",totalEverBacking);
            if(totalPayout + (amount * supply) > totalEverBacking) {//Do not owe more than we have
                amount = (totalEverBacking - totalPayout) / supply;
                console.log("adjustedAmount:",amount);
            }
            totalPayout += amount * supply;
            payoutAmount += amount;
            console.log("totalPayout:",totalPayout);
            console.log("payoutAmount:",payoutAmount);
            console.log("totalEverBacking:",totalEverBacking);
            lastUpdateTimestamp = block.timestamp;
        }
        _;
    }

    constructor(address _okto) ERC20("vOktopus", "$DOKT") {
        okto = IOktoCoin(_okto);
    }
    //Deposit okto to vault to start earning rewards
    function depositOKT(uint256 _amount) external override {
        _claim(msg.sender);
        Deposit storage deposit = deposits[msg.sender];
        deposit.deposited = true;

        _mint(msg.sender, _amount);
        okto.safeTransferFrom(msg.sender, address(this), _amount);
        console.log("deposited");
    }
    //Withdraw okto from the vault
    function withdrawOKT(uint256 _amount) external override {
        Deposit storage deposit = deposits[msg.sender];
        require(deposit.deposited, "Okto not deposited");
        require(balanceOf(msg.sender) >= _amount);
        _claim(msg.sender);
        deposit.deposited = false;

        _burn(msg.sender, _amount);
        okto.safeTransfer(msg.sender, _amount);
    }
    //Claim rewards
    function claimFTM() external override {
        _claim(msg.sender);
        uint256 debt = debts[msg.sender];
        debts[msg.sender] = 0;
        payable(msg.sender).transfer(debt);
    }
    function _claim(address _recipient) internal updatePayout {
        console.log("claiming");
        console.log("payout:",payoutAmount);
        Deposit storage deposit = deposits[_recipient];
        console.log("init:",deposit.initialAmount);
        if(payoutAmount <= deposit.initialAmount) return;
        if(!deposit.deposited) {
            deposit.initialAmount = payoutAmount;
            return;
        }
        console.log("no return");
        console.log("bal:",balanceOf(_recipient));
        uint256 rewards = (balanceOf(_recipient) * (payoutAmount - deposit.initialAmount)) / 1 ether;
        console.log("rewards:",rewards);
        console.log("backing:",backing);
        backing -= rewards;
        debts[_recipient] += rewards;
        deposit.initialAmount = payoutAmount;
        console.log("claimed");
    }
    //Do not allow for the transfer of vault tokens
    function _transfer (
        address,
        address,
        uint256
    ) internal virtual override {
        revert("Vault tokens cannot be transferred, withdraw to Okto first.");
    }
    //Add backing to vault
    function addBacking() external override payable {
        backing += msg.value;
        totalEverBacking += msg.value;
    }
    //See rewards of address
    function rewardsFTM(address _of) external override view returns(uint256) {
        Deposit storage deposit = deposits[_of];
        if(!deposit.deposited || payoutAmount > deposit.initialAmount) return debts[_of];
        uint256 rewards =  balanceOf(_of) * (payoutAmount - deposit.initialAmount) / 1 ether;
        return rewards + debts[_of];
    }
}