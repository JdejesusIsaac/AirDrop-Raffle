const { network, ethers } = require("hardhat")
const {
    
    developmentChains,
    INITIAL_SUPPLY,
   
} = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments
    const { deployer} = await getNamedAccounts()
    

    arguments = []
    const Battle = await deploy("ChainBattles", {
        from: deployer,
        args: arguments,
        log: true,

        waitConfirmations: network.config.blockConfirmations || 1,

    })
    log(`our ChainBattle deployed at ${Battle.address}`)
    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        log("Verifying...")
        await verify(Battle.address, arguments)
    }
    
  }