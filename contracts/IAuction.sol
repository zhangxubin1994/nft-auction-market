// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IAuction {
    enum AuctionStatus { ACTIVE, ENDED, CANCELLED }
    
    function placeBid(uint256 _amount) external payable;
    function endAuction() external;
    function getBidInUSD(uint256 _bidAmount) external view returns (uint256);
    function getAuctionDetails() external view returns (
        address, uint256, address, uint256, uint256, uint256, AuctionStatus, address, uint256
    );
}