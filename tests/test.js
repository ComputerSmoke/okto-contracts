const { expect } = require("chai");
let web3 = require("web3");
const { ethers, waffle } = require("hardhat");
const crypto = require("crypto");

const provider = waffle.provider;
let owner, dev1, client1, client2;
let Aquarium,aquarium,OktoCoin,oktoCoin,OktoNFT,oktoNFT,RevenueManager,revenueManager,Vault,vault;
//Expect two arrays to have equal values
function tupleEqual(test, expected) {
  expect(test.length).to.equal(expected.length);
  for(let i = 0; i < test.length; i++) {
    expect(test[i]).to.equal(expected[i]);
  }
}
//Convert hex string to decimal string
function hexToDec(s) {
    var i, j, digits = [0], carry;
    for (i = 0; i < s.length; i += 1) {
        carry = parseInt(s.charAt(i), 16);
        for (j = 0; j < digits.length; j += 1) {
            digits[j] = digits[j] * 16 + carry;
            carry = digits[j] / 10 | 0;
            digits[j] %= 10;
        }
        while (carry > 0) {
            digits.push(carry % 10);
            carry = carry / 10 | 0;
        }
    }
    return digits.reverse().join('');
}
//Get random traits array as placeholder
async function getTraitsArr() {
    let arr = [];
    for(let i = 0; i < 655; i++) {
        arr.push(
            hexToDec(
                await new Promise(res => {
                    crypto.randomBytes(32, (err, buf) => {
                        res(buf.toString("hex"));
                    });
                })
            )
        );
    }
    return arr;
}

describe("Aquarium", function() {
    beforeEach(async function() {
        //Get test accounts
        [owner, dev1, client1, client2] = await ethers.getSigners();
        //factories
        Aquarium = await ethers.getContractFactory("Aquarium");
        OktoCoin = await ethers.getContractFactory("OktoCoin");
        OktoNFT = await ethers.getContractFactory("OktoNFT");
        RevenueManager = await ethers.getContractFactory("RevenueManager");
        Vault = await ethers.getContractFactory("Vault");
        //deployments
        oktoCoin = await OktoCoin.deploy()
        revenueManager = await RevenueManager.deploy(dev1.address, oktoCoin.address);
        oktoNFT = await oktoNFT.deploy(getTraitsArr());
        vault = await Vault.deploy(oktoCoin.address);
        aquarium = await Aquarium.deploy(oktoNFT.address, oktoCoin.address, revenueManager.address);
        //dependencies
        await oktoCoin.setRevenueManager(revenueManager.address);
        await oktoNFT.setAquarium(aquarium.address);
    });

    it("Mint", async () => {

    });
});