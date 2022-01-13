//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IOktoCoin.sol";
import "../interfaces/IVault.sol";

contract Vault is ERC20,IVault {
    using SafeERC20 for IOktoCoin;
    //Okto token
    IOktoCoin public immutable okto;
    //Total FTM in vault
    uint256 public backing;
    //Amount to payout per staked okto ether per day
    uint256 public constant dailyRewards = 250000 * 1 ether / uint256(5 * 5000000000 * 360);//1 year to pay out total gen 0 mint fee amount
    //Total amount to pay out per staked ether
    uint256 public payoutAmount;
    //Total amount owed as payouts
    uint256 public totalPayout;
    //Total amount of okto deposited in vault
    uint256 public totalDeposits;
    //Last time rewards were updated
    uint256 public lastUpdateTimestamp;
    //Claimable FTM debts
    mapping(address => uint256) debts;
    
    
    struct Deposit {
        uint256 initialAmount;
        bool deposited;
    }
    //Track deposits of each address
    mapping(address => Deposit) deposits;

    //Update payout amount
    modifier updatePayout() {
        if(lastUpdateTimestamp < block.timestamp) {
            uint256 delta = block.timestamp - lastUpdateTimestamp;
            uint256 amount = dailyRewards * delta / 1 days;
            totalPayout += amount * totalDeposits;
            payoutAmount += amount;
            if(totalPayout > backing) {//Do not owe more than we have
                payoutAmount -= (totalPayout - backing) / totalDeposits;
                totalPayout = backing;
            }
            lastUpdateTimestamp = block.timestamp;
        }
        _;
    }

    constructor(address _okto) ERC20("vOktopus", "$DOKT") {
        okto = IOktoCoin(_okto);
    }
    //Deposit okto to vault to start earning rewards
    function depositOKT(uint256 _amount) external {
        _claim(msg.sender);
        Deposit storage deposit = deposits[msg.sender];
        deposit.deposited = true;
        deposit.initialAmount = payoutAmount;

        _mint(msg.sender, _amount);
        okto.safeTransferFrom(msg.sender, address(this), _amount);
    }
    //Withdraw okto from the vault
    function withdrawOKT(uint256 _amount) external {
        require(balanceOf(msg.sender) >= _amount);
        _claim(msg.sender);
        _burn(msg.sender, _amount);
        okto.safeTransfer(msg.sender, _amount);
    }
    //Claim rewards
    function claimFTM() external {
        _claim(msg.sender);
        uint256 debt = debts[msg.sender];
        debts[msg.sender] = 0;
        payable(msg.sender).transfer(debt);
    }
    function _claim(address _recipient) internal updatePayout {
        Deposit storage deposit = deposits[_recipient];
        if(!deposit.deposited || payoutAmount > deposit.initialAmount) return;
        uint256 rewards =  balanceOf(_recipient) * (payoutAmount - deposit.initialAmount) / 1 ether;
        deposit.initialAmount = payoutAmount;
        backing -= rewards;
        debts[_recipient] += rewards;
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
    function addBacking() external payable {
        backing += msg.value;
    }
    //See rewards of address
    function rewardsFTM(address _of) external view returns(uint256) {
        Deposit storage deposit = deposits[_of];
        if(!deposit.deposited || payoutAmount > deposit.initialAmount) return debts[_of];
        uint256 rewards =  balanceOf(_of) * (payoutAmount - deposit.initialAmount) / 1 ether;
        return rewards + debts[_of];
    }
}