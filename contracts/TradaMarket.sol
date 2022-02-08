// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./IERC721.sol";

contract TradaMarket {


    enum ListingStatus {
        ACTIVE,
        SOLD,
        CANCELLED
    }

    struct Listing{
        address seller;
        address token;
        string symbol;
        uint tokenId;
        uint price;
        ListingStatus status;        
    }

    event Listed(
        address seller,
        address token,
        string symbol,
        uint tokenId,
        uint price

    );

    event Sold(
        uint listingId,
        address buyer,
        address token,
        uint tokenId,
        string symbol,
        uint price
    );

    event Canceled(
        address seller,
        uint listingId,
        address token,
        uint tokenId
    );

    uint private _listingId = 0;
    mapping(uint =>Listing) private _listings;

    function getListing(uint _listingId) public view returns (Listing memory){
        return _listings[_listingId];
    }

    function listToken(address token, string memory symbol, uint tokenId, uint price) private {
        IERC721(token).transferFrom(msg.sender, address(this), tokenId);
        Listing memory listing = Listing(
            msg.sender,
            token,
            symbol,
            tokenId,
            price * 1 ether,
            ListingStatus.ACTIVE
        );

        _listingId ++;
        _listings[_listingId] = listing;

        emit Listed(msg.sender, token, symbol, tokenId, price);
        
    }

    function buyToken(uint listingId) external payable {
        Listing storage listing = _listings[listingId];
        require(listing.status == ListingStatus.ACTIVE, "Listing is not active !");
        require(msg.sender!=listing.seller, "Seller cannot buyer !");
        require(msg.value >=listing.price, "Not enough to payment !");

        listing.status = ListingStatus.SOLD;
        IERC721(listing.token).transferFrom(address(this), msg.sender, listing.tokenId);
        payable(listing.seller).transfer(listing.price);
        
        emit Sold(listingId, msg.sender, listing.token, listing.tokenId, listing.symbol, listing.price);

    }

    function cancel(uint listingId) private {
        Listing storage listing = _listings[listingId];
        require(listing.status == ListingStatus.ACTIVE, "Listing is not active");
        require(listing.seller == msg.sender, "User is not seller");

        listing.status = ListingStatus.CANCELLED;
        IERC721(listing.token).transferFrom(address(this), msg.sender, listing.tokenId);
        emit Canceled(msg.sender, listingId, listing.token, listing.tokenId);
    }

}