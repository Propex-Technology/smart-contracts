// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// TODO: check to make sure the logic for the buy listings is right
// TODO: write unit tests

/*

One potential way we could do it:
1.  Every x seconds, we query for the largest buy and sell counters & 
    the listing removes.
2.  If the buy and sell counters are greater than what they were before, 
    we multicall/batch request for the data, and index based on tokenId.
3.  If there are listing removes, then we simply remove the entry from
    our database.

*/

/// @author Miguel Piedrafita & Jeremy Boetticher
contract LilOpenSea is Ownable {
    /// EVENTS ///

    /// @notice Emitted when a new listing is created
    /// @param listing The newly-created listing
    event NewSellListing(
        uint256 indexed tokenId,
        uint256 indexed listingId,
		address indexed seller,
        SellListing listing
    );

    /// @notice Emitted when a listing is removed (canceled or finished)
    /// @param listing The removed listing
    event SellListingRemoved(
        uint256 indexed tokenId,
        uint256 indexed listingId,
        SellListing listing
    );

    /// @notice Emitted when a listing is purchased
    /// @param buyer The address of the buyer
    /// @param listing The purchased listing
    event SellListingFilled(
        uint256 indexed tokenId,
        uint256 indexed listingId,
        address indexed buyer,
        SellListing listing
    );

    event NewBuyListing(
        uint256 indexed tokenId,
        uint256 indexed listingId,
		address indexed buyer,
        BuyListing listing
    );

    event BuyListingRemoved(
        uint256 indexed tokenId,
        uint256 indexed listingId,
        BuyListing listing
    );

    event BuyListingFilled(
        uint256 indexed tokenId,
        uint256 indexed listingId,
        address indexed seller,
        BuyListing listing
    );

    /// TODO: post buy listings vs post sell listings

    /// @notice Used as a counter for the next sale index.
    /// @dev Initialised at 1 because it makes the first transaction slightly cheaper.
    uint256 internal saleCounter = 1;
    uint256 internal buyCounter = 1;

    /// @notice The contract whose tokens we are selling.
    IERC1155 public immutable propexContract;

    /// @notice The tokens users can ask for in exchange.
    mapping(IERC20 => bool) public approvedTokens;

    /// @param _propexContract The contract whose tokens we're selling.
    constructor(IERC1155 _propexContract) {
        propexContract = _propexContract;
    }

    /// @dev Parameters for listings
    /// @param tokenId The ID of the listed token
    /// @param amount The amount of tokens to sell.
    /// @param askPrice The amount the seller is asking for in exchange for the token (per unit)
    /// @param askToken The token the seller is asking for in payment.
    /// @param creator The address of the seller
    struct SellListing {
        uint256 tokenId;
        uint256 amount;
        uint256 askPrice;
        IERC20 askToken;
        address creator;
        bool allowPartialFills;
    }

    /// @dev Parameters for listings
    /// @param tokenId The ID of the listed token
    /// @param amount The amount of tokens to sell.
    /// @param bidPrice The amount the buyer is offering for in exchange for the token (per unit)
    /// @param bidToken The token the buyer is offering for in payment.
    /// @param creator The address of the buyer.
    struct BuyListing {
        uint256 tokenId;
        uint256 amount;
        uint256 bidPrice;
        IERC20 bidToken;
        address creator;
        bool allowPartialFills;
    }

    /// @notice An indexed list of listings
    mapping(uint256 => SellListing) public getSellListing;
    mapping(uint256 => BuyListing) public getBuyListing;

    /// @notice The fee ratio for sales.
    uint256 public feeRatio;
    mapping(IERC20 => uint256) public feesCollected;

    /// @notice Allows the owner to set the contract fees.
    /// @param newFee The new fee ratio to set.
    function setFee(uint256 newFee) external onlyOwner {
        require(newFee >= 20, "PropexMarket: Fee ratio is too high (<20).");
        feeRatio = newFee;
    }

    /// @notice Allows the owner to withdraw collected fees.
    /// @param token The token to collect fees from.
    function withdraw(address token) external onlyOwner {
        IERC20 erc = IERC20(token);
        require(approvedTokens[erc], "PropexMarket: Token is not approved.");
        uint256 amnt = feesCollected[erc]; 
        feesCollected[erc] = 0;
        erc.transfer(owner(), amnt);
    }

    /// @notice List an ERC721 token for sale
    /// @param tokenId The ID of the token you're listing
    /// @param askPrice How much you want to receive in exchange for the token
    /// @return The ID of the created listing
    /// @dev Remember to call setApprovalForAll(<address of this contract>, true) on the ERC721's contract before calling this function
    function listSellOrder(
        uint256 tokenId,
        uint256 amount,
        uint256 askPrice,
        address askToken,
        bool allowPartialFills
    ) public payable returns (uint256) {
        IERC20 token = IERC20(askToken);
        require(approvedTokens[token], "PropexMarket: Cannot list this token.");

        SellListing memory listing = SellListing({
            tokenId: tokenId,
            amount: amount,
            askPrice: askPrice,
            askToken: token,
            creator: msg.sender,
            allowPartialFills: allowPartialFills
        });

        getSellListing[saleCounter] = listing;

        emit NewSellListing(tokenId, saleCounter, msg.sender, listing);

        propexContract.safeTransferFrom(
            msg.sender,
            address(this),
            tokenId,
            amount,
            ""
        );

        return saleCounter++;
    }

    /// @notice Cancel an existing listing
    /// @param listingId The ID for the listing you want to cancel
    function cancelSellListing(uint256 listingId) public payable {
        SellListing memory listing = getSellListing[listingId];

        require(
            listing.creator == msg.sender,
            "PropexMarket: Only the listinc creator can cancel."
        );

        delete getSellListing[listingId];

        emit SellListingRemoved(listing.tokenId, listingId, listing);

        propexContract.safeTransferFrom(
            address(this),
            listing.creator,
            listing.tokenId,
            listing.amount,
            ""
        );
    }

    /// @notice Purchase one of the listed tokens
    /// @param listingId The ID for the listing you want to purchase
    function fillSellListing(uint256 listingId, uint256 amount) public payable {
        SellListing memory listing = getSellListing[listingId];

        require(
            listing.creator != address(0),
            "PropexMarket: SellListing does not exist."
        );

        // Attempt to purchase a portion of the listing.
        if (listing.amount > amount) {
            require(
                listing.allowPartialFills,
                "PropexMarket: Partial fills not allowed."
            );

            // Send payment tokens.
            uint256 entireAmount = amount * listing.askPrice;
            uint256 fee = entireAmount / feeRatio;
            listing.askToken.transferFrom(
                msg.sender,
                listing.creator,
                entireAmount - fee
            );
            listing.askToken.transferFrom(msg.sender, address(this), fee);
            feesCollected[listing.askToken] += fee;

            // Remove amount purchased from listing
            getSellListing[listingId].amount -= amount;

            // Purchase (partial) listing
            emit SellListingFilled(listing.tokenId, listingId, msg.sender, listing);
            propexContract.safeTransferFrom(
                address(this),
                msg.sender,
                listing.tokenId,
                amount,
                ""
            );
        }
        // Purchase the entire listing.
        else {
            // Send payment tokens.
            uint256 entireAmount = listing.amount * listing.askPrice;
            uint256 fee = entireAmount / feeRatio;
            listing.askToken.transferFrom(
                msg.sender,
                listing.creator,
                entireAmount - fee
            );
            listing.askToken.transferFrom(msg.sender, address(this), fee);

            delete getSellListing[listingId];

            // Send IERC1155 token to user.
            emit SellListingFilled(listing.tokenId, listingId, msg.sender, listing);
			emit SellListingRemoved(listing.tokenId, listingId, listing);
            propexContract.safeTransferFrom(
                address(this),
                msg.sender,
                listing.tokenId,
                listing.amount,
                ""
            );
        }
    }

    /// @notice List an ERC721 token buy offer
    /// @param tokenId The ID of the token you're listing
    /// @param amount How many tokens they'd like to buy.
    /// @param bidPrice How much you want to receive in exchange for the token
    /// @return bidToken ID of the created listing
    /// @dev Remember to call setApprovalForAll(<address of this contract>, true) on the ERC721's contract before calling this function
    function listBuyOrder(
        uint256 tokenId,
        uint256 amount,
        uint256 bidPrice,
        address bidToken,
        bool allowPartialFills
    ) public payable returns (uint256) {
        IERC20 token = IERC20(bidToken);
        require(approvedTokens[token], "PropexMarket: Cannot list this token.");

        BuyListing memory listing = BuyListing({
            tokenId: tokenId,
            amount: amount,
            bidPrice: bidPrice,
            bidToken: token,
            creator: msg.sender,
            allowPartialFills: allowPartialFills
        });

        getBuyListing[buyCounter] = listing;

        token.transferFrom(msg.sender, address(this), amount * bidPrice);

        emit NewBuyListing(tokenId, buyCounter, msg.sender, listing);

        return saleCounter++;
    }

    /// @notice Cancel an existing listing
    /// @param listingId The ID for the listing you want to cancel
    function cancelBuyListing(uint256 listingId) public payable {
        BuyListing memory listing = getBuyListing[listingId];

        require(
            listing.creator == msg.sender,
            "PropexMarket: Only the listing creator can cancel."
        );

        delete getBuyListing[listingId];

        emit BuyListingRemoved(listing.tokenId, listingId, listing);

        listing.bidToken.transfer(listing.creator, listing.amount);
    }

    /// @notice Purchase one of the listed tokens
    /// @param listingId The ID for the listing you want to purchase
    function fillBuyListing(uint256 listingId, uint256 amount) public payable {
        BuyListing memory listing = getBuyListing[listingId];

        require(
            listing.creator != address(0),
            "PropexMarket: BuyListing does not exist."
        );

        // Attempt to purchase a portion of the listing.
        if (listing.amount > amount) {
            require(
                listing.allowPartialFills,
                "PropexMarket: Partial fills not allowed."
            );

            // Partial listing
            emit BuyListingFilled(listing.tokenId, listingId, msg.sender, listing);
            propexContract.safeTransferFrom(
                msg.sender,
                listing.creator,
                listing.tokenId,
                amount,
                ""
            );

            // Send payment tokens.
            uint256 entireAmount = amount * listing.bidPrice;
            uint256 fee = entireAmount / feeRatio;
            listing.bidToken.transferFrom(
                address(this),
                msg.sender,
                entireAmount - fee
            );
            listing.bidToken.transferFrom(msg.sender, address(this), fee);

            // Remove amount purchased from listing
            getSellListing[listingId].amount -= amount;
        }
        // Purchase the entire listing.
        else {
            // Send payment tokens.
            uint256 entireAmount = listing.amount * listing.bidPrice;
            uint256 fee = entireAmount / feeRatio;
            listing.bidToken.transferFrom(
                msg.sender,
                listing.creator,
                entireAmount - fee
            );
            feesCollected[listing.bidToken] += fee;

            delete getSellListing[listingId];

            // Send IERC1155 token to user.
            emit BuyListingFilled(listing.tokenId, listingId, msg.sender, listing);
			emit BuyListingRemoved(listing.tokenId, listingId, listing);
            propexContract.safeTransferFrom(
                address(this),
                msg.sender,
                listing.tokenId,
                listing.amount,
                ""
            );
        }
    }
}
