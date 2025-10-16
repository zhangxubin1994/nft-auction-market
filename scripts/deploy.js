const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // Deploy NFT contract
  const MyNFT = await ethers.getContractFactory("MyNFT");
  const nft = await MyNFT.deploy("MyNFT", "MNFT");
  await nft.deployed();
  console.log("MyNFT deployed to:", nft.address);

  // Deploy AuctionFactory
  const AuctionFactory = await ethers.getContractFactory("AuctionFactory");
  const factory = await AuctionFactory.deploy();
  await factory.deployed();
  console.log("AuctionFactory deployed to:", factory.address);

  // Initialize factory
  await factory.initialize();
  console.log("AuctionFactory initialized");

  // Deploy AuctionMarket (UUPS upgradeable)
  const AuctionMarket = await ethers.getContractFactory("AuctionMarket");
  const market = await upgrades.deployProxy(AuctionMarket, [
    nft.address,
    factory.address,
    250, // 2.5% platform fee
    deployer.address
  ], { initializer: 'initialize' });
  await market.deployed();
  console.log("AuctionMarket deployed to:", market.address);

  // Add supported tokens (ETH and example ERC20)
  const ethPriceFeed = "0x694AA1769357215DE4FAC081bf1f309aDC325306"; // ETH/USD Sepolia
  await factory.addSupportedToken(ethers.constants.AddressZero, ethPriceFeed);
  console.log("ETH added as supported token");

  // Save deployment info
  const deploymentInfo = {
    network: network.name,
    nft: nft.address,
    factory: factory.address,
    market: market.address,
    deployer: deployer.address,
    timestamp: new Date().toISOString()
  };

  console.log("Deployment completed:", deploymentInfo);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });