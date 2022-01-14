const { expect } = require("chai");
let web3 = require("web3");
const { ethers, waffle } = require("hardhat");

const provider = waffle.provider;
let owner, reciever, sender;
let PaymentManager,TestToken,paymentManager,testToken;
//Expect two arrays to have equal values
function tupleEqual(test, expected) {
  expect(test.length).to.equal(expected.length);
  for(let i = 0; i < test.length; i++) {
    expect(test[i]).to.equal(expected[i]);
  }
}

