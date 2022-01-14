const crypto = require("crypto");

async function deployNFT(account) {
    let OktoNFT = await ethers.getContractFactory("OktoNFT");
    console.log("account:",account.address)
    let oktoNFT = await OktoNFT.deploy(
        await getTraitsArr()
    )
    return oktoNFT;
}

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

async function main() {
    let [account] = await ethers.getSigners();
    let oktoNFT = await deployNFT(account);
    console.log(oktoNFT);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })