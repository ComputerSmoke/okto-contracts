const crypto = require("crypto");
const fs = require("fs");
const randomTraits = false;
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


async function main() {
    //Libraries
    Entropy = await ethers.getContractFactory("Entropy");
    entropy = await Entropy.deploy();
    //factories
    Aquarium = await ethers.getContractFactory("Aquarium", {libraries: {Entropy: entropy.address}});
    OktoCoin = await ethers.getContractFactory("OktoCoin");
    OktoNFT = await ethers.getContractFactory("OktoNFT", {libraries: {Entropy: entropy.address}});
    RevenueManager = await ethers.getContractFactory("RevenueManager", {libraries: {Entropy: entropy.address}});
    Vault = await ethers.getContractFactory("Vault");
    //deployments
    oktoCoin = await OktoCoin.deploy();
    vault = await Vault.deploy(oktoCoin.address);
    revenueManager = await RevenueManager.deploy("0x969eC4E98EF088d64C88521671306cA295Fd482e", oktoCoin.address, vault.address);
    oktoNFT = await OktoNFT.deploy(await getTraitsArr());
    aquarium = await Aquarium.deploy(
        oktoNFT.address, 
        oktoCoin.address, 
        revenueManager.address, 
        "0x2316f8e7b406f48fbb7da1e1c0d8620ed1d4813ed6d856b4e7b4a001faa47bb9"
    );
    //dependencies
    await oktoCoin.setRevenueManager(revenueManager.address);
    await oktoNFT.setAquarium(aquarium.address);
    await oktoCoin.setAquarium(aquarium.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })