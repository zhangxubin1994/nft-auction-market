// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract Auction is ReentrancyGuard, Ownable {
    enum AuctionStatus { ACTIVE, ENDED, CANCELLED }
    
    struct Bid {
        address bidder;
        uint256 amount;
        uint256 timestamp;
        bool isETH;
    }
    
    address public immutable nftAddress;
    uint256 public immutable tokenId;
    address public immutable seller;
    address public immutable paymentToken; // address(0) for ETH
    uint256 public startTime;
    uint256 public endTime;
    uint256 public reservePrice;
    
    AuctionStatus public status;
    address public highestBidder;
    uint256 public highestBid;
    
    AggregatorV3Interface internal priceFeed;
    
    mapping(address => Bid[]) public bids;
    address[] public bidders;
    
    event BidPlaced(address indexed bidder, uint256 amount, bool isETH);
    event AuctionEnded(address indexed winner, uint256 amount);
    event AuctionCancelled();
    
    constructor(
        address _nftAddress,
        uint256 _tokenId,
        address _seller,
        address _paymentToken,
        uint256 _reservePrice,
        uint256 _duration,
        address _priceFeed
    ) {
        nftAddress = _nftAddress;
        tokenId = _tokenId;
        seller = _seller;
        paymentToken = _paymentToken;
        reservePrice = _reservePrice;
        startTime = block.timestamp;
        endTime = block.timestamp + _duration;
        status = AuctionStatus.ACTIVE;
        priceFeed = AggregatorV3Interface(_priceFeed);
        
        // Transfer NFT to auction contract
        IERC721(_nftAddress).transferFrom(_seller, address(this), _tokenId);
    }
    
    function placeBid(uint256 _amount) external payable nonReentrant {
        require(status == AuctionStatus.ACTIVE, "Auction not active");
        require(block.timestamp < endTime, "Auction ended");
        
        uint256 bidAmount;
        bool isETH;
        
        if (paymentToken == address(0)) {
            // ETH bid
            require(msg.value == _amount, "ETH amount mismatch");
            bidAmount = msg.value;
            isETH = true;
        } else {
            // ERC20 bid
            require(msg.value == 0, "ETH not accepted");
            require(IERC20(paymentToken).transferFrom(msg.sender, address(this), _amount), "Transfer failed");
            bidAmount = _amount;
            isETH = false;
        }
        
        require(bidAmount > highestBid, "Bid too low");
        require(bidAmount >= reservePrice, "Below reserve price");
        
        // Return previous highest bid
        if (highestBidder != address(0)) {
            _returnBid(highestBidder, highestBid, paymentToken == address(0));
        }
        
        highestBidder = msg.sender;
        highestBid = bidAmount;
        
        bids[msg.sender].push(Bid(msg.sender, bidAmount, block.timestamp, isETH));
        bidders.push(msg.sender);
        
        emit BidPlaced(msg.sender, bidAmount, isETH);
    }
    
    function endAuction() external nonReentrant {
        require(status == AuctionStatus.ACTIVE, "Auction not active");
        require(block.timestamp >= endTime, "Auction not ended");
        
        if (highestBidder != address(0)) {
            status = AuctionStatus.ENDED;
            
            // Transfer NFT to winner
            IERC721(nftAddress).transferFrom(address(this), highestBidder, tokenId);
            
            // Transfer funds to seller
            if (paymentToken == address(0)) {
                payable(seller).transfer(highestBid);
            } else {
                IERC20(paymentToken).transfer(seller, highestBid);
            }
            
            emit AuctionEnded(highestBidder, highestBid);
        } else {
            status = AuctionStatus.CANCELLED;
            // Return NFT to seller
            IERC721(nftAddress).transferFrom(address(this), seller, tokenId);
            emit AuctionCancelled();
        }
    }
    
    function getBidInUSD(uint256 _bidAmount) public view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        uint8 decimals = priceFeed.decimals();
        
        // Convert bid amount to USD
        return (_bidAmount * uint256(price)) / (10 ** decimals);
    }
    
    function getAuctionDetails() external view returns (
        address, uint256, address, uint256, uint256, uint256, AuctionStatus, address, uint256
    ) {
        return (
            nftAddress,
            tokenId,
            seller,
            startTime,
            endTime,
            reservePrice,
            status,
            highestBidder,
            highestBid
        );
    }
    
    function _returnBid(address _bidder, uint256 _amount, bool _isETH) internal {
        if (_isETH) {
            payable(_bidder).transfer(_amount);
        } else {
            IERC20(paymentToken).transfer(_bidder, _amount);
        }
    }
}