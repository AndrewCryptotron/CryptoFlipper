const { ethers, network } = require("hardhat")

async function mockKeepers() {
    const CryptotronLottery = await ethers.getContract("CryptotronLottery")
    const checkData = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(""))
    const { upkeepNeeded } = await CryptotronLottery.callStatic.checkUpkeep(checkData)
    if (upkeepNeeded) {
        const tx = await CryptotronLottery.performUpkeep(checkData)
        const txReceipt = await tx.wait(1)
        const requestId = txReceipt.events[1].args.requestId
        console.log(`Performed upkeep with RequestId: ${requestId}`)
        if (network.config.chainId == 31337) {
            await mockVrf(requestId, CryptotronLottery)
        }
    } else {
        console.log("No upkeep needed!")
    }
}

async function mockVrf(requestId, CryptotronLottery) {
    console.log("We on a local network? Ok let's pretend...")
    const vrfCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock")
    await vrfCoordinatorV2Mock.fulfillRandomWords(requestId, CryptotronLottery.address)
    console.log("Responded!")
    const recentWinner = await CryptotronLottery.getRecentWinner()
    console.log(`The winner is: ${recentWinner}`)
}

mockKeepers()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })