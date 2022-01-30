const { expect } = require("chai");
let web3 = require("web3");
const { ethers, waffle } = require("hardhat");
const crypto = require("crypto");
const deploy = require("../scripts/deploy.js");

const provider = waffle.provider;
let owner, dev1, client1, client2, client3, client4;
let Aquarium,aquarium,OktoCoin,oktoCoin,OktoNFT,oktoNFT,RevenueManager,revenueManager,Vault,vault,Entropy,entropy;
let mintCost,genMintCaps;
let hasher,Hasher;

const testFullMint = false;
const testLottery = true;
const testStaking = false;
const testSteal = false;
const testDecoding = false;
const testPower = false;

const nullAddress = "0x0000000000000000000000000000000000000000";
//Expect two arrays to have equal values
function tupleEqual(test, expected) {
  expect(test.length).to.equal(expected.length);
  for(let i = 0; i < test.length; i++) {
    expect(test[i]).to.equal(expected[i]);
  }
}

async function getGenMintCaps() {
    let ret = [];
    for(let i = 0; i < 4; i++) {
        ret.push(await oktoNFT.genMintCaps(i));
    }
    return ret;
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
/*PYRAMID OF DOOM*/     res(buf.toString("hex"));
                    });
                })
            )
        );
    }
    return arr;
}
//If token is false, expected just represents the sign change expected.
async function checkBalance(expected, account, token) {
    let balance;
    if(token) {
      balance = await oktoCoin.balanceOf(account.address);
      expect(balance).to.equal(ethers.BigNumber.from(expected));
    } else {
      balance = await provider.getBalance(account.address);
      expect(balance.sub(ethers.BigNumber.from(10).pow(27)).mul(expected) > 0).to.equal(true);
    }
  }
//wait specified number of ms
async function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

//Mint until we have an octopus for client 1 and a squid for 2
async function mintOcto(user, squid) {
    let octo;
    let caquarium = aquarium.connect(user);
    let i = 0;
    while(octo == undefined) {
        let hash = await hasher.hashSeed(7777);
        let numPosted = await randomOracle.numPosted();
        await randomOracle.postHash(hash, numPosted);
        await caquarium.mintGen0(69, {value: mintCost});
        await randomOracle.fulfillRandomness(7777, numPosted);
        let id = await oktoNFT.tokenOfOwnerByIndex(user.address, i);
        let trait = await oktoNFT.getTraits(id);
        let isSquid = (trait & 0xf) > 5;
        if(isSquid == squid) octo = id;
        i++;
    }
    return octo;
}

let postedVal = 0;
let postedIdx = 0;
async function postHash() {
    postedVal = Math.floor(Math.random()*100000);
    let hash = await hasher.hashSeed(postedVal);
    postedIdx = await randomOracle.numPosted();
    await randomOracle.postHash(hash, postedIdx);
}

async function fillRand() {
    await randomOracle.fulfillRandomness(postedVal, postedIdx);
}

let merkleTree = [];
let baseSize = 0;
let addressDict;


//Create merkle tree and hashmap of address to index
async function createMerkleTree(tree) {
    let addressIdx = {};
    for(let i = 0; i < tree.length; i++) {
        addressIdx[tree[i]] = i;
        tree[i] = await hasher.toBytes(tree[i]);
    }
    let height = Math.ceil(Math.log2(tree.length))+1;
    let levelSize = Math.pow(2, height-1);
    let x = levelSize - tree.length;
    for(let i = 0; i < x; i++) {
        tree.push(await hasher.toBytes(nullAddress));
    }
    let idx = 0;
    while(idx+1 < tree.length) {
        tree.push(await hasher.hashTogether(tree[idx], tree[idx+1]));
        idx += 2;
    }
    return addressIdx;
}
//Get proof from tree
function getProof(address) {
    let idx = addressDict[address];
    let proof = [];
    while(idx < merkleTree.length-1) {
        let sibling = (idx % 2 == 0) ? merkleTree[idx+1] : merkleTree[idx-1];
        proof.push(sibling);
        idx = merkleTree.length - Math.floor((merkleTree.length-idx)/2);
    }
    return proof;
}

describe("Aquarium", function() {
    beforeEach(async function() {
        //Get test accounts
        [owner, dev1, client1, client2, client3, client4] = await ethers.getSigners();
        [randomOracle,oktoCoin,vault,revenueManager,oktoNFT,aquarium] = await deploy.deploy(dev1.address);
        Hasher = await ethers.getContractFactory("Hasher");
        hasher = await Hasher.deploy();
        merkleTree = [owner.address, dev1.address, client1.address, client2.address, client3.address, client4.address];
        addressDict = createMerkleTree(merkleTree);
        //Constant views
        mintCost = await aquarium.mintCost();
        genMintCaps = await getGenMintCaps();
    });

    it("Whitelist mint", async() => {
        return;
        await aquarium.connect(client1).mintWhitelist(
            "69", 
            getProof(client1.address), 
            addressDict[client1.address], 
            {value: mintCost}
        );
        expect(await oktoNFT.balanceOf(client1.address)).to.equal(0);//Not minted until randomness is fulfilled
        expect(await revenueManager.lotteryBalance()).to.equal(ethers.BigNumber.from(mintCost).sub(ethers.utils.parseWei("0.5")));//funds sent to lottery balance
        await randomOracle.fulfillRandomness("69", "0");
        expect(await oktoNFT.balanceOf(client1.address)).to.equal(1);//NFT recieved
    });

    it("Mint, stake, unstake", async () => {
        //mint
        let val = "666";
        let hash = await hasher.hashSeed(val);
        await randomOracle.postHash(hash, "0");
        expect(await oktoNFT.balanceOf(client1.address)).to.equal(0);//None owned prior to mint
        await aquarium.setOpenMint();
        await aquarium.connect(client1).mintGen0(69, {value: mintCost});
        await randomOracle.fulfillRandomness(val, "0");
        expect(await oktoNFT.balanceOf(client1.address)).to.equal(1);//NFT recieved
        expect(await revenueManager.lotteryBalance()).to.equal(ethers.BigNumber.from(mintCost).sub(web3.utils.toWei("0.5", "ether")).toString());//funds sent to lottery balance
    
        //stake
        let id = await oktoNFT.tokenOfOwnerByIndex(client1.address, 0);
        await aquarium.connect(client1).stakeNFT(id);
        //unstake
        hash = await hasher.hashSeed(700);
        await randomOracle.postHash(hash, 1);
        await aquarium.connect(client1).unstakeNFT(id, 240, {value: web3.utils.toWei("0.5", "ether")});
        await randomOracle.fulfillRandomness(700, 1);
    });


    it("Mint all gen0, mint some gen1, vault", async() => {
        if(!testFullMint) {
            console.log("Skipping gen0 mint test");
            return;
        }
        await aquarium.setOpenMint();
        let hash = await hasher.hashSeed(900);
        await randomOracle.postHash(hash, "0");
        await aquarium.connect(client1).mintGen0(69, {value: mintCost});
        await randomOracle.fulfillRandomness(900, 0);
        expect(""+await oktoNFT.getGen(0)).to.equal(""+0);
        for(let i = 1; i < genMintCaps[0]; i++) {
            let hash = await hasher.hashSeed(900+i);
            await randomOracle.postHash(hash, i);
            await aquarium.connect(client1).mintGen0(69, {value: mintCost});
            await randomOracle.fulfillRandomness(900+i, i);

            let id = await oktoNFT.tokenOfOwnerByIndex(client1.address, i);
            await aquarium.connect(client1).stakeNFT(id);
        }
        expect(await oktoNFT.balanceOf(client1.address)).to.equal(genMintCaps[0]);//All minted
        //Check that all IDs are unique and in range
        let pass = true;
        let idCounts = {}
        for(let i = 0; i < genMintCaps[0]; i++) {
            let id = await oktoNFT.tokenOfOwnerByIndex(client1.address, i);
            if(id < 0 || id >= genMintCaps[0]) pass = false;
            if(idCounts[id] != undefined) pass = false;
            idCounts[id] = true;
        }
        expect(pass).to.equal(true);
        //Check that lottery is funded
        expect(await revenueManager.lotteryBalance()).to.equal(web3.utils.toWei("10000","ether"));
        //Check that gen now gen1
        expect(await oktoNFT.currentGen()).to.equal(1);

        console.log("minted");
        //gen 1 buying
        await sleep(600000);

        for(let i = 1; i < genMintCaps[0]; i++) {
            let id = await oktoNFT.tokenOfOwnerByIndex(client1.address, i);
            await aquarium.connect(client1).claimNFT(id);
        }
        console.log("claimed");

        let fBal = await oktoCoin.balanceOf(client1.address);
        hash = hasher.hashSeed(9000);
        let num = randomOracle.numPosted();
        await randomOracle.postHash(hash, num);
        await aquarium.connect(client1).mintGenX(69, {value: web3.utils.toWei("0.5", "ether")});
        await randomOracle.fulfillRandomness(9000, num);
        expect(""+await oktoNFT.getGen(genMintCaps[0])).to.equal(""+1);
        let nBal = await oktoCoin.balanceOf(client1.address);
        expect(fBal.gt(nBal)).to.equal(true);
        console.log("fbal:",fBal,"nbal:",nBal);

        console.log("minted gen 1");
        //vault
        await sleep(100000);
        let backing = await vault.backing()
        console.log("backing:",backing);
        expect(backing.gt(0)).to.equal(true);
        nBal = await oktoCoin.balanceOf(client1.address);
        oktoCoin.connect(client1).approve(vault.address, nBal);
        let ftmHoldings = await provider.getBalance(client1.address);
        await vault.connect(client1).depositOKT(nBal);
        let oktoBal = await oktoCoin.balanceOf(client1.address);
        console.log("okto bal post deposit:",oktoBal,"pre:",nBal);
        expect(oktoBal.eq(0)).to.equal(true);
        await sleep(100000);
        await vault.connect(client1).claimFTM();
        let newHoldings = await provider.getBalance(client1.address);
        console.log("oldholdings",ftmHoldings,"newHoldings:",newHoldings)
        expect(newHoldings.gt(ftmHoldings)).to.equal(true);
        await vault.connect(client1).withdrawOKT(nBal);
        expect(nBal.eq(await oktoCoin.balanceOf(client1.address))).to.equal(true);
    });

    it("revenue payout and lottery", async () => {
        if(!testLottery) return;
        for(let i = 0; i < 300; i++) {
            let hash = await hasher.hashSeed(400+i);
            await randomOracle.postHash(hash, i);
        }
        for(let i = 0; i < 300; i++) {
            await aquarium.connect(client1).mintGen0(69, {value: mintCost});
        }
        for(let i = 0; i < 300; i++) {
            await randomOracle.fulfillRandomness(400+i, i);
            let id = await oktoNFT.tokenOfOwnerByIndex(client1.address, i);
            await aquarium.connect(client1).stakeNFT(id);
        }
        expect(await revenueManager.lotteryBalance()).to.equal(await revenueManager.lotteryAmount());
        expect(await revenueManager.devBalance()).to.equal("3880000000000000000000");

        await revenueManager.payout();
        console.log("dev1 bal:",await provider.getBalance(dev1.address));
        console.log("owner bal:",await provider.getBalance(owner.address));
        checkBalance(1, dev1, false);
        checkBalance(1, owner, false);
        expect(await provider.getBalance(dev1.address) < await provider.getBalance(owner.address)).to.equal(true);

        await sleep(1500000);
        for(let i = 0; i < 300; i++) {
            let id = await oktoNFT.tokenOfOwnerByIndex(client1.address, i);
            await aquarium.connect(client1).claimNFT(id);
        }

        let oldBalance = await provider.getBalance(client2.address);
        let coinBalance = await oktoCoin.balanceOf(client1.address)
        await oktoCoin.connect(client1).transfer(client2.address, coinBalance);
        console.log("coin balance:",coinBalance);
        let hash = await hasher.hashSeed(677);
        let numPosted = await randomOracle.numPosted();
        await randomOracle.postHash(hash, numPosted);
        await revenueManager.connect(dev1).runLottery(69, {value: web3.utils.toWei("0.5", "ether")});//TODO: lottery not paying out to client 2
        await randomOracle.fulfillRandomness(677, numPosted);
        let newBalance = await provider.getBalance(client2.address);
        console.log("balance change: ",newBalance.sub(oldBalance));
        expect(newBalance.gt(oldBalance)).to.equal(true);

    });

    it("power level decoding", async() => {
        if(!testDecoding) return;
        await aquarium.setOpenMint();
        for(let i = 0; i < 10; i++) {
            let hash = await hasher.hashSeed(500+i);
            await randomOracle.postHash(hash, i);
            await aquarium.connect(client1).mintGen0(69, {value: mintCost});
            await randomOracle.fulfillRandomness(500+i, i);
            let id = await oktoNFT.tokenOfOwnerByIndex(client1.address, i);
            let trait = await oktoNFT.getTraits(id);
            let squid = (trait & 0xf) > 5;
            let expectedPower = squid ? ((trait & 0xf)-1)*(((trait >> 4) & 0x3)+1) : ((trait & 0xf) + 5)*(((trait >> 4) & 0x3)+1);
            let powerLevel = await aquarium.powerLevel(""+trait);
            expect(powerLevel).to.equal(expectedPower);
        }
    });

    it("staking", async() => {
        if(!testStaking) return;
        let octopus = await mintOcto(client1, false);
        let squid = await mintOcto(client2, true);
        let i = 0;
        let c1quarium = await aquarium.connect(client1);
        let c2quarium = await aquarium.connect(client2);
        
        await c1quarium.stakeNFT(octopus);
        await c2quarium.stakeNFT(squid);

        await sleep(10000);//wait 10 seconds

        await c1quarium.claimNFT(octopus);
        await c2quarium.claimNFT(squid);
        console.log("address 1:",client1.address);
        let b1 = await oktoCoin.balanceOf(client1.address);
        let b2 = await oktoCoin.balanceOf(client2.address);
        console.log("b1:",b1);
        console.log("b2:",b2);
        expect(b1.gt(0)).to.equal(true);
        expect(b2.gt(0)).to.equal(true);
        expect(b1.gt(b2)).to.equal(true);
        await postHash();
        await c1quarium.unstakeNFT(octopus, 69, {value: web3.utils.toWei("0.5", "ether")});
        await fillRand();
        let safe=0;
        let steal=0;
        let prev = await oktoCoin.balanceOf(client2.address);
        for(let i = 0; i < 30; i++) {
            await c1quarium.stakeNFT(octopus);
            await sleep(10000);
            await postHash();
            await c1quarium.unstakeNFT(octopus, 69, {value: web3.utils.toWei("0.5", "ether")});
            await fillRand();
            await c2quarium.claimNFT(squid);
            let bal = await oktoCoin.balanceOf(client2.address);
            if(bal.gt(prev)) steal++;
            else safe++;
            prev = bal;
        }
        console.log("safes:",safe,"steals:",steal);
        expect(safe+steal).to.equal(30);
    });

    it("power ratios", async() => {
        if(!testPower) return;
        let octopus1 = await mintOcto(client1, false);
        let squid1 = await mintOcto(client2, true);
        let octopus2 = await mintOcto(client3, false);
        let squid2 = await mintOcto(client4, true);
        let trait1 = await oktoNFT.getTraits(octopus1);
        let trait2 = await oktoNFT.getTraits(squid1);
        let trait3 = await oktoNFT.getTraits(octopus2);
        let trait4 = await oktoNFT.getTraits(squid2);
        let power1 = await aquarium.powerLevel(trait1);
        let power2 = await aquarium.powerLevel(trait2);
        let power3 = await aquarium.powerLevel(trait3);
        let power4 = await aquarium.powerLevel(trait4);
        await aquarium.connect(client1).stakeNFT(octopus1);
        await aquarium.connect(client3).stakeNFT(octopus2);
        await aquarium.connect(client2).stakeNFT(squid1);
        await aquarium.connect(client4).stakeNFT(squid2);
        await sleep(30000);
        await aquarium.connect(client1).claimNFT(octopus1);
        await aquarium.connect(client3).claimNFT(octopus2);
        await aquarium.connect(client2).claimNFT(squid1);
        await aquarium.connect(client4).claimNFT(squid2);
        let bal1 = await oktoCoin.balanceOf(client1.address);
        let bal2 = await oktoCoin.balanceOf(client2.address);
        let bal3 = await oktoCoin.balanceOf(client3.address);
        let bal4 = await oktoCoin.balanceOf(client4.address);
        expect(bal1.gt(0)).to.equal(true);
        expect(bal2.gt(0)).to.equal(true);
        console.log("power2:",power2,"bal2:",bal2,"power4:",power4,"bal4:",bal4);
        expect(power1 > power3).to.equal(bal1.gt(bal3));
        expect(power2 > power4).to.equal(bal2.gt(bal4));
    });

    it("octopus stealing", async() => {
        if(!testSteal) return;
        await aquarium.setOpenMint();
        let squid1 = await mintOcto(client2, true);
        await aquarium.connect(client2).stakeNFT(squid1);
        let firstBal = await oktoNFT.balanceOf(client2.address);
        let prev = 0;
        let safes = 0;
        let steals = 0;
        for(let i = 0; i < 30; i++) {
            await postHash();
            await aquarium.connect(client1).mintGen0(69, {value: mintCost});
            await fillRand();
            let bal = await oktoNFT.balanceOf(client1.address);
            if(bal.gt(prev)) safes++;
            else steals++;
            prev = bal;
        }
        console.log("safes:",safes,"steals:",steals);
        let b1 = await oktoNFT.balanceOf(client1.address);
        let b2 = await oktoNFT.balanceOf(client2.address);
        console.log("b2:",b2,"firstbal:",firstBal,"steals:",steals,"b1:",b1,"safes:",safes);
        expect(b2.eq(firstBal.add(steals))).to.equal(true);
        expect(b1.eq(safes)).to.equal(true);
        expect(safes+steals).to.equal(30);
    });

});