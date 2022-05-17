pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./interfaces/IMarketplace.sol";
import "./interfaces/IUniswapV2Router.sol";

contract Marketplace is Ownable, IMarketplace {
    uint256 public fee;
    address public lpTokenAddress;
    address public communityTreasure;
    IERC20 public lpToken;

    mapping(address => mapping(uint256 => Order)) public orderByTokenId;
    address public WBNB = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;
    address public ROUTER = 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3;

    IUniswapV2Router swap = IUniswapV2Router(ROUTER);

    constructor(
        uint256 _fee,
        address _lpTokenAddress,
        address _communityTreasure
    ) {
        fee = _fee; // Fee
        lpTokenAddress = _lpTokenAddress; // SNDAddress
        lpToken = IERC20(lpToken); // SND Token
        communityTreasure = _communityTreasure; // Community Treasure Address
    }

    modifier existOrder(address _nftAddress, uint256 _tokenId) {
        require(
            orderByTokenId[_nftAddress][_tokenId].seller != address(0),
            "Marketplace: order is not exist"
        );
        _;
    }

    modifier isActiveOrder(address _nftAddress, uint256 _tokenId) {
        Order storage order = orderByTokenId[_nftAddress][_tokenId];
        require(
            order.orderState == OrderState.Active,
            "Marketplace: item is listing"
        );
        _;
    }

    modifier enoughBalance(address _nftAddress, uint256 _tokenId) {
        require(
            orderByTokenId[_nftAddress][_tokenId].seller != address(0),
            "Marketplace: order is not exist"
        );
        _;
    }

    function createOrder(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _price
    ) public {
        IERC721 nftRegistry = _requireERC721(_nftAddress);
        address nftOwner = nftRegistry.ownerOf(_tokenId);

        Order storage order = orderByTokenId[_nftAddress][_tokenId];

        require(nftOwner == msg.sender, "Marketplace: Only nft owner can list");
        require(_price > 0, "Marketplace: Price should be bigger than 0");
        require(
            order.orderState != OrderState.Active,
            "Marketplace: item is listing"
        );

        nftRegistry.safeTransferFrom(nftOwner, address(this), _tokenId);

        Offer[] memory offers;

        orderByTokenId[_nftAddress][_tokenId] = Order({
            seller: nftOwner,
            nftAddress: _nftAddress,
            price: _price,
            orderState: OrderState.Active,
            offers: offers
        });

        emit OrderCreated(nftOwner, _nftAddress, _tokenId, _price);
    }

    function cancelOrder(address _nftAddress, uint256 _tokenId)
        public
        existOrder(_nftAddress, _tokenId)
        isActiveOrder(_nftAddress, _tokenId)
    {
        Order storage order = orderByTokenId[_nftAddress][_tokenId];
        // require(order.seller == msg.sender || msg.sender == owner(), "Marketplace: unauthorized sender");
        require(order.seller == msg.sender, "Marketplace: unauthorized sender");
        
        order.orderState = OrderState.Canceled;

        uint256 lengthOfOffers = order.offers.length;
        for (uint256 i = 0; i < lengthOfOffers; i++) {
            address offerOwner = order.offers[i].offerOwner;
            if (order.offers[i].canceled == false) {
                order.offers[i].canceled = true;

                lpToken.transferFrom(
                    address(this),
                    offerOwner,
                    order.offers[i].offerPrice
                );
            }
        }

        emit OrderCanceled(_nftAddress, _tokenId);
    }

    function updateOrder(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _newPrice
    ) public existOrder(_nftAddress, _tokenId) isActiveOrder(_nftAddress, _tokenId)
    {
    
        Order storage order = orderByTokenId[_nftAddress][_tokenId];
        require(order.seller == msg.sender, "Marketplace: unauthorized sender");
    
        order.price = _newPrice;

        emit OrderUpdated(_nftAddress, _tokenId, _newPrice);
    }

    function placeOffer(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _amount
    ) public existOrder(_nftAddress, _tokenId) isActiveOrder(_nftAddress, _tokenId) {
        require(
            lpToken.balanceOf(msg.sender) >= _amount,
            "Marketplace: user is not enough token to pay"
        );

        Order storage order = orderByTokenId[_nftAddress][_tokenId];

        require(
            _amount < order.price,
            "Marketplace: offer price must be less than order price"
        );

        // get floorprice
        lpToken.transferFrom(msg.sender, address(this), _amount);

        Offer memory offer = Offer({
            offerOwner: msg.sender,
            offerPrice: msg.value,
            canceled: false
        });

        order.offers.push(offer);

        emit OfferPlaced(msg.sender, _nftAddress, _tokenId, msg.value);
    }

    function cancelOffer(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _offerIndex
    ) public existOrder(_nftAddress, _tokenId) isActiveOrder(_nftAddress, _tokenId) {
        Order storage order = orderByTokenId[_nftAddress][_tokenId];

        require(
            order.offers[_offerIndex].offerOwner == msg.sender,
            "Marketplact: you are not offer owner"
        );
        require(
            order.offers[_offerIndex].canceled == false,
            "Marketplact: offer canceled"
        );


        order.offers[_offerIndex].canceled = true;

        address offerOwner = order.offers[_offerIndex].offerOwner;
        lpToken.transferFrom(
            address(this),
            offerOwner,
            order.offers[_offerIndex].offerPrice
        );

        emit OfferCanceled(msg.sender, _nftAddress, _tokenId);
    }

    function acceptOffer(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _offerIndex
    ) public existOrder(_nftAddress, _tokenId) isActiveOrder(_nftAddress, _tokenId){
        Order storage order = orderByTokenId[_nftAddress][_tokenId];

        require(
            order.seller == msg.sender,
            "Marketplace: you are not order owner"
        );
       
        require(
            order.offers[_offerIndex].canceled == false,
            "Marketplact: offer canceled"
        );
        require(
            order.offers[_offerIndex].offerOwner != address(0),
            "Marketplact: offer is not exist"
        );

        uint256 lengthOfOffers = order.offers.length;

        IERC721 nftRegistry = _requireERC721(_nftAddress);
        address nftOwner = nftRegistry.ownerOf(_tokenId);

        order.orderState = OrderState.Sold;

        for (uint256 i = 0; i < lengthOfOffers; i++) {
            address offerOwner = order.offers[i].offerOwner;
            if (i == _offerIndex) {
                nftRegistry.transferFrom(address(this), offerOwner, _tokenId);
                refundToken(order.offers[i].offerPrice, nftOwner);
            } else {
                if (order.offers[i].canceled == false) {
                    lpToken.transferFrom(
                        address(this),
                        offerOwner,
                        order.offers[i].offerPrice
                    );
                    }
            }
        }
    }

    function refundToken(uint256 orderPrice, address nftOwner) internal {
        uint256 feeOfMarket = (orderPrice * fee) / 100;
        uint256 receiptAmount = orderPrice - feeOfMarket;
        payable(nftOwner).transfer(receiptAmount);
        lpToken.transferFrom(address(this), nftOwner, receiptAmount);

        uint256 amoutForTreasure = (feeOfMarket * 50) / 100;
        uint256 amoutForSN = feeOfMarket - amoutForTreasure;

        lpToken.approve(ROUTER, feeOfMarket);
        address[] memory path_sell = new address[](2);
        path_sell[0] = lpTokenAddress;
        path_sell[1] = WBNB;

        swap.swapExactTokensForETH(
            amoutForTreasure,
            0,
            path_sell,
            snTeam,
            block.timestamp
        );
        swap.swapExactTokensForETH(
            amoutForSN,
            0,
            path_sell,
            communityTreasure,
            block.timestamp
        );
    }

    function buy(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _amount
    ) public existOrder(_nftAddress, _tokenId) isActiveOrder(_nftAddress, _tokenId){
        Order storage order = orderByTokenId[_nftAddress][_tokenId];

        require(lpToken.balanceOf(msg.sender)>= order.price, "Marketplace: balance of user is not enough");
        require(_amount == order.price, "Marketplace: money is not enough");

        lpToken.transferFrom(msg.sender, address(this), _amount);

        order.orderState = OrderState.Sold;

        uint256 lengthOfOffers = order.offers.length;
        for (uint256 i = 0; i < lengthOfOffers; i++) {
            address offerOwner = order.offers[i].offerOwner;
            if (order.offers[i].canceled == false) {
                lpToken.transferFrom(
                    address(this),
                    offerOwner,
                    order.offers[i].offerPrice
                );
            }
        }

        IERC721 nftRegistry = _requireERC721(_nftAddress);
        address nftOwner = nftRegistry.ownerOf(_tokenId);

        nftRegistry.transferFrom(address(this), msg.sender, _tokenId);

        refundToken(order.price, nftOwner);
    }

    function _requireERC721(address _nftAddress) internal view returns (IERC721) {
        require(
            IERC721(_nftAddress).supportsInterface(0x80ac58cd),
            "The NFT contract has an invalid ERC721 implementation"
        );
        return IERC721(_nftAddress);
    }

}
