async function deployNFT(account) {
    let OktoNFT = await ethers.getContractFactory("OktoNFT");
    console.log("account:",account.address)
    let oktoNFT = await OktoNFT.deploy(
        getTraitsArr()
    )
    return oktoNFT;
}

function getTraitsArr() {
    let arr = [];
    for(let i = 0; i < 655; i++) {
        arr.push(""+Math.floor(Math.random()*256000000000000))
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