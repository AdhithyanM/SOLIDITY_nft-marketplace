// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// INTERNAL IMPORT FOR NFT OPENZEPPELIN
import "@openzeppelin/contracts/utils/Counters.sol";  // Using as a counter to track how many nfts are getting created/sold/users
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "hardhat/console.sol";

contract NFTMarketplace is ERC721URIStorage {
  using Counters for Counters.Counter;

  // STATE VARIABLES
  Counters.Counter private _tokenIds;   // total no.of.NFTs there in the market place
  Counters.Counter private _itemsSold;  // no.of.NFTs that are actually sold in the market place
  uint256 listingPrice = 0.0025 ether;  // default listing price
  address payable owner;                // owner of this smart contract (market place)
  mapping(uint256 => MarketItem) private idMarketItem;
  /* 
    Every NFT will have an unique ID and we will pass that ID in this mapping.
    the MarketItem is a struct which will have details about a particular NFT.
  */
  struct MarketItem {
    uint256 tokenId;
    address payable seller;
    address payable owner;
    uint256 price;
    bool sold;
  }

  // EVENTS
  // whenever any kind of transaction happens we will trigger an event
  event idMarketItemCreated(
    uint256 indexed tokenId,
    address seller,
    address owner,
    uint256 price,
    bool sold
  );

  // MODIFIERS
  modifier onlyOwner() {
    require(msg.sender == owner, "only owner of the marketplace can change the listing price"); 
    _;
  }

  // Initializes the contract by setting a `name` and a `symbol` to the token collection.
  constructor() ERC721("NFT Metaverse Token", "MYNFT") {
    owner == payable(msg.sender);
  }

  function updateListingPrice(uint256 _listingPrice) public payable onlyOwner {
    listingPrice = _listingPrice;
  }

  function getListingPrice() public view returns(uint256) {
    return listingPrice;
  }

  /**
   * function to create nft token
   * @param tokenURI URL of a particular NFT
   * @param price listing price
   * returns tokenId for the NFT
   */
  function createToken(string memory tokenURI, uint256 price) public payable returns(uint256) {
    _tokenIds.increment();

    uint256 newTokenId = _tokenIds.current();

    _mint(msg.sender, newTokenId);
    _setTokenURI(newTokenId, tokenURI);

    createMarketItem(newTokenId, price);

    return newTokenId;
  }
  
  /**
   * function to create market item (NFT)
   * @param tokenId unique ID for an NFT
   * @param price listing price
   * creates a market item with that unique token id
   * transfers the item to the smart contract
   * emits the event idMarketItemCreated to the blockchain informing the tokenId, sender, owner, price and sold or not.
   */
  function createMarketItem(uint256 tokenId, uint256 price) private {
    require(price > 0, "Price must be atleast 1");
    require(msg.value == listingPrice, "Price must be equal to listing price");

    idMarketItem[tokenId] = MarketItem(
      tokenId,
      payable(msg.sender),      // seller 
      payable(address(this)),   // owner is set to this smart contract when creating
      price,
      false
    );

    _transfer(msg.sender, address(this), tokenId);

    emit idMarketItemCreated(tokenId, msg.sender, address(this), price, false);
  }
  
  /**
   * function to resell market item (NFT)
   * @param tokenId unique ID for an NFT
   * @param price reselling price
   * alters the details of the market item and transfers it to the smart contract
   */
  function resellToken(uint256 tokenId, uint256 price) public payable {
    require(idMarketItem[tokenId].owner == msg.sender, "Only the NFT owner can perform this operation");
    require(msg.value == listingPrice, "Price must be equal to listing price");

    idMarketItem[tokenId].sold = false;
    idMarketItem[tokenId].price = price;
    idMarketItem[tokenId].seller = payable(msg.sender);
    idMarketItem[tokenId].owner = payable(address(this)); // owner is set to this smart contract when reselling

    _itemsSold.decrement();

    _transfer(msg.sender, address(this), tokenId);
  }

  /**
   * function for making a sale
   * @param tokenId unique ID of an NFT for which the sale is taking place
   * alters the details of the market item and transfers it to the current buyer after receiving comission and quoted amount.
   */
  function createMarketSale(uint256 tokenId) public payable {
    uint256 price = idMarketItem[tokenId].price;

    require(
      msg.value == price, 
      "Please submit the asking price in order to complete the purchase"
    );

    idMarketItem[tokenId].owner = payable(msg.sender);
    idMarketItem[tokenId].sold = true;
    idMarketItem[tokenId].owner = payable(address(0));

    _itemsSold.increment();

    _transfer(address(this), msg.sender, tokenId);   // transfer the NFT from smart contract to current buyer

    payable(owner).transfer(listingPrice);  // take the marketPlace commission
    payable(idMarketItem[tokenId].seller).transfer(msg.value);   // transfer the quoted amount to the seller
  }

  /**
   * function to fetch unsold market items
   * returns an array of MarketItem
   */
  function fetchMarketItem() public view returns(MarketItem[] memory) {
    uint256 itemCount = _tokenIds.current();
    uint256 unsoldItemCount = _tokenIds.current() - _itemsSold.current();
    uint256 currentIndex = 0;

    MarketItem[] memory items = new MarketItem[](unsoldItemCount);
    
    for (uint256 i = 0; i < itemCount; i++) {
      // NFTs which are owned by the smart contract are subjected to unsold ones.
      if(idMarketItem[i + 1].owner == address(this)) {
        uint256 currentId = i + 1;

        MarketItem storage currentItem = idMarketItem[currentId];
        items[currentIndex] = currentItem;
        currentIndex += 1;
      }
    } 

    return items;
  }

  /**
   * function to fetch the NFTs owned by current wallet user
   * returns an array of MarketItem
   */
  function fetchMyNFT() public view returns(MarketItem[] memory) {
    uint256 totalCount = _tokenIds.current();
    uint256 itemCount = 0;
    uint256 currentIndex = 0;

    for (uint256 i = 0; i <  totalCount; i++) {
      if(idMarketItem[i + 1].owner == msg.sender) {
        itemCount += 1;
      }
    }

    MarketItem[] memory items = new MarketItem[](itemCount);

    for (uint256 i = 0; i < totalCount; i++) {
      if(idMarketItem[i + 1].owner == msg.sender) {
        uint256 currentId = i + 1;

        MarketItem storage currentItem = idMarketItem[currentId];
        items[currentIndex] = currentItem;
        currentIndex += 1;
      }
    }

    return items;
  }

  /**
   * function to fetch the NFTs listed for sale by the current wallet user
   * returns an array of MarketItem
   */
  function fetchItemsListed() public view returns(MarketItem[] memory) {
    uint256 totalCount = _tokenIds.current();
    uint256 itemCount = 0;
    uint256 currentIndex = 0;

    for(uint256 i = 0; i < totalCount; i++) {
      if(idMarketItem[i + 1].seller == msg.sender) {
        itemCount += 1;        
      }
    }

    MarketItem[] memory items = new MarketItem[](itemCount);

    for(uint256 i = 0; i < totalCount; i++) {
      if(idMarketItem[i + 1].seller == msg.sender) {
        uint256 currentId = i + 1;

        MarketItem storage currentItem = idMarketItem[currentId];
        items[currentIndex] = currentItem;
        currentIndex += 1;
      }
    }

    return items;
  }
}