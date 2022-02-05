const aquariumAddress = "0xE6ca8b3dbc174342481Ece6AAdF35E72b1ACEa70";

async function main() {
    let aquarium = await ethers.getContractAt("Aquarium", aquariumAddress);
    let tx = await aquarium.setOpenMint();
    await tx.wait();
}

main();