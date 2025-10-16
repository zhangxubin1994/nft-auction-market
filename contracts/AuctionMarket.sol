// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./AuctionFactory.sol";
import "./MyNFT.sol";

contract AuctionMarket is UUPSUpgradeable, OwnableUpgradeable {
    AuctionFactory public auctionFactory;
    MyNFT public nftContract;
    
    uint256 public platformFee; // in basis points (100 = 1%)
    address public feeRecipient;
    
    mapping(address => bool) public authorizedCurators;
    
    event PlatformFeeUpdated(uint256 newFee);
    event CuratorAuthorized(address curator);
    event CuratorRevoked(address curator);
    
    function initialize(
        address _nftContract,
        address _factory,
        uint256 _platformFee,
        address _feeRecipient
    ) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        
        nftContract = MyNFT(_nftContract);
        auctionFactory = AuctionFactory(_factory);
        platformFee = _platformFee;
        feeRecipient = _feeRecipient;
    }
    
    function createAuction(
        uint256 _tokenId,
        address _paymentToken,
        uint256 _reservePrice,
        uint256 _duration
    ) external returns (address) {
        require(nftContract.ownerOf(_tokenId) == msg.sender, "Not NFT owner");
        require(nftContract.isApprovedForAll(msg.sender, address(this)), "Not approved");
        
        return auctionFactory.createAuction(
            address(nftContract),
            _tokenId,
            _paymentToken,
            _reservePrice,
            _duration
        );
    }
    
    function mintAndCreateAuction(
        string memory _tokenURI,
        address _paymentToken,
        uint256 _reservePrice,
        uint256 _duration
    ) external returns (uint256, address) {
        uint256 tokenId = nftContract.safeMint(msg.sender, _tokenURI);
        nftContract.approve(address(this), tokenId);
        
        address auction = auctionFactory.createAuction(
            address(nftContract),
            tokenId,
            _paymentToken,
            _reservePrice,
            _duration
        );
        
        return (tokenId, auction);
    }
    
    function setPlatformFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 1000, "Fee too high"); // Max 10%
        platformFee = _newFee;
        emit PlatformFeeUpdated(_newFee);
    }
    
    function setFeeRecipient(address _newRecipient) external onlyOwner {
        require(_newRecipient != address(0), "Invalid address");
        feeRecipient = _newRecipient;
    }
    
    function authorizeCurator(address _curator) external onlyOwner {
        authorizedCurators[_curator] = true;
        emit CuratorAuthorized(_curator);
    }
    
    function revokeCurator(address _curator) external onlyOwner {
        authorizedCurators[_curator] = false;
        emit CuratorRevoked(_curator);
    }
    
    // UUPS upgrade authorization
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    // Additional functions for dynamic fee calculation
    function calculateDynamicFee(uint256 _salePrice) public view returns (uint256) {
        if (_salePrice < 1 ether) {
            return platformFee; // Base fee for small sales
        } else if (_salePrice < 10 ether) {
            return platformFee * 80 / 100; // 20% discount for medium sales
        } else {
            return platformFee * 60 / 100; // 40% discount for large sales
        }
    }
}