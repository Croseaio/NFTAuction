// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";



library FeeLibrary {
   using SafeMath for uint256;
   function calculateRoyalties(
       uint256 amount,
       uint256 royaltiesBips
   ) internal pure returns (uint256 amountAfterRoyalties, uint256 royaltiesAmount) {
       royaltiesAmount = amount.mul(royaltiesBips).div(10000);
       amountAfterRoyalties = amount.sub(royaltiesAmount);
   }
}
contract NFTMarket is Ownable{

  using Counters for Counters.Counter;
  Counters.Counter private _itemIds;
  Counters.Counter private _bidIds;
  /*╔═════════════════════════════╗
    ║           Mapping           ║
    ╚═════════════════════════════╝*/
  mapping(address => mapping(uint256 => Auction)) public nftContractAuctions;
  mapping(address => Data) public nftContractStats;
  mapping(uint256 => MarketListing) public itemIdtoListing;
  mapping(uint256 => Bids) public bidIdtoBids;
  mapping(address => uint256) failedTransferCredits;
  mapping(address => mapping(address => uint256)) public erc20toContractVolume;
  mapping(address => uint256) public erc20toVolume;
  /**********************************/
  /*╔══════════════════════════════╗
    ║             END              ║
    ║           Mapping            ║
    ╚══════════════════════════════╝*/
  /**********************************/ 
  //Each Auction is unique to each NFT (contract + id pairing).
struct Auction {
      uint32[] feePercentages;
      uint32 bidIncreasePercentage; 
      uint32 auctionBidPeriod; 
      uint64 auctionEnd; 
      uint128 minPrice; 
      uint128 buyNowPrice; 
      uint128 nftHighestBid;
      uint256 currentItemId;
      uint256 currentBidId;
      address nftHighestBidder;
      address nftSeller;
      address whitelistedBuyer; 
      address nftRecipient; 
      address ERC20Token; 
      address[] feeRecipients;
  }
  struct Data {
      uint32 soldItems; 
      uint128 croVolume;
  }
struct MarketListing{
     uint128 minPrice;
     uint128 buyNowPrice;	
     uint128 nftHighestBid;	
     uint256 itemId;
     uint256 listedTime;
     uint256 tokenId;
     address nftContract;
     address nftHighestBidder;
     address nftSeller;
     address paymentMethod;
     bool auction;
     ListingStatus listingStatus;
  }

   struct Bids{
     uint256 itemId;
     address nftContract;
     uint256 tokenId;
     uint256 bidAmount;
     address bidderAddress;
     uint256 bidTime;
     BidStatus bidStatus;
  }
  enum ListingStatus {
     Active,
     Sold,
     Cancel
  }
  enum BidStatus {
     Active,
     Cancel,
     Accepted
  }
   /*
   * Default values that are used if not specified by the NFT seller.
   */
  uint32 public defaultBidIncreasePercentage;
  uint32 public minimumSettableIncreasePercentage;
  uint32 public maximumMinPricePercentage;
  uint32 public defaultAuctionBidPeriod;
  //State Variables
  uint256 public listingFee;
  uint256 public withdrawFee;
  uint256 public endActionFee;
  uint256 public settleAuctionFee;
  uint256 public saleFeeBips;
  uint256 public soldListing;
  uint256 public activeListing;
  uint256 public totalVolume;

   receive() external payable {
    (bool success, ) = owner().call{
           value: msg.value,
           gas: 50000
       }("");
       require(success);
    }
  /*╔═════════════════════════════╗
    ║           Initializer       ║
    ╚═════════════════════════════╝*/
  constructor(){
      defaultBidIncreasePercentage = 100;
      defaultAuctionBidPeriod = 86400; //1 day
      minimumSettableIncreasePercentage = 100;
      maximumMinPricePercentage = 8000;
      listingFee = 100;
      withdrawFee = 100;
      endActionFee = 100;
      settleAuctionFee = 100;
      saleFeeBips = 250;
      _itemIds.increment();
      _bidIds.increment();
  }
  /*╔═════════════════════════════╗
    ║          Setter             ║
    ╚═════════════════════════════╝*/
  function setlistingFee(uint256 amount) public onlyOwner{
      listingFee = amount;
  }
  function setwithdrawFee(uint256 amount) public onlyOwner{
      withdrawFee = amount;
  }
  function setEndAuctionFee(uint256 amount) public onlyOwner{
      endActionFee = amount;
  }
  function setsettleAuctionFee(uint256 amount) public onlyOwner{
      settleAuctionFee = amount;
  }
  function setSaleFee(uint256 amount) public onlyOwner{
      saleFeeBips = amount;
  }
  function getAllActiveItems() public view returns (MarketListing[] memory){
      uint256 totalItems = _itemIds.current();
      uint256 itemCount = 0;
      for (uint256 i = 1; i < totalItems; i++) {
          if (ListingStatus.Active == itemIdtoListing[i].listingStatus){
              itemCount += 1;
          }
      }
      MarketListing[] memory items = new MarketListing[](itemCount);
     uint256 currentIndex = 0;
     for (uint256 i = 1; i < totalItems; i++) {
         if (ListingStatus.Active == itemIdtoListing[i].listingStatus) {
             MarketListing storage currentItem = itemIdtoListing[i];
             items[currentIndex] = currentItem;
             currentIndex++;
         }
     }
     return items;
  }

  function getAllSoldItems() public view returns (MarketListing[] memory){
      uint256 totalItems = _itemIds.current();
      uint256 itemCount = 0;
      for (uint256 i = 1; i < totalItems; i++) {
          if (ListingStatus.Sold == itemIdtoListing[i].listingStatus){
              itemCount += 1;
          }
      }
      MarketListing[] memory items = new MarketListing[](itemCount);
     uint256 currentIndex = 0;
     for (uint256 i = 1; i < totalItems; i++) {
         if (ListingStatus.Sold == itemIdtoListing[i].listingStatus) {
             MarketListing storage currentItem = itemIdtoListing[i];
             items[currentIndex] = currentItem;
             currentIndex++;
         }
     }
     return items;
  }
  function getAllMylisting()public view returns (MarketListing[] memory){
      uint256 totalItems = _itemIds.current();
      uint256 itemCount = 0;
      for (uint256 i = 1; i < totalItems; i++) {
          if (msg.sender == itemIdtoListing[i].nftSeller){
              itemCount += 1;
          }
      }
       MarketListing[] memory items = new MarketListing[](itemCount);
      uint256 currentIndex = 0;
      for (uint256 i = 1; i < totalItems; i++) {
         if (msg.sender == itemIdtoListing[i].nftSeller) {
             MarketListing storage currentItem = itemIdtoListing[i];
             items[currentIndex] = currentItem;
             currentIndex++;
         }
     }
     return items;
    }
    
  function getMyBiddedNFT()public view returns (MarketListing[] memory){
      uint256 totalItems = _itemIds.current();
      uint256 itemCount = 0;
      for (uint256 i = 1; i < totalItems; i++) {
          if (msg.sender == itemIdtoListing[i].nftHighestBidder){
              itemCount += 1;
          }
      }
       MarketListing[] memory items = new MarketListing[](itemCount);
      uint256 currentIndex = 0;
      for (uint256 i = 1; i < totalItems; i++) {
         if (msg.sender == itemIdtoListing[i].nftHighestBidder) {
             MarketListing storage currentItem = itemIdtoListing[i];
             items[currentIndex] = currentItem;
             currentIndex++;
         }
     }
     return items;
    }

  function fetchBids(uint256 itemId) public view returns (Bids memory){
      return bidIdtoBids[itemId];
   }
  function getListing(uint256 itemId) public view returns (MarketListing memory){
     return itemIdtoListing[itemId];
   }
  function getContractVolume(address _erc20Token, address _nftContract) public view returns (uint256){
      return erc20toContractVolume[_erc20Token][_nftContract];
  }
  function getErc20Volume(address _erc20Token) public view returns(uint256){
      return erc20toVolume[_erc20Token];
  }
  function getAuctionInfo(address _nftContract, uint256 _tokenId) public view returns (Auction memory){
   return  nftContractAuctions[_nftContract][_tokenId];
  }
  function getContractStats(address _nftcontract) public view returns (Data memory){
      return nftContractStats[_nftcontract];
  }


  modifier auctionOngoing(address _nftContractAddress, uint256 _tokenId) {
      require(
          _isAuctionOngoing(_nftContractAddress, _tokenId),
          "Q"
      );
      _;
  }
  modifier priceGreaterThanZero(uint256 _price) {
      require(_price > 0, "W");
      _;
  }
  
  modifier minPriceDoesNotExceedLimit(
      uint128 _buyNowPrice,
      uint128 _minPrice
  ) {
      require(
          _buyNowPrice == 0 ||
              _getPortionOfBid(_buyNowPrice, maximumMinPricePercentage) >=
              _minPrice,
          "E"
      );
      _;
  }
  modifier notNftSeller(address _nftContractAddress, uint256 _tokenId) {
      require(
          msg.sender !=
              nftContractAuctions[_nftContractAddress][_tokenId].nftSeller,
          "R"
      );
      _;
  }
  modifier onlyNftSeller(address _nftContractAddress, uint256 _tokenId) {
      require(
          msg.sender ==
              nftContractAuctions[_nftContractAddress][_tokenId].nftSeller,
          "T"
      );
      _;
  }
  /*
   * The bid amount was either equal the buyNowPrice or it must be higher than the previous
   * bid by the specified bid increase percentage.
   */
  modifier bidAmountMeetsBidRequirements(
      address _nftContractAddress,
      uint256 _tokenId,
      uint128 _tokenAmount
  ) {
      require(
          _doesBidMeetBidRequirements(
              _nftContractAddress,
              _tokenId,
              _tokenAmount
          ),
          "Y"
      );
      _;
  }
  // check if the highest bidder can purchase this NFT.
  modifier onlyApplicableBuyer(
      address _nftContractAddress,
      uint256 _tokenId
  ) {
      require(
          !_isWhitelistedSale(_nftContractAddress, _tokenId) ||
              nftContractAuctions[_nftContractAddress][_tokenId]
                  .whitelistedBuyer ==
              msg.sender,
          "U"
      );
      _;
  }
  modifier minimumBidNotMade(address _nftContractAddress, uint256 _tokenId) {
      require(
          !_isMinimumBidMade(_nftContractAddress, _tokenId),
          "I"
      );
      _;
  }
  /*
   * Payment is accepted if the payment is made in the ERC20 token or ETH specified by the seller.
   * Early bids on NFTs not yet up for auction must be made in ETH.
   */
  modifier paymentAccepted(
      address _nftContractAddress,
      uint256 _tokenId,
      address _erc20Token,
      uint128 _tokenAmount
  ) {
      require(
          _isPaymentAccepted(
              _nftContractAddress,
              _tokenId,
              _erc20Token,
              _tokenAmount
          ),
          "O"
      );
      _;
  }
  modifier isAuctionOver(address _nftContractAddress, uint256 _tokenId) {
      require(
          !_isAuctionOngoing(_nftContractAddress, _tokenId),
          "P"
      );
      _;
  }
  modifier notZeroAddress(address _address) {
      require(_address != address(0), "A");
      _;
  }
  modifier increasePercentageAboveMinimum(uint32 _bidIncreasePercentage) {
      require(
          _bidIncreasePercentage >= minimumSettableIncreasePercentage,
          "S"
      );
      _;
  }
  modifier isFeePercentagesLessThanMaximum(uint32[] memory _feePercentages) {
      uint32 totalPercent;
      for (uint256 i = 0; i < _feePercentages.length; i++) {
          totalPercent = totalPercent + _feePercentages[i];
      }
      require(totalPercent <= 10000, "D");
      _;
  }
  modifier correctFeeRecipientsAndPercentages(
      uint256 _recipientsLength,
      uint256 _percentagesLength
  ) {
      require(
          _recipientsLength == _percentagesLength,
          "F"
      );
      _;
  }
  modifier isNotASale(address _nftContractAddress, uint256 _tokenId) {
      require(
          !_isASale(_nftContractAddress, _tokenId),
          "G"
      );
      _;
  }
  /**********************************/
  /*╔═════════════════════════════╗
    ║             END             ║
    ║          MODIFIERS          ║
    ╚═════════════════════════════╝*/
  /*╔══════════════════════════════╗
    ║    AUCTION CHECK FUNCTIONS   ║
    ╚══════════════════════════════╝*/
  function _isAuctionOngoing(address _nftContractAddress, uint256 _tokenId)
      internal
      view
      returns (bool)
  {
      uint64 auctionEndTimestamp = nftContractAuctions[_nftContractAddress][
          _tokenId
      ].auctionEnd;
      //if the auctionEnd is set to 0, the auction is technically on-going, however
      //the minimum bid price (minPrice) has not yet been met.
      return (auctionEndTimestamp == 0 ||
          block.timestamp < auctionEndTimestamp);
  }
  /*
   * Check if a bid has been made. This is applicable in the early bid scenario
   * to ensure that if an auction is created after an early bid, the auction
   * begins appropriately or is settled if the buy now price is met.
   */
  function _isABidMade(address _nftContractAddress, uint256 _tokenId)
      internal
      view
      returns (bool)
  {
      return (nftContractAuctions[_nftContractAddress][_tokenId]
          .nftHighestBid > 0);
  }
  /*
   *if the minPrice is set by the seller, check that the highest bid meets or exceeds that price.
   */
  function _isMinimumBidMade(address _nftContractAddress, uint256 _tokenId)
      internal
      view
      returns (bool)
  {
      uint128 minPrice = nftContractAuctions[_nftContractAddress][_tokenId]
          .minPrice;
      return
          minPrice > 0 &&
          (nftContractAuctions[_nftContractAddress][_tokenId].nftHighestBid >=
              minPrice);
  }
  /*
   * If the buy now price is set by the seller, check that the highest bid meets that price.
   */
  function _isBuyNowPriceMet(address _nftContractAddress, uint256 _tokenId)
      internal
      view
      returns (bool)
  {
      uint128 buyNowPrice = nftContractAuctions[_nftContractAddress][_tokenId]
          .buyNowPrice;
      return
          buyNowPrice > 0 &&
          nftContractAuctions[_nftContractAddress][_tokenId].nftHighestBid >=
          buyNowPrice;
  }
  /*
   * Check that a bid is applicable for the purchase of the NFT.
   * In the case of a sale: the bid needs to meet the buyNowPrice.
   * In the case of an auction: the bid needs to be a % higher than the previous bid.
   */
  function _doesBidMeetBidRequirements(
      address _nftContractAddress,
      uint256 _tokenId,
      uint128 _tokenAmount
  ) internal view returns (bool) {
      uint128 buyNowPrice = nftContractAuctions[_nftContractAddress][_tokenId]
          .buyNowPrice;
      //if buyNowPrice is met, ignore increase percentage
      if (
          buyNowPrice > 0 &&
          (msg.value >= buyNowPrice || _tokenAmount >= buyNowPrice)
      ) {
          return true;
      }
      //if the NFT is up for auction, the bid needs to be a % higher than the previous bid
      uint256 bidIncreaseAmount = (nftContractAuctions[_nftContractAddress][
          _tokenId
      ].nftHighestBid *
          (10000 +
              _getBidIncreasePercentage(_nftContractAddress, _tokenId))) /
          10000;
      return (msg.value >= bidIncreaseAmount ||
          _tokenAmount >= bidIncreaseAmount);
  }
  /*
   * An NFT is up for sale if the buyNowPrice is set, but the minPrice is not set.
   * Therefore the only way to conclude the NFT sale is to meet the buyNowPrice.
   */
  function _isASale(address _nftContractAddress, uint256 _tokenId)
      internal
      view
      returns (bool)
  {
      return (nftContractAuctions[_nftContractAddress][_tokenId].buyNowPrice >
          0 &&
          nftContractAuctions[_nftContractAddress][_tokenId].minPrice == 0);
  }
  function _isWhitelistedSale(address _nftContractAddress, uint256 _tokenId)
      internal
      view
      returns (bool)
  {
      return (nftContractAuctions[_nftContractAddress][_tokenId]
          .whitelistedBuyer != address(0));
  }
  /*
   * The highest bidder is allowed to purchase the NFT if
   * no whitelisted buyer is set by the NFT seller.
   * Otherwise, the highest bidder must equal the whitelisted buyer.
   */
  function _isHighestBidderAllowedToPurchaseNFT(
      address _nftContractAddress,
      uint256 _tokenId
  ) internal view returns (bool) {
      return
          (!_isWhitelistedSale(_nftContractAddress, _tokenId)) ||
          _isHighestBidderWhitelisted(_nftContractAddress, _tokenId);
  }
  function _isHighestBidderWhitelisted(
      address _nftContractAddress,
      uint256 _tokenId
  ) internal view returns (bool) {
      return (nftContractAuctions[_nftContractAddress][_tokenId]
          .nftHighestBidder ==
          nftContractAuctions[_nftContractAddress][_tokenId]
              .whitelistedBuyer);
  }
  /**
   * Payment is accepted in the following scenarios:
   * (1) Auction already created - can accept ETH or Specified Token
   *  --------> Cannot bid with ETH & an ERC20 Token together in any circumstance<------
   * (2) Auction not created - only ETH accepted (cannot early bid with an ERC20 Token
   * (3) Cannot make a zero bid (no ETH or Token amount)
   */
  function _isPaymentAccepted(
      address _nftContractAddress,
      uint256 _tokenId,
      address _bidERC20Token,
      uint128 _tokenAmount
  ) internal view returns (bool) {
      address auctionERC20Token = nftContractAuctions[_nftContractAddress][
          _tokenId
      ].ERC20Token;
      if (_isERC20Auction(auctionERC20Token)) {
          return
              msg.value == 0 &&
              auctionERC20Token == _bidERC20Token &&
              _tokenAmount > 0;
      } else {
          return
              msg.value != 0 &&
              _bidERC20Token == address(0) &&
              _tokenAmount == 0;
      }
  }
  function _isERC20Auction(address _auctionERC20Token)
      internal
      pure
      returns (bool)
  {
      return _auctionERC20Token != address(0);
  }
  /*
   * Returns the percentage of the total bid (used to calculate fee payments)
   */
  function _getPortionOfBid(uint256 _totalBid, uint256 _percentage)
      internal
      pure
      returns (uint256)
  {
      return (_totalBid * (_percentage)) / 10000;
  }
  /**********************************/
  /*╔══════════════════════════════╗
    ║             END              ║
    ║    AUCTION CHECK FUNCTIONS   ║
    ╚══════════════════════════════╝*/
  /**********************************/
  /*╔══════════════════════════════╗
    ║    DEFAULT GETTER FUNCTIONS  ║
    ╚══════════════════════════════╝*/
  /*****************************************************************
   * These functions check if the applicable auction parameter has *
   * been set by the NFT seller. If not, return the default value. *
   *****************************************************************/
  function _getBidIncreasePercentage(
      address _nftContractAddress,
      uint256 _tokenId
  ) internal view returns (uint32) {
      uint32 bidIncreasePercentage = nftContractAuctions[_nftContractAddress][
          _tokenId
      ].bidIncreasePercentage;
      if (bidIncreasePercentage == 0) {
          return defaultBidIncreasePercentage;
      } else {
          return bidIncreasePercentage;
      }
  }
  function _getAuctionBidPeriod(address _nftContractAddress, uint256 _tokenId)
      internal
      view
      returns (uint32)
  {
      uint32 auctionBidPeriod = nftContractAuctions[_nftContractAddress][
          _tokenId
      ].auctionBidPeriod;
      if (auctionBidPeriod == 0) {
          return defaultAuctionBidPeriod;
      } else {
          return auctionBidPeriod;
      }
  }
  /*
   * The default value for the NFT recipient is the highest bidder
   */
  function _getNftRecipient(address _nftContractAddress, uint256 _tokenId)
      internal
      view
      returns (address)
  {
      address nftRecipient = nftContractAuctions[_nftContractAddress][
          _tokenId
      ].nftRecipient;
      if (nftRecipient == address(0)) {
          return
              nftContractAuctions[_nftContractAddress][_tokenId]
                  .nftHighestBidder;
      } else {
          return nftRecipient;
      }
  }
  /**********************************/
  /*╔══════════════════════════════╗
    ║             END              ║
    ║    DEFAULT GETTER FUNCTIONS  ║
    ╚══════════════════════════════╝*/
  /**********************************/
  /*╔══════════════════════════════╗
    ║  TRANSFER NFTS TO CONTRACT   ║
    ╚══════════════════════════════╝*/
  function _transferNftToAuctionContract(
      address _nftContractAddress,
      uint256 _tokenId
  ) internal {
    
      if (IERC721(_nftContractAddress).ownerOf(_tokenId) == msg.sender) {
          IERC721(_nftContractAddress).transferFrom(
              msg.sender,
              address(this),
              _tokenId
          );
          require(
              IERC721(_nftContractAddress).ownerOf(_tokenId) == address(this),
              "H"
          );
      } else {
          require(
              IERC721(_nftContractAddress).ownerOf(_tokenId) == address(this),
              "J"
          );
      }
  }
  /**********************************/
  /*╔══════════════════════════════╗
    ║             END              ║
    ║  TRANSFER NFTS TO CONTRACT   ║
    ╚══════════════════════════════╝*/
  /**********************************/
  /*╔══════════════════════════════╗
    ║       AUCTION CREATION       ║
    ╚══════════════════════════════╝*/
  /**
   * Setup parameters applicable to all auctions and whitelised sales:
   * -> ERC20 Token for payment (if specified by the seller) : _erc20Token
   * -> minimum price : _minPrice
   * -> buy now price : _buyNowPrice
   * -> the nft seller: msg.sender
   * -> The fee recipients & their respective percentages for a sucessful auction/sale
   */
  function _setupAuction(
      address _nftContractAddress,
      uint256 _tokenId,
      address _erc20Token,
      uint128 _minPrice,
      uint128 _buyNowPrice,
      address[] memory _feeRecipients,
      uint32[] memory _feePercentages
  )
      internal
      minPriceDoesNotExceedLimit(_buyNowPrice, _minPrice)
      correctFeeRecipientsAndPercentages(
          _feeRecipients.length,
          _feePercentages.length
      )
      isFeePercentagesLessThanMaximum(_feePercentages)
  {
      if (_erc20Token != address(0)) {
          nftContractAuctions[_nftContractAddress][_tokenId]
              .ERC20Token = _erc20Token;
      }
      nftContractAuctions[_nftContractAddress][_tokenId]
          .feeRecipients = _feeRecipients;
      nftContractAuctions[_nftContractAddress][_tokenId]
          .feePercentages = _feePercentages;
      nftContractAuctions[_nftContractAddress][_tokenId]
          .buyNowPrice = _buyNowPrice;
      nftContractAuctions[_nftContractAddress][_tokenId].minPrice = _minPrice;
      nftContractAuctions[_nftContractAddress][_tokenId].nftSeller = msg
          .sender;
  }
  function _createNewNftAuction(
      address _nftContractAddress,
      uint256 _tokenId,
      address _erc20Token,
      uint128 _minPrice,
      uint128 _buyNowPrice,
      address[] memory _feeRecipients,
      uint32[] memory _feePercentages
  ) internal {
      // Sending the NFT to this contract
      _setupAuction(
          _nftContractAddress,
          _tokenId,
          _erc20Token,
          _minPrice,
          _buyNowPrice,
          _feeRecipients,
          _feePercentages
      );
      _updateOngoingAuction(_nftContractAddress, _tokenId);
  }
  /**
   * Create an auction that uses the default bid increase percentage
   * & the default auction bid period.
   */
  function createDefaultNftAuction(
      address _nftContractAddress,
      uint256 _tokenId,
      address _erc20Token,
      uint128 _minPrice,
      uint128 _buyNowPrice,
      address[] memory _feeRecipients,
      uint32[] memory _feePercentages
  )
      external payable
      priceGreaterThanZero(_minPrice)
  {
      require (IERC721(_nftContractAddress).ownerOf(_tokenId) == msg.sender, "2");

      if(listingFee > 0){
       require(
         msg.value == listingFee,
         "K"
       );
       (bool success, ) = owner().call{
           value: msg.value,
           gas: 50000
       }("");
       require(success);
     }
    
      _transferNftToAuctionContract(
          _nftContractAddress,
          _tokenId
                  );
      activeListing += 1;   
      _createNewNftAuction(
          _nftContractAddress,
          _tokenId,
          _erc20Token,
          _minPrice,
          _buyNowPrice,
          _feeRecipients,
          _feePercentages
      );
      uint256 currentId = _itemIds.current();
      nftContractAuctions[_nftContractAddress][_tokenId].currentItemId = currentId;
      itemIdtoListing[currentId] = MarketListing(
          _minPrice, 
          _buyNowPrice,
          0,
          currentId,
          block.timestamp,
          _tokenId,
          _nftContractAddress,
          address(0),
          msg.sender,
          _erc20Token,
          true,
          ListingStatus.Active
        
      );
      _itemIds.increment();
  }
  function createNewNftAuction(
      address _nftContractAddress,
      uint256 _tokenId,
      address _erc20Token,
      uint128 _minPrice,
      uint128 _buyNowPrice,
      uint32 _auctionBidPeriod, //this is the time that the auction lasts until another bid occurs
      uint32 _bidIncreasePercentage,
      address[] memory _feeRecipients,
      uint32[] memory _feePercentages
  )
      external payable
      priceGreaterThanZero(_minPrice)
      increasePercentageAboveMinimum(_bidIncreasePercentage)
  {
      require (IERC721(_nftContractAddress).ownerOf(_tokenId) == msg.sender, "2");
      if(listingFee > 0){
       require(
         msg.value == listingFee,
         "K"
       );
       (bool success, ) = owner().call{
           value: msg.value,
           gas: 50000
       }("");
       require(success);
     }
      _transferNftToAuctionContract(
          _nftContractAddress,
          _tokenId
                  );
      activeListing += 1;  
      nftContractAuctions[_nftContractAddress][_tokenId]
          .auctionBidPeriod = _auctionBidPeriod;
      nftContractAuctions[_nftContractAddress][_tokenId]
          .bidIncreasePercentage = _bidIncreasePercentage;
      _createNewNftAuction(
          _nftContractAddress,
          _tokenId,
          _erc20Token,
          _minPrice,
          _buyNowPrice,
          _feeRecipients,
          _feePercentages
      );
      uint256 currentId = _itemIds.current();
      nftContractAuctions[_nftContractAddress][_tokenId].currentItemId = currentId;
      itemIdtoListing[currentId] = MarketListing(
          _minPrice,
          _buyNowPrice,
          0,
          currentId,
          block.timestamp,
          _tokenId,
          _nftContractAddress,
          address(0),
          msg.sender,
          _erc20Token,
          true,
          ListingStatus.Active
        
      );
      _itemIds.increment();
  }
  /**********************************/
  /*╔══════════════════════════════╗
    ║             END              ║
    ║       AUCTION CREATION       ║
    ╚══════════════════════════════╝*/
  /**********************************/
  /*╔══════════════════════════════╗
    ║            SALES             ║
    ╚══════════════════════════════╝*/
  /********************************************************************
   * Allows for a standard sale mechanism where the NFT seller can    *
   * can select an address to be whitelisted. This address is then    *
   * allowed to make a bid on the NFT. No other address can bid on    *
   * the NFT.                                                         *
   ********************************************************************/
  function _setupSale(
      address _nftContractAddress,
      uint256 _tokenId,
      address _erc20Token,
      uint128 _buyNowPrice,
      address _whitelistedBuyer,
      address[] memory _feeRecipients,
      uint32[] memory _feePercentages
  )
      internal
      correctFeeRecipientsAndPercentages(
          _feeRecipients.length,
          _feePercentages.length
      )
      isFeePercentagesLessThanMaximum(_feePercentages)
  {
      if (_erc20Token != address(0)) {
          nftContractAuctions[_nftContractAddress][_tokenId]
              .ERC20Token = _erc20Token;
      }
      nftContractAuctions[_nftContractAddress][_tokenId]
          .feeRecipients = _feeRecipients;
      nftContractAuctions[_nftContractAddress][_tokenId]
          .feePercentages = _feePercentages;
      nftContractAuctions[_nftContractAddress][_tokenId]
          .buyNowPrice = _buyNowPrice;
      nftContractAuctions[_nftContractAddress][_tokenId]
          .whitelistedBuyer = _whitelistedBuyer;
      nftContractAuctions[_nftContractAddress][_tokenId].nftSeller = msg
          .sender;
  }
  function createSale(
      address _nftContractAddress,
      uint256 _tokenId,
      address _erc20Token,
      uint128 _buyNowPrice,
      address _whitelistedBuyer,
      address[] memory _feeRecipients,
      uint32[] memory _feePercentages
  )
      external payable
      priceGreaterThanZero(_buyNowPrice)
  {
      require (IERC721(_nftContractAddress).ownerOf(_tokenId) == msg.sender, "2");
      if(listingFee > 0){
       require(
         msg.value == listingFee,
         "K"
       );
       (bool success, ) = owner().call{
           value: msg.value,
           gas: 50000
       }("");
       require(success);
     
     }
      _transferNftToAuctionContract(
          _nftContractAddress,
          _tokenId
                  );
      activeListing += 1; 
      _setupSale(
          _nftContractAddress,
          _tokenId,
          _erc20Token,
          _buyNowPrice,
          _whitelistedBuyer,
          _feeRecipients,
          _feePercentages
      );
      uint256 currentId = _itemIds.current();
      nftContractAuctions[_nftContractAddress][_tokenId].currentItemId = currentId;
      itemIdtoListing[currentId] = MarketListing(
          0,
          _buyNowPrice,
          0,
          currentId,
          block.timestamp,
          _tokenId,
          _nftContractAddress,
          address(0),
          msg.sender,
          _erc20Token,
          true,
          ListingStatus.Active
      );
      _itemIds.increment();
      //check if buyNowPrice is meet and conclude sale, otherwise reverse the early bid
      if (_isABidMade(_nftContractAddress, _tokenId)) {
          if (
              //we only revert the underbid if the seller specifies a different
              //whitelisted buyer to the highest bidder
              _isHighestBidderAllowedToPurchaseNFT(
                  _nftContractAddress,
                  _tokenId
              )
          ) {
              if (_isBuyNowPriceMet(_nftContractAddress, _tokenId)) {
                  uint256 currentBid =  nftContractAuctions[_nftContractAddress][_tokenId].currentBidId;
                  uint256 currentListing =  nftContractAuctions[_nftContractAddress][_tokenId].currentItemId;
                  itemIdtoListing[currentListing].listingStatus = ListingStatus.Sold;
                  bidIdtoBids[currentBid].bidStatus = BidStatus.Accepted;
                  _transferNftAndPaySeller(_nftContractAddress, _tokenId);
                  activeListing -= 1;
                  soldListing += 1; 
              }
          } else {
              uint256 currentBid =  nftContractAuctions[_nftContractAddress][_tokenId].currentBidId;
              bidIdtoBids[currentBid].bidStatus = BidStatus.Cancel;
              _reverseAndResetPreviousBid(_nftContractAddress, _tokenId);
          }
      }
  }
  /**********************************/
  /*╔══════════════════════════════╗
    ║             END              ║
    ║            SALES             ║
    ╚══════════════════════════════╝*/
  /**********************************/
  /*╔═════════════════════════════╗
    ║        BID FUNCTIONS        ║
    ╚═════════════════════════════╝*/
  /********************************************************************
   * Make bids with ETH or an ERC20 Token specified by the NFT seller.*
   * Additionally, a buyer can pay the asking price to conclude a sale*
   * of an NFT.                                                      *
   ********************************************************************/
  function _makeBid(
      address _nftContractAddress,
      uint256 _tokenId,
      address _erc20Token,
      uint128 _tokenAmount
  )
      internal
      notNftSeller(_nftContractAddress, _tokenId)
      paymentAccepted(
          _nftContractAddress,
          _tokenId,
          _erc20Token,
          _tokenAmount
      )
      bidAmountMeetsBidRequirements(
          _nftContractAddress,
          _tokenId,
          _tokenAmount
      )
  {
      _reversePreviousBidAndUpdateHighestBid(
          _nftContractAddress,
          _tokenId,
          _tokenAmount
      );
      _updateOngoingAuction(_nftContractAddress, _tokenId);
  }
  function makeBid(
      address _nftContractAddress,
      uint256 _tokenId,
      address _erc20Token,
      uint128 _tokenAmount
  )
      external
      payable
      auctionOngoing(_nftContractAddress, _tokenId)
      onlyApplicableBuyer(_nftContractAddress, _tokenId)
  {
        _makeBid(_nftContractAddress, _tokenId, _erc20Token, _tokenAmount);
        uint256 currentId = _bidIds.current();
        nftContractAuctions[_nftContractAddress][_tokenId].currentBidId = currentId;
        bidIdtoBids[currentId] = Bids(
            currentId,
            _nftContractAddress,
            _tokenId,
            _tokenAmount,
            msg.sender,
            block.timestamp,
            BidStatus.Active
            );
        _bidIds.increment();
      
  }
  function makeCustomBid(
      address _nftContractAddress,
      uint256 _tokenId,
      address _erc20Token,
      uint128 _tokenAmount,
      address _nftRecipient
  )
      external
      payable
      auctionOngoing(_nftContractAddress, _tokenId)
      notZeroAddress(_nftRecipient)
      onlyApplicableBuyer(_nftContractAddress, _tokenId)
  {
      nftContractAuctions[_nftContractAddress][_tokenId]
          .nftRecipient = _nftRecipient;
      _makeBid(_nftContractAddress, _tokenId, _erc20Token, _tokenAmount);
      uint256 currentId = _bidIds.current();
      nftContractAuctions[_nftContractAddress][_tokenId].currentBidId = currentId;
      bidIdtoBids[currentId] = Bids(
          currentId,
          _nftContractAddress,
          _tokenId,
          _tokenAmount,
          msg.sender,
          block.timestamp,
          BidStatus.Active
      );
      _bidIds.increment();
  }
   /**********************************/
  /*╔══════════════════════════════╗
    ║             END              ║
    ║        BID FUNCTIONS         ║
    ╚══════════════════════════════╝*/
  /**********************************/
  /*╔══════════════════════════════╗
    ║       UPDATE AUCTION         ║
    ╚══════════════════════════════╝*/
  /***************************************************************
   * Settle an auction or sale if the buyNowPrice is met or set  *
   *  auction period to begin if the minimum price has been met. *
   ***************************************************************/
  function _updateOngoingAuction(
      address _nftContractAddress,
      uint256 _tokenId
  ) internal {
      if (_isBuyNowPriceMet(_nftContractAddress, _tokenId)) {
          uint256 currentBid =  nftContractAuctions[_nftContractAddress][_tokenId].currentBidId;
          uint256 currentListing =  nftContractAuctions[_nftContractAddress][_tokenId].currentItemId;
          itemIdtoListing[currentListing].listingStatus = ListingStatus.Sold;
          bidIdtoBids[currentBid].bidStatus = BidStatus.Accepted;
          _transferNftAndPaySeller(_nftContractAddress, _tokenId);
          activeListing -= 1;
          soldListing += 1; 
          return;
      }
      //min price not set, nft not up for auction yet
      if (_isMinimumBidMade(_nftContractAddress, _tokenId)) {
          _updateAuctionEnd(_nftContractAddress, _tokenId);
      }
  }
  function _updateAuctionEnd(address _nftContractAddress, uint256 _tokenId)
      internal
  {
      //the auction end is always set to now + the bid period
      nftContractAuctions[_nftContractAddress][_tokenId].auctionEnd =
          _getAuctionBidPeriod(_nftContractAddress, _tokenId) +
          uint64(block.timestamp);
  }
  /**********************************/
  /*╔══════════════════════════════╗
    ║             END              ║
    ║       UPDATE AUCTION         ║
    ╚══════════════════════════════╝*/
  /**********************************/
  /*╔══════════════════════════════╗
    ║       RESET FUNCTIONS        ║
    ╚══════════════════════════════╝*/
  /*
   * Reset all auction related parameters for an NFT.
   * This effectively removes an NFT as an item up for auction
   */
  function _resetAuction(address _nftContractAddress, uint256 _tokenId)
      internal
  {
      nftContractAuctions[_nftContractAddress][_tokenId].minPrice = 0;
      nftContractAuctions[_nftContractAddress][_tokenId].buyNowPrice = 0;
      nftContractAuctions[_nftContractAddress][_tokenId].auctionEnd = 0;
      nftContractAuctions[_nftContractAddress][_tokenId].auctionBidPeriod = 0;
      nftContractAuctions[_nftContractAddress][_tokenId].currentItemId = 0;
      nftContractAuctions[_nftContractAddress][_tokenId]
          .bidIncreasePercentage = 0;
      nftContractAuctions[_nftContractAddress][_tokenId].nftSeller = address(
          0
      );
      nftContractAuctions[_nftContractAddress][_tokenId]
          .whitelistedBuyer = address(0);
      nftContractAuctions[_nftContractAddress][_tokenId].ERC20Token = address(0);
  }
  /*
   * Reset all bid related parameters for an NFT.
   * This effectively sets an NFT as having no active bids
   */
  function _resetBids(address _nftContractAddress, uint256 _tokenId)
      internal
  {
      nftContractAuctions[_nftContractAddress][_tokenId]
          .nftHighestBidder = address(0);
      nftContractAuctions[_nftContractAddress][_tokenId].nftHighestBid = 0;
      nftContractAuctions[_nftContractAddress][_tokenId]
          .nftRecipient = address(0);
    
      nftContractAuctions[_nftContractAddress][_tokenId].currentBidId = 0;
  }
  /**********************************/
  /*╔══════════════════════════════╗
    ║             END              ║
    ║       RESET FUNCTIONS        ║
    ╚══════════════════════════════╝*/
  /**********************************/
  /*╔══════════════════════════════╗
    ║         UPDATE BIDS          ║
    ╚══════════════════════════════╝*/
  /******************************************************************
   * Internal functions that update bid parameters and reverse bids *
   * to ensure contract only holds the highest bid.                 *
   ******************************************************************/
  function _updateHighestBid(
      address _nftContractAddress,
      uint256 _tokenId,
      uint128 _tokenAmount
  ) internal {
      address auctionERC20Token = nftContractAuctions[_nftContractAddress][
          _tokenId
      ].ERC20Token;
      uint256 currentItem = nftContractAuctions[_nftContractAddress][_tokenId].currentItemId;
      uint256 currentBid =  nftContractAuctions[_nftContractAddress][_tokenId].currentBidId;
      if (_isERC20Auction(auctionERC20Token)) {
          IERC20(auctionERC20Token).transferFrom(
              msg.sender,
              address(this),
              _tokenAmount
          );
          itemIdtoListing[currentItem].nftHighestBid = _tokenAmount;
          nftContractAuctions[_nftContractAddress][_tokenId]
              .nftHighestBid = _tokenAmount;
        if (msg.sender == bidIdtoBids[currentBid].bidderAddress && bidIdtoBids[currentBid].bidStatus == BidStatus.Active){
            bidIdtoBids[currentBid].bidAmount = _tokenAmount;
        }else{
            bidIdtoBids[currentBid].bidStatus = BidStatus.Cancel;
        }

      } else {
          itemIdtoListing[currentItem].nftHighestBid = uint128(msg.value);
          nftContractAuctions[_nftContractAddress][_tokenId]
              .nftHighestBid = uint128(msg.value);
        if (msg.sender == bidIdtoBids[currentBid].bidderAddress && bidIdtoBids[currentBid].bidStatus == BidStatus.Active){
            bidIdtoBids[currentBid].bidAmount = msg.value;
        }else{
            bidIdtoBids[currentBid].bidStatus = BidStatus.Cancel;
        } 
      }
      
      nftContractAuctions[_nftContractAddress][_tokenId]
          .nftHighestBidder = msg.sender;
      itemIdtoListing[currentItem].nftHighestBidder = msg.sender;
  }
  function _reverseAndResetPreviousBid(
      address _nftContractAddress,
      uint256 _tokenId
  ) internal {
      address nftHighestBidder = nftContractAuctions[_nftContractAddress][
          _tokenId
      ].nftHighestBidder;
      uint128 nftHighestBid = nftContractAuctions[_nftContractAddress][
          _tokenId
      ].nftHighestBid;
      _resetBids(_nftContractAddress, _tokenId);
      _payout(_nftContractAddress, _tokenId, nftHighestBidder, nftHighestBid);
  }
  function _reversePreviousBidAndUpdateHighestBid(
      address _nftContractAddress,
      uint256 _tokenId,
      uint128 _tokenAmount
  ) internal {
      address prevNftHighestBidder = nftContractAuctions[_nftContractAddress][
          _tokenId
      ].nftHighestBidder;
      uint256 prevNftHighestBid = nftContractAuctions[_nftContractAddress][
          _tokenId
      ].nftHighestBid;
      _updateHighestBid(_nftContractAddress, _tokenId, _tokenAmount);
      if (prevNftHighestBidder != address(0)) {
          _payout(
              _nftContractAddress,
              _tokenId,
              prevNftHighestBidder,
              prevNftHighestBid
          );
      }
  }
  /**********************************/
  /*╔══════════════════════════════╗
    ║             END              ║
    ║         UPDATE BIDS          ║
    ╚══════════════════════════════╝*/
  /**********************************/
  /*╔══════════════════════════════╗
    ║  TRANSFER NFT & PAY SELLER   ║
    ╚══════════════════════════════╝*/
  function _transferNftAndPaySeller(
      address _nftContractAddress,
      uint256 _tokenId
  ) internal {
      address _nftSeller = nftContractAuctions[_nftContractAddress][_tokenId]
          .nftSeller;
      address _nftRecipient = _getNftRecipient(_nftContractAddress, _tokenId);
      uint128 _nftHighestBid = nftContractAuctions[_nftContractAddress][
          _tokenId
      ].nftHighestBid;


      nftContractStats[_nftContractAddress].soldItems += 1;
      if (nftContractAuctions[_nftContractAddress][_tokenId].ERC20Token != address(0)){
          erc20toContractVolume[nftContractAuctions[_nftContractAddress][_tokenId].ERC20Token][_nftContractAddress] += _nftHighestBid;
          erc20toVolume[nftContractAuctions[_nftContractAddress][_tokenId].ERC20Token] += _nftHighestBid;
      }
      else{
          nftContractStats[_nftContractAddress].croVolume += _nftHighestBid;
          totalVolume += _nftHighestBid;
      }
      _payFeesAndSeller(
          _nftContractAddress,
          _tokenId,
          _nftSeller,
          _nftHighestBid
      );
      _resetBids(_nftContractAddress, _tokenId);
      _resetAuction(_nftContractAddress, _tokenId);
      IERC721(_nftContractAddress).transferFrom(
          address(this),
          _nftRecipient,
          _tokenId
      );
  }
  function _payFeesAndSeller(
      address _nftContractAddress,
      uint256 _tokenId,
      address _nftSeller,
      uint256 _highestBid
  ) internal {
      (uint256 saleProceed, uint256 platformFee) = FeeLibrary
         .calculateRoyalties(_highestBid, saleFeeBips);
      address auctionERC20Token = nftContractAuctions[_nftContractAddress][
          _tokenId
      ].ERC20Token;
      if (_isERC20Auction(auctionERC20Token)) {
          IERC20(auctionERC20Token).transfer(owner(), platformFee);
      } else {
          // attempt to send the funds to the recipient
          (bool success, ) = owner().call{
              value: platformFee,
              gas: 50000
          }("");
          // if it failed, update their credit balance so they can pull it later
          if (!success) {
              failedTransferCredits[owner()] =
                  failedTransferCredits[owner()] +
                  platformFee;
          }
      }
      uint256 feesPaid;
      for (
          uint256 i = 0;
          i <
          nftContractAuctions[_nftContractAddress][_tokenId]
              .feeRecipients
              .length;
          i++
      ) {
          uint256 fee = _getPortionOfBid(
              saleProceed,
              nftContractAuctions[_nftContractAddress][_tokenId]
                  .feePercentages[i]
          );
          feesPaid = feesPaid + fee;
          _payout(
              _nftContractAddress,
              _tokenId,
              nftContractAuctions[_nftContractAddress][_tokenId]
                  .feeRecipients[i],
              fee
          );
      }
      _payout(
          _nftContractAddress,
          _tokenId,
          _nftSeller,
          (saleProceed - feesPaid)
      );
  }
  function _payout(
      address _nftContractAddress,
      uint256 _tokenId,
      address _recipient,
      uint256 _amount
  ) internal {
      address auctionERC20Token = nftContractAuctions[_nftContractAddress][
          _tokenId
      ].ERC20Token;
      if (_isERC20Auction(auctionERC20Token)) {
          IERC20(auctionERC20Token).transfer(_recipient, _amount);
      } else {
          // attempt to send the funds to the recipient
          (bool success, ) = payable(_recipient).call{
              value: _amount,
              gas: 50000
          }("");
          // if it failed, update their credit balance so they can pull it later
          if (!success) {
              failedTransferCredits[_recipient] =
                  failedTransferCredits[_recipient] +
                  _amount;
          }
      }
  }
  /**********************************/
  /*╔══════════════════════════════╗
    ║             END              ║
    ║  TRANSFER NFT & PAY SELLER   ║
    ╚══════════════════════════════╝*/
  /**********************************/
  /*╔══════════════════════════════╗
    ║      SETTLE & WITHDRAW       ║
    ╚══════════════════════════════╝*/
  function settleAuction(address _nftContractAddress, uint256 _tokenId)
      external payable
      isAuctionOver(_nftContractAddress, _tokenId)
  {
      if(settleAuctionFee > 0){
       require(
         msg.value == settleAuctionFee,
         "K"
       );
       (bool success, ) = owner().call{
           value: msg.value,
           gas: 50000
       }("");
       require(success);
      }
      uint256 currentBid =  nftContractAuctions[_nftContractAddress][_tokenId].currentBidId;
      uint256 currentListing =  nftContractAuctions[_nftContractAddress][_tokenId].currentItemId;
      itemIdtoListing[currentListing].listingStatus = ListingStatus.Sold;
      itemIdtoListing[currentListing].auction = false;
      bidIdtoBids[currentBid].bidStatus = BidStatus.Accepted;
      _transferNftAndPaySeller(_nftContractAddress, _tokenId);
      activeListing -= 1;
      soldListing += 1; 
  }
  function withdrawAuction(address _nftContractAddress, uint256 _tokenId)
      external payable
  {
      //only the NFT owner can prematurely close and auction
      require(
          msg.sender == nftContractAuctions[_nftContractAddress][_tokenId].nftSeller,
          "L"
      );
      if(endActionFee > 0){
       require(
         msg.value == endActionFee,
         "K"
       );
       (bool success, ) = owner().call{
           value: msg.value,
           gas: 50000
       }("");
       require(success);
      }
      uint256 currentListing =  nftContractAuctions[_nftContractAddress][_tokenId].currentItemId;
      itemIdtoListing[currentListing].auction = false;
      itemIdtoListing[currentListing].listingStatus = ListingStatus.Cancel;
      activeListing -= 1;
      _resetAuction(_nftContractAddress, _tokenId);
      IERC721(_nftContractAddress).transferFrom(
          address(this),
          msg.sender,
          _tokenId
      );
  }
  function withdrawBid(address _nftContractAddress, uint256 _tokenId)
      external payable
      minimumBidNotMade(_nftContractAddress, _tokenId)
  {
      if(withdrawFee > 0){
       require(
         msg.value == withdrawFee,
         "K"
       );
       (bool success, ) = owner().call{
           value: msg.value,
           gas: 50000
       }("");
       require(success);
      }
      address nftHighestBidder = nftContractAuctions[_nftContractAddress][
          _tokenId
      ].nftHighestBidder;
      require(msg.sender == nftHighestBidder, "Z");
      uint128 nftHighestBid = nftContractAuctions[_nftContractAddress][
          _tokenId
      ].nftHighestBid;
      uint256 currentBid =  nftContractAuctions[_nftContractAddress][_tokenId].currentBidId;
      bidIdtoBids[currentBid].bidStatus = BidStatus.Cancel;
      _resetBids(_nftContractAddress, _tokenId);
      _payout(_nftContractAddress, _tokenId, nftHighestBidder, nftHighestBid);
  }
  /**********************************/
  /*╔══════════════════════════════╗
    ║             END              ║
    ║      SETTLE & WITHDRAW       ║
    ╚══════════════════════════════╝*/
  /**********************************/
  /*╔══════════════════════════════╗
    ║       UPDATE AUCTION         ║
    ╚══════════════════════════════╝*/
  function updateWhitelistedBuyer(
      address _nftContractAddress,
      uint256 _tokenId,
      address _newWhitelistedBuyer
  ) external onlyNftSeller(_nftContractAddress, _tokenId) {
      require(_isASale(_nftContractAddress, _tokenId), "X");
      nftContractAuctions[_nftContractAddress][_tokenId]
          .whitelistedBuyer = _newWhitelistedBuyer;
      //if an underbid is by a non whitelisted buyer,reverse that bid
      address nftHighestBidder = nftContractAuctions[_nftContractAddress][
          _tokenId
      ].nftHighestBidder;
      uint128 nftHighestBid = nftContractAuctions[_nftContractAddress][
          _tokenId
      ].nftHighestBid;
      if (nftHighestBid > 0 && !(nftHighestBidder == _newWhitelistedBuyer)) {
          //we only revert the underbid if the seller specifies a different
          //whitelisted buyer to the highest bider
          uint256 currentBid =  nftContractAuctions[_nftContractAddress][_tokenId].currentBidId;
          bidIdtoBids[currentBid].bidStatus = BidStatus.Cancel;
          _resetBids(_nftContractAddress, _tokenId);
          _payout(
              _nftContractAddress,
              _tokenId,
              nftHighestBidder,
              nftHighestBid
          );
      }
  }
  function updateMinimumPrice(
      address _nftContractAddress,
      uint256 _tokenId,
      uint128 _newMinPrice
  )
      external
      onlyNftSeller(_nftContractAddress, _tokenId)
      minimumBidNotMade(_nftContractAddress, _tokenId)
      isNotASale(_nftContractAddress, _tokenId)
      priceGreaterThanZero(_newMinPrice)
      minPriceDoesNotExceedLimit(
          nftContractAuctions[_nftContractAddress][_tokenId].buyNowPrice,
          _newMinPrice
      )
  {
      uint256 currentListing =  nftContractAuctions[_nftContractAddress][_tokenId].currentItemId;
      itemIdtoListing[currentListing].minPrice = _newMinPrice;
      nftContractAuctions[_nftContractAddress][_tokenId]
          .minPrice = _newMinPrice;
      if (_isMinimumBidMade(_nftContractAddress, _tokenId)) {
          _updateAuctionEnd(_nftContractAddress, _tokenId);
      }
  }
  function updateBuyNowPrice(
      address _nftContractAddress,
      uint256 _tokenId,
      uint128 _newBuyNowPrice
  )
      external
      onlyNftSeller(_nftContractAddress, _tokenId)
      priceGreaterThanZero(_newBuyNowPrice)
      minPriceDoesNotExceedLimit(
          _newBuyNowPrice,
          nftContractAuctions[_nftContractAddress][_tokenId].minPrice
      )
  {
      uint256 currentListing =  nftContractAuctions[_nftContractAddress][_tokenId].currentItemId;
      itemIdtoListing[currentListing].buyNowPrice = _newBuyNowPrice;
      nftContractAuctions[_nftContractAddress][_tokenId]
          .buyNowPrice = _newBuyNowPrice;
      if (_isBuyNowPriceMet(_nftContractAddress, _tokenId)) {
          uint256 currentBid =  nftContractAuctions[_nftContractAddress][_tokenId].currentBidId;
          itemIdtoListing[currentListing].listingStatus = ListingStatus.Sold;
          bidIdtoBids[currentBid].bidStatus = BidStatus.Accepted;
          _transferNftAndPaySeller(_nftContractAddress, _tokenId);
          activeListing -= 1;
          soldListing += 1;           
      }
  }
  /*
   * The NFT seller can opt to end an auction by taking the current highest bid.
   */
  function takeHighestBid(address _nftContractAddress, uint256 _tokenId)
      external
      onlyNftSeller(_nftContractAddress, _tokenId)
  {
      require(
          _isABidMade(_nftContractAddress, _tokenId),
          "C"
      );
      uint256 currentBid =  nftContractAuctions[_nftContractAddress][_tokenId].currentBidId;
      uint256 currentListing =  nftContractAuctions[_nftContractAddress][_tokenId].currentItemId;
      itemIdtoListing[currentListing].listingStatus = ListingStatus.Sold;
      bidIdtoBids[currentBid].bidStatus = BidStatus.Accepted;
      _transferNftAndPaySeller(_nftContractAddress, _tokenId);
      activeListing -= 1;
      soldListing += 1; 
  }
  /*
   * Query the owner of an NFT deposited for auction
   */
  function ownerOfNFT(address _nftContractAddress, uint256 _tokenId)
      external
      view
      returns (address)
  {
      address nftSeller = nftContractAuctions[_nftContractAddress][_tokenId]
          .nftSeller;
      require(nftSeller != address(0), "V");
      return nftSeller;
  }
  /*
   * If the transfer of a bid has failed, allow the recipient to reclaim their amount later.
   */
  function withdrawAllFailedCredits() external {
      uint256 amount = failedTransferCredits[msg.sender];
      require(amount != 0, "B");
      failedTransferCredits[msg.sender] = 0;
      (bool successfulWithdraw, ) = msg.sender.call{
          value: amount,
          gas: 50000
      }("");
      require(successfulWithdraw, "N");
  }
  /**********************************/
  /*╔══════════════════════════════╗
    ║             END              ║
    ║       UPDATE AUCTION         ║
    ╚══════════════════════════════╝*/
  /**********************************/
}
 
 
 

