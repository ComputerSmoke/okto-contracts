var sqlite = require('sqlite3').verbose();

const mode = "test";
let randomOracleAddress;

if(mode == "test") randomOracleAddress = "0x2212F7dfe08fA71b2bC7319588145A56275aF525";
else if(mode == "local") randomOracleAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3";

async function main() {
    let randomOracle = await ethers.getContractAt("IRandomOracle", randomOracleAddress);
    let Hasher = await ethers.getContractFactory("Hasher");
    let hasher = await Hasher.deploy();
    let pendingBuffer = ethers.BigNumber.from(500);
    let db = new sqlite.Database("./data.db");
    let skiplist = {};
    let numSkipped = 0;
    await new Promise(res => {
        db.run(`CREATE TABLE IF NOT EXISTS idToVal (
            id INT NOT NULL PRIMARY KEY,
            val STRING NOT NULL
        )`, res)
    });
    await new Promise(res => {
        db.run("CREATE UNIQUE INDEX IF NOT EXISTS idx_id ON idToVal (id)", res)
    });
    
    async function post() {
        let startTime = Date.now();
        let numPosted = await randomOracle.numPosted();
        let numPending = await randomOracle.numPending();
        let numFulfilled = await randomOracle.numFulfilled();
        numFulfilled = numFulfilled.add(numSkipped);
        console.log("posted:",numPosted,"pending:",numPending,"fulfilled:",numFulfilled)
        
        for(let i = 0; numPending.sub(numFulfilled).gt(i); i++) {
            if(skiplist[numFulfilled.toNumber()+i] != undefined) continue;
            console.log("fulfilling, idx:",numFulfilled.toNumber()+i);
            let val = await new Promise(res => {
                db.get("SELECT val FROM idToVal WHERE id = " + (numFulfilled.toNumber()+i), (err, val) => {
                    res(val);
                })
            });
            if(val == null) {
                console.log("skipping id:",(numFulfilled.toNumber()+i));
                skiplist[numFulfilled.toNumber()+i] = true;
                numSkipped++;
                continue;
            }
            val = val.val;
            let tx = await randomOracle.fulfillRandomness(val, numFulfilled.add(i), {gasPrice: "200000000000"});
            await tx.wait();
        }
        
        console.log("buffer:",pendingBuffer,"numPosted:",numPosted,"pending:",numPending,"all:",pendingBuffer.sub(numPosted).add(numPending))
        for(let i = 0; pendingBuffer.sub(numPosted).add(numPending).gt(i); i++) {
            let val = web3.utils.randomHex(16);
            let hash = await hasher.hashSeed(val)
            console.log("posting hash:",hash);
            let tx = await randomOracle.postHash(hash, numPosted.add(i), {gasPrice: "200000000000"});
            await tx.wait();
            console.log("writing id"+(numPosted.toNumber()+i));
            await new Promise(res => {
                db.run("INSERT INTO idToVal (id, val) VALUES ("+(numPosted.toNumber()+i)+", "+val+")", res)
            });
        }
        let delta = 10000 - Date.now() + startTime;
        delta > 0 ? setTimeout(post, delta) : post();
    }
    post();
}

main()