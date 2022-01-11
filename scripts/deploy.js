async function deployNFT(account) {
    let OktoNFT = await ethers.getContractFactory("OktoNFT");
    console.log("account:",account.address)
    let oktoNFT = await OktoNFT.deploy(
        [ethers.BigNumber.from("4"), ethers.BigNumber.from("390874508723"), ethers.BigNumber.from("824322"), ethers.BigNumber.from("8242322")],
        account.address,
        "6900000",
        "0xffffefffffffefffffffefffffffefffffffefffffffefffffffefffffffefff",
        "0xffffefffffffefffffffefffffffefffffffefffffffefffffffefffffffefff",
        "0xffffefffffffefffffffefffffffefffffffefffffffefffffffefffffffefff",
        "0xffffefffffffefffffffefffffffefffffffefffffffefffffffefffffffefff"
    )
    return oktoNFT;
}

function getTraitsArr() {
    let arr = [];
    for(let i = 0; i < 239; i++) {
        arr.push(""+Math.floor(Math.random()*256000000000000))
    }
    return arr;
}

async function main() {
    let [account] = await ethers.getSigners();
    let oktoNFT = await deployNFT(account);
    console.log(oktoNFT);
    let tx = await oktoNFT.setTraitsGen2(getTraitsArr());
    console.log(tx);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })