const randomOracleAddress = "";

async function main() {
    let randomOracle = ethers.getContractAt("IRandomOracle", randomOracleAddress);
    let Hasher = await ethers.getContractFactory("hasher");
    let hasher = await Hasher.deploy();
    let pendingBuffer = 500;
    let idToVal = {};
    setInterval(async () => {
        let numPosted = await randomOracle.numPosted();
        let numPending = await randomOracle.numPending();
        let numFulfilled = await randomOracle.numFulfilled();
        await new Promise(res => {
            let count = 0;
            for(let i = 0; i < numPending - numFulfilled; i++) {
                randomOracle.fulfillRandomness(idToVal[numPending+i], numPending+i).then(() => {
                    count++;
                    if(count == numPending - numFulfilled) res();
                });
            }
        });
        await new Promise(res => {
            let count = 0;
            for(let i = 0; i < pendingBuffer - numPosted + numPending; i++) {
                let val = Math.floor(Math.random()*10000000);
                hasher.hashSeed(val).then((hash) => {
                    randomOracle.postHash(hash, numPosted+i).then(() => {
                        count++;
                        idToVal[numPosted+i] = val;
                        if(count == pendingBuffer - numPosted + numPending) res();
                    });
                });
            }
        })
    }, 100);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })