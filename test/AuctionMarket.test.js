const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("NFT Auction Market", function () {
  let nft, factory, market;
  let owner, seller, bidder1, bidder2;

  beforeEach(async function () {
    [owner, seller, bidder1, bidder2] = await ethers.getSigners();

    // Deploy NFT
    const MyNFT = await ethers.getContractFactory("MyNFT");
    nft = await MyNFT.deploy("Test NFT", "TNFT");
    await nft.deployed();

    // Deploy Factory
    const AuctionFactory = await ethers.getContractFactory("AuctionFactory");
    factory = await AuctionFactory.deploy();
    await factory.deployed();
    await factory.initialize();

    // Deploy Market
    const AuctionMarket = await ethers.getContractFactory("AuctionMarket");
    market = await upgrades.deployProxy(AuctionMarket, [
      nft.address,
      factory.address,
      250, // 2.5% fee
      owner.address
    ], { initializer: 'initialize' });
    await market.deployed();

    // Add ETH as supported token
    const ethPriceFeed = "0x694AA1769357215DE4FAC081bf1f309aDC325306"; // Sepolia ETH/USD
    await factory.addSupportedToken(ethers.constants.AddressZero, ethPriceFeed);
  });

  describe("NFT Contract", function () {
    it("Should mint NFT successfully", async function () {
      await nft.safeMint(seller.address, "ipfs://test1");
      expect(await nft.ownerOf(0)).to.equal(seller.address);
    });
  });

  describe("Auction Creation", function () {
    beforeEach(async function () {
      // Mint NFT to seller
      await nft.connect(seller).safeMint(seller.address, "ipfs://test1");
      await nft.connect(seller).setApprovalForAll(market.address, true);
    });

    it("Should create auction successfully", async function () {
      await expect(
        market.connect(seller).createAuction(
          0,
          ethers.constants.AddressZero, // ETH
          ethers.utils.parseEther("1.0"),
          86400 // 1 day
        )
      ).to.emit(factory, "AuctionCreated");
    });

    it("Should mint and create auction in one transaction", async function () {
      const tx = await market.connect(seller).mintAndCreateAuction(
        "ipfs://test2",
        ethers.constants.AddressZero,
        ethers.utils.parseEther("1.0"),
        86400
      );
      
      await expect(tx).to.emit(factory, "AuctionCreated");
    });
  });

  describe("Bidding", function () {
    let auctionAddress;

    beforeEach(async function () {
      // Mint NFT and create auction
      await nft.connect(seller).safeMint(seller.address, "ipfs://test1");
      await nft.connect(seller).setApprovalForAll(market.address, true);
      
      const tx = await market.connect(seller).createAuction(
        0,
        ethers.constants.AddressZero,
        ethers.utils.parseEther("1.0"),
        86400
      );
      
      const receipt = await tx.wait();
      const event = receipt.events.find(e => e.event === "AuctionCreated");
      auctionAddress = event.args.auction;
    });

    it("Should place bid successfully", async function () {
      const auction = await ethers.getContractAt("Auction", auctionAddress);
      
      await expect(
        auction.connect(bidder1).placeBid(ethers.utils.parseEther("1.5"), {
          value: ethers.utils.parseEther("1.5")
        })
      ).to.emit(auction, "BidPlaced");
    });

    it("Should reject bid below reserve price", async function () {
      const auction = await ethers.getContractAt("Auction", auctionAddress);
      
      await expect(
        auction.connect(bidder1).placeBid(ethers.utils.parseEther("0.5"), {
          value: ethers.utils.parseEther("0.5")
        })
      ).to.be.revertedWith("Below reserve price");
    });
  });

  describe("Upgradeability", function () {
    it("Should upgrade contract successfully", async function () {
      const AuctionMarketV2 = await ethers.getContractFactory("AuctionMarket");
      const marketV2 = await upgrades.upgradeProxy(market.address, AuctionMarketV2);
      
      expect(await marketV2.version()).to.not.be.undefined;
    });
  });
});