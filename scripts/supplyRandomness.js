var sqlite = require('sqlite3').verbose();

const mode = "local";
let randomOracleAddress;

if(mode == "test") randomOracleAddress = "0x031bDd9979eCA1AE93Ffd84B6f52cc1Bb4642c77";
else if(mode == "local") randomOracleAddress = "0x5fbdb2315678afecb367f032d93f642f64180aa3";

async function main() {
    let randomOracle = await ethers.getContractAt("IRandomOracle", randomOracleAddress);
    let Hasher = await ethers.getContractFactory("Hasher");
    let hasher = await Hasher.deploy();
    let pendingBuffer = ethers.BigNumber.from(50);
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
        let valid = true;
        let numPosted = await randomOracle.numPosted().catch((e) => {
            console.error(e);
            valid = false;
        });
        let numPending = await randomOracle.numPending().catch((e) => {
            console.error(e);
            valid = false;
        });
        let numFulfilled = await randomOracle.numFulfilled().catch((e) => {
            console.error(e);
            valid = false;
        });
        if(!valid) {
            setTimeout(post, 10000);
            return;
        }
        numFulfilled = numFulfilled.add(numSkipped);
        console.log("posted:",numPosted,"pending:",numPending,"fulfilled:",numFulfilled)
        
        let toFulfill = [];
        for(let i = 0; numPending.sub(numFulfilled).gt(i); i++) {
            let idx = numFulfilled.toNumber()+i;
            if(skiplist[idx] != undefined) continue;
            console.log("fulfilling, idx:",idx);
            let val = await new Promise(res => {
                db.get("SELECT val FROM idToVal WHERE id = " + idx, (err, val) => {
                    res(val);
                })
            });
            if(val == null) {
                console.log("skipping id:",idx);
                skiplist[idx] = true;
                numSkipped++;
                continue;
            }
            val = val.val;
            toFulfill.push({idx, val});
        }
        console.log("toFulfill:",toFulfill);
        for(let i = 0; i < Math.floor(toFulfill.length / 10); i++) {
            let ids = [];
            let vals = [];
            for(let j = 0; j < 10; j++) {
                let both = toFulfill[i*10+j];
                ids.push(both.idx);
                vals.push(both.val);
            }
            let tx = await randomOracle.fulfillBatch(vals, ids, {gasPrice: "200000000000"}).catch((e) => {
                console.error(e);
            });
            await tx.wait().catch((e) => {
                console.error(e);
            });
        }
        if(toFulfill.length % 10 != 0) {
            let ids = [];
            let vals = [];
            for(let j = 0; j < toFulfill.length % 10; j++) {
                let both = toFulfill[toFulfill.length - (toFulfill.length % 10) + j];
                ids.push(both.idx);
                vals.push(both.val);
            }
            let tx = await randomOracle.fulfillBatch(vals, ids, {gasPrice: "200000000000"}).catch((e) => {
                console.error(e);
            });
            await tx.wait().catch((e) => {
                console.error(e);
            });
        }
        
        let toPost = [];
        console.log("buffer:",pendingBuffer,"numPosted:",numPosted,"pending:",numPending,"all:",pendingBuffer.sub(numPosted).add(numPending))
        for(let i = 0; pendingBuffer.sub(numPosted).add(numPending).gt(i); i++) {
            let idx = numPosted.toNumber()+i;
            let val = web3.utils.randomHex(16);
            let hash = await hasher.hashSeed(val).catch((e) => {
                console.error(e);
            });
            toPost.push({hash, idx});
            await new Promise(res => {
                db.run("INSERT INTO idToVal (id, val) VALUES ("+(idx)+', "'+val+'")', res)
            });
        }
        console.log("toPost:",toPost);
        for(let i = 0; i < Math.floor(toPost.length / 50); i++) {
            let ids = [];
            let hashes = [];
            for(let j = 0; j < 50; j++) {
                let both = toPost[i*50+j];
                ids.push(both.idx);
                hashes.push(both.hash);
            }
            console.log("ids:",ids,"hashes:",hashes)
            let tx = await randomOracle.postBatch(hashes, ids, {gasPrice: "200000000000"}).catch((e) => {
                console.error(e);
            });
            await tx.wait().catch((e) => {
                console.error(e);
            });
        }
        if(toPost.length % 50 != 0) {
            let ids = [];
            let hashes = [];
            for(let j = 0; j < toPost.length % 50; j++) {
                let both = toPost[toPost.length - (toPost.length % 50) + j];
                ids.push(both.idx);
                hashes.push(both.hash);
            }
            let tx = await randomOracle.postBatch(hashes, ids, {gasPrice: "200000000000"}).catch((e) => {
                console.error(e);
            });
            await tx.wait().catch((e) => {
                console.error(e);
            });
        }


        let delta = 10000 - Date.now() + startTime;
        delta > 0 ? setTimeout(post, delta) : post();
    }
    post();
}

main()