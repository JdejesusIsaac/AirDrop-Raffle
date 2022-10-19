
  
  

  const { network, ethers } = require("hardhat")
const {
    
    developmentChains,
    INITIAL_SUPPLY,
   
} = require("../helper-hardhat-config")
const { verify } = require("../utils/verify")

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy, log } = deployments
    const { deployer} = await getNamedAccounts()
    const FUND_AMOUNT = ethers.utils.parseEther("0.1")


   

    
    
    
    const Token = await deploy("VibraToken", {
      from: deployer,
      args: [INITIAL_SUPPLY],
      log: true,
      // we need to wait if on a live network so we can verify properly
      waitConfirmations: network.config.blockConfirmations || 1,
    })
    log(`ourToken deployed at ${Token.address}`)

    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        log("Verifying...")
        await verify(Token.address, [INITIAL_SUPPLY])
    }
    const VibraAdd =  "0xB1A930fA68E4093E2BE6396D83e249bDB4b2ef6E"
    const buyer = "0x6869674A3E032B0678bb1bcaD681A0fe375F8BBf"
    const seller = "0x20f3c530aeD28d26cE5AE6d5d7E9b1DF249b5e0D"
    const parent = "0xECFeDE31E564C97Ab05ABE88786dFb2A642f69f2"
    const child = "0x1aF79b22fDb9617BD9622F1E99582Adb80912C57"
    const nombre = "John"
    const subscriptionId = 3062;

   
    const arguments = [
        VibraAdd,
        FUND_AMOUNT,
        buyer,
        seller,
    ]
    const arguments1 = [
        subscriptionId,

    ]
    const arguments2 = [
        subscriptionId,

    ]


    const escrow = await deploy("Escrow", {
        from: deployer,
        args: arguments,
        log: true,

        waitConfirmations: network.config.blockConfirmations || 1,

    })
    log(`our ESCROW deployed at ${escrow.address}`)
    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        log("Verifying...")
        await verify(escrow.address, arguments)
    }
    const drop = await deploy("VibraPawn", {
        from: deployer,
        args: arguments1,
        log: true,

        waitConfirmations: network.config.blockConfirmations || 1,

    })
    log(`our webshop deployed at ${drop.address}`)
    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        log("Verifying...")
        await verify(drop.address, arguments1)
    }

    const airdrop = await deploy("airDrop", {
        from: deployer,
        args: arguments2,
        log: true,

        waitConfirmations: network.config.blockConfirmations || 1,

    })
    log(`our AIRDROP deployed at ${airdrop.address}`)
    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        log("Verifying...")
        await verify(airdrop.address, arguments2)
    }
    

    

    
    
   


  
    //if (
      //!developmentChains.includes(network.name) &&
      //process.env.ETHERSCAN_API_KEY
    //) //{
      //await verify(VibraToken.address, [INITIAL_SUPPLY])
    //}
  }
  
  module.exports.tags = ["all", "Token", "escrow", "shop"]