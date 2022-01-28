//Encode JSON for upload to chain
let fs = require("fs");

let ignoredTraits = {
    "Type": true,
    "Body": true,
    "Eyes": true,
    "Mouth": true
}
//convert binary string to hex string
function bin2hex(bin) {
    let hex = "0x";
    for(let i = 0; i < bin.length / 4; i++) {
        hex += parseInt(bin.slice(i, i+4), 2).toString(16);
    }
    return hex;
}

//Get random 'alpha' level for squid
function randomAlpha() {
    return Math.floor(Math.random() * 4) + 5;
}

function main() {
    let encoded = [];
    for(let i = 1; i <= 27500; i++) {
        let data = JSON.parse(fs.readFileSync("metadata/json/"+i+".json", "UTF-8"));
        let traitCount = 0;
        let squid;
        if(i % 10000 == 0) console.log("Reading metadata",i);
        for(let j = 0; j < data.attributes.length; j++) {
            let trait = data.attributes[j];
            if(trait.trait_type == "Type") squid = trait.value != "Okto";
            else if(!ignoredTraits[trait.trait_type] && trait.value != "0") traitCount++;
        }
        let encoding = (data.rarity << 4) | (squid ? randomAlpha() : traitCount);
        encoded.push(encoding);
    }
    let compressedBinary = [];
    for(let i = 0; i < Math.ceil(encoded.length / 42); i++) {
        compressedBinary.push("");
        if(i % 100 == 0) console.log("compressing binary",i);
        for(let j = 0; j < 42; j++) {
            let bin;
            if(i*42 + j < encoded.length) bin = encoded[i*42 + j].toString(2);
            else bin = "000000";
            for(let k = 0; k < 6 - bin.length; k++) bin = "0" + bin;
            compressedBinary[i] += bin;
        }
        for(let j = 0; j < 256-compressedBinary[i].length; j++) compressedBinary[i] += "0";
    }
    let compressedHex = [];
    for(let i = 0; i < compressedBinary.length; i++) {
        if(i % 100 == 0) console.log("hexified binary",i);
        compressedHex.push(bin2hex(compressedBinary[i]));
    }

    fs.writeFileSync("metadata/encoding.json",JSON.stringify(compressedHex));
}

main()