pragma solidity ^0.8.6;

interface IMarketplace {

    struct Order {
        address seller;
        address nftAddress;
        uint256 price;
        OrderState orderState;
        Offer[] offers;
    }

    enum OrderState {
        Active,
        Canceled,
        Sold
    }

    struct Offer {
        address offerOwner;
        uint256 offerPrice;
        bool canceled;
    }

     enum OfferState {
        Active,
        Canceled,
        Accepted
    }

    // ORDER EVENTS
    event OrderCreated(
        address indexed seller,
        address indexed nftAddress,
        uint256 tokenId,
        uint256 price
    );

    event OrderCanceled(
        address indexed nftAddress,
        uint256 tokenId
    );

    event OrderUpdated(
        address indexed nftAddress,
        uint256 tokenId,
        uint256 newPrice
    );

    event OfferPlaced(
        address indexed offerOwner,
        address indexed nftAddress,
        uint256 tokenId,
        uint256 newPrice
    );

    event OfferCanceled(
        address indexed offerOwner,
        address indexed nftAddress,
        uint256 tokenId
    );

}