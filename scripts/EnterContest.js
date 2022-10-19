const { ethers, getNamedAccounts } = require("hardhat")

async function enterContests() {
    const { deployer } = await getNamedAccounts()
    const contestName = 'Dropy3'
    const winnersCount = 1
    const contestantAddressArray = ["0x6869674A3E032B0678bb1bcaD681A0fe375F8BBf", "0x20f3c530aeD28d26cE5AE6d5d7E9b1DF249b5e0D", "0x1aF79b22fDb9617BD9622F1E99582Adb80912C57"] //   900, "https://gateway.pinata.cloud/ipfs/QmZ6X8XBfjS8HX2wYfns7KqRX9KKqibvmpuFXj5PXdcgMB", 1
    const date =  1665342907

    const imageURL = "https://gateway.pinata.cloud/ipfs/QmZ6X8XBfjS8HX2wYfns7KqRX9KKqibvmpuFXj5PXdcgMB"
    const prizeWorth = 1
    const contestantSettlement = 2

    const raffle = await ethers.getContract("VibraPawn", deployer)
    console.log(`Got contract vRFconsumer at ${raffle.address}`)
   
    const transactionResponse = await raffle.configureNewAirdrop(contestName, winnersCount, contestantAddressArray, date, imageURL, prizeWorth, contestantSettlement) //
    await transactionResponse.wait()
    console.log("AirDropConfigured!")
} 

enterContests()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })