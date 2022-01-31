const crypto = require("crypto");
const fs = require("fs");
const randomTraits = false;
const rootHashStatic = "0x2316f8e7b406f48fbb7da1e1c0d8620ed1d4813ed6d856b4e7b4a001faa47bb9";
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
    return randomTraits ? await getRandomTraitsArr() : loadTraitsArr();
}
function loadTraitsArr() {
    return JSON.parse(fs.readFileSync("metadata/encoding.json"));
}
async function getRandomTraitsArr() {
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

async function deploy(devAddress) {
    const accounts = await ethers.getSigners();
    //factories
    RandomOracle = await ethers.getContractFactory("RandomOracle");
    Aquarium = await ethers.getContractFactory("Aquarium");
    OktoCoin = await ethers.getContractFactory("OktoCoin");
    OktoNFT = await ethers.getContractFactory("OktoNFT");
    RevenueManager = await ethers.getContractFactory("RevenueManager");
    Vault = await ethers.getContractFactory("Vault");
    //deployments
    randomOracle = await RandomOracle.deploy();
    oktoCoin = await OktoCoin.deploy();
    vault = await Vault.deploy(oktoCoin.address);
    revenueManager = await RevenueManager.deploy(
        devAddress, 
        oktoCoin.address, 
        vault.address,
        randomOracle.address,
        [devAddress]
    );
    oktoNFT = await OktoNFT.deploy();
    aquarium = await Aquarium.deploy(
        oktoNFT.address, 
        oktoCoin.address, 
        revenueManager.address, 
        randomOracle.address,
        rootHashStatic
    );
    //dependencies
    await oktoCoin.setRevenueManager(revenueManager.address);
    await oktoNFT.setAquarium(aquarium.address);
    await oktoCoin.setAquarium(aquarium.address);
    await randomOracle.addAuthorization(aquarium.address);
    await randomOracle.addAuthorization(revenueManager.address);
    //metadata upload
    let traits = await getTraitsArr();
    for(let i = 0; i < 10; i++) {
        await oktoNFT.uploadMetadata(traits.slice(i*65, (i+1)*65));
    }
    await oktoNFT.uploadMetadata(traits.slice(650, 655));
    return ([
        randomOracle,
        oktoCoin,
        vault,
        revenueManager,
        oktoNFT,
        aquarium
    ]);
}

async function main() {
    await deploy("0xc8cab50f49aba9b17Bd62ef6Aa765ba7f1f8BD4A");
}

main()

module.exports = {deploy}