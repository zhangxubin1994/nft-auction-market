// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Auction.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract AuctionFactory is Initializable {
    mapping(address => address[]) public userAuctions;
    mapping(address => bool) public supportedTokens;
    mapping(address => address) public tokenPriceFeeds;
    
    address[] public allAuctions;
    address public owner;
    
    event AuctionCreated(
        address indexed auction,
        address indexed nftAddress,
        uint256 indexed tokenId,
        address seller,
        address paymentToken,
        uint256 reservePrice,
        uint256 duration
    );
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    function initialize() public initializer {
        owner = msg.sender;
    }
    
    function createAuction(
        address _nftAddress,
        uint256 _tokenId,
        address _paymentToken,
        uint256 _reservePrice,
        uint256 _duration
    ) external returns (address) {
        require(supportedTokens[_paymentToken], "Payment token not supported");
        
        Auction newAuction = new Auction(
            _nftAddress,
            _tokenId,
            msg.sender,
            _paymentToken,
            _reservePrice,
            _duration,
            tokenPriceFeeds[_paymentToken]
        );
        
        address auctionAddress = address(newAuction);
        
        userAuctions[msg.sender].push(auctionAddress);
        allAuctions.push(auctionAddress);
        
        emit AuctionCreated(
            auctionAddress,
            _nftAddress,
            _tokenId,
            msg.sender,
            _paymentToken,
            _reservePrice,
            _duration
        );
        
        return auctionAddress;
    }
    
    function addSupportedToken(address _token, address _priceFeed) external onlyOwner {
        supportedTokens[_token] = true;
        tokenPriceFeeds[_token] = _priceFeed;
    }
    
    function removeSupportedToken(address _token) external onlyOwner {
        supportedTokens[_token] = false;
        tokenPriceFeeds[_token] = address(0);
    }
    
    function getUserAuctions(address _user) external view returns (address[] memory) {
        return userAuctions[_user];
    }
    
    function getAllAuctions() external view returns (address[] memory) {
        return allAuctions;
    }
    
    function getAuctionsCount() external view returns (uint256) {
        return allAuctions.length;
    }
}