const randomOracleAddress = "0x5fbdb2315678afecb367f032d93f642f64180aa3";

async function main() {
    let randomOracle = await ethers.getContractAt("IRandomOracle", randomOracleAddress);
    let Hasher = await ethers.getContractFactory("Hasher");
    let hasher = await Hasher.deploy();
    let pendingBuffer = ethers.BigNumber.from(500);
    let idToVal = {};
    setInterval(async () => {
        let numPosted = await randomOracle.numPosted();
        let numPending = await randomOracle.numPending();
        let numFulfilled = await randomOracle.numFulfilled();
        console.log("posted:",numPosted,"pending:",numPending,"fulfilled:",numFulfilled)
        await new Promise(res => {
            let count = 0;
            if(count == numPending.sub(numFulfilled)) res();
            for(let i = 0; numPending.sub(numFulfilled).gt(i); i++) {
                console.log("fulfilling, i:",i)
                randomOracle.fulfillRandomness(idToVal[numFulfilled.toNumber()+i], numFulfilled.add(i)).then(() => {
                    count++;
                    if(count == numPending.sub(numFulfilled)) res();
                });
            }
        });
        await new Promise(async (res) => {
            let count = 0;
            if(count == pendingBuffer.sub(numPosted).add(numPending)) res();
            console.log("buffer:",pendingBuffer,"numPosted:",numPosted,"pending:",numPending,"all:",pendingBuffer.sub(numPosted).add(numPending))
            for(let i = 0; pendingBuffer.sub(numPosted).add(numPending).gt(i); i++) {
                let val = Math.floor(Math.random()*10000000);
                hasher.hashSeed(val).then((hash) => {
                    randomOracle.postHash(hash, numPosted.add(i)).then(() => {
                        count++;
                        idToVal[numPosted.toNumber()+i] = val;
                        console.log("id:",numPosted.toNumber()+i,"val:",val);
                        if(count == pendingBuffer.sub(numPosted).add(numPending)) res();
                    });
                });
            }
        })
    }, 10000);
}

main()