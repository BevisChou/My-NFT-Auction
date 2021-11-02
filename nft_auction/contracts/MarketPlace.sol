//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./Item.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MarketPlace {
    
    Item private tokenContract;
    
    constructor (address tokenContractAddr) {
        tokenContract = Item(tokenContractAddr);
    }
    
    uint expiry = 1;    // Duration (in minutes) of expiry

    struct Auction {
        // uint256 tokenId;        // ID of the token
        uint startPrice;        // Start price of the token
        uint startTime;         // Start time of the auction
        uint duration;          // Duration (in minutes) of the auction
        uint currentPrice;      // Current price of the token
        address lastBidderAddr; // Address of the last bidder
        address payable owner;  // Address of the owner
    }

    struct User {
        uint256[] ownedTokenIds;
        uint256[] participatedAuctionIds;
        uint256[] createdAuctionIds;
    }

    uint256[] auctionTokenIds;
    mapping (uint256 => Auction) auctions;  // Use auctionTokenId as key

    mapping (address => User) users;

    mapping (uint256 => address[]) history;

    // Getters

    function getOwnedTokenIds ()
    public view
    returns(uint256[] memory)
    {
        User storage user = users[msg.sender];
        return user.ownedTokenIds;
    }
    
    function getParticipatedAuctionIds ()
    public view
    returns(uint256[] memory)
    {
        User storage user = users[msg.sender];
        return user.participatedAuctionIds;
    }
    
    function getCreatedAuctionIds ()
    public view
    returns(uint256[] memory)
    {
        User storage user = users[msg.sender];
        return user.createdAuctionIds;
    }
    
    function getAuctionIds ()
    public view
    returns(uint256[] memory)
    {
        return auctionTokenIds;
    }

    function getHistory (uint256 tokenId)
    public view
    returns(address[] memory)
    {
        return history[tokenId];
    }

    // Operations

    function sync ()
    public
    {
        updateAuctions();
        User storage user = users[msg.sender];
        updateParticipatedAuctionIds(user.participatedAuctionIds);
    }
    
    function addMintedTokenId (uint256 tokenId)
    public
    {
        require(tokenContract.isTokenValid(tokenId));
        
        User storage user = users[msg.sender];

        addToArray(user.ownedTokenIds, tokenId);

        address[] storage hist = history[tokenId];
        hist.push(msg.sender);

        emit assetAdded(tokenId);
    }

    function getFinalPrice (uint256 tokenId)
    public view
    returns (uint)
    {
        require(!canBid(tokenId) && isAuctionActive(tokenId));
        return auctions[tokenId].currentPrice;
    }

    function claimToken (uint256 tokenId)
    public payable
    {
        require(!canBid(tokenId) && isAuctionActive(tokenId) && auctions[tokenId].lastBidderAddr == msg.sender);

        Auction storage auction = auctions[tokenId];

        User storage seller = users[auction.owner];
        User storage claimant = users[msg.sender];

        auction.owner.transfer(auction.currentPrice);
        
        tokenContract.transferFrom(tokenContract.ownerOf(tokenId), msg.sender, tokenId);
        
        removeFromArray(seller.createdAuctionIds, tokenId);
        
        addToArray(claimant.ownedTokenIds, tokenId);
        removeFromArray(claimant.participatedAuctionIds, tokenId);

        removeFromArray(auctionTokenIds, tokenId);

        address[] storage hist = history[tokenId];
        hist.push(msg.sender);

        emit result(true);
    }

    function bid (uint256 auctionId, uint price)
    public
    {
        require(!isTokenOwner(auctionId, msg.sender) && canBid(auctionId));
        Auction storage auction = auctions[auctionId];

        require(price > auction.currentPrice);
        auction.currentPrice = price;
        auction.lastBidderAddr = msg.sender;
        
        User storage user = users[msg.sender];
        addToArray(user.participatedAuctionIds, auctionId);
        
        emit result(true);
    }

    function createAuction (uint256 tokenId, uint startPrice, uint duration)
    public
    {
        updateAuctions();
        
        require(duration > 0);
        require(isTokenOwner(tokenId, msg.sender));
        
        User storage user = users[msg.sender];
        
        require(!isAuctionActive(tokenId));
        
        Auction storage auction = auctions[tokenId];
        
        auction.startPrice = startPrice;
        auction.startTime = block.timestamp;
        auction.duration = duration;
        auction.currentPrice = startPrice;
        auction.lastBidderAddr = msg.sender;
        auction.owner = payable(msg.sender);
        
        auctionTokenIds.push(tokenId);
        
        removeFromArray(user.ownedTokenIds, tokenId);
        addToArray(user.createdAuctionIds, tokenId);
        
        emit result(true);
    }

    // Bools

    function canBid (uint256 auctionId)
    public view
    returns (bool)
    {
        Auction storage auction = auctions[auctionId];
        return block.timestamp <= auction.startTime + auction.duration * 1 minutes;
    }
    
    function isAuctionActive (uint256 auctionId)
    public view
    returns (bool)
    {
        Auction storage auction = auctions[auctionId];
        return block.timestamp <= auction.startTime + auction.duration * 1 minutes + expiry * 1 minutes;
    }
    
    function isTokenOwner (uint256 tokenId)
    public view
    returns (bool)
    {
        return isTokenOwner(tokenId, msg.sender);
    }
    
    function isTokenOwner (uint256 tokenId, address addr)
    public view
    returns (bool)
    {
        return tokenContract.ownerOf(tokenId) == addr;
    }
    
    // Helpers
    
    function restoreToken (uint256 tokenId) 
    private
    {
        address owner = tokenContract.ownerOf(tokenId);
        User storage user = users[owner];
        
        addToArray(user.ownedTokenIds, tokenId);
        removeFromArray(user.createdAuctionIds, tokenId);
    }
    
    function updateParticipatedAuctionIds (uint256[] storage participatedAuctionIds)
    private
    {
        for (uint i = 0; i < participatedAuctionIds.length; i++) {
            if (!isAuctionActive(participatedAuctionIds[i])) {
                participatedAuctionIds[i] = participatedAuctionIds[participatedAuctionIds.length - 1];
                participatedAuctionIds.pop();
            }
            else{
                i++;
            }
        }
    }
    
    function updateAuctions ()
    private
    {
        // Removed ones are the expired ones
        for (uint i = 0; i < auctionTokenIds.length; ) {
            if (!isAuctionActive(auctionTokenIds[i])) {
                restoreToken(auctionTokenIds[i]);
                auctionTokenIds[i] = auctionTokenIds[auctionTokenIds.length - 1];
                auctionTokenIds.pop();
            }
            else{
                i++;
            }
        }
    }
    
    function isInArray (uint256[] storage array, uint256 target)
    private view
    returns (bool)
    {
        bool ret = false;
        for (uint i = 0; i < array.length; i++){
            if (array[i] == target) {
                ret = true;
                break;
            }
        }
        return ret;
    }
    
    function removeFromArray (uint256[] storage array, uint256 target)
    private
    {
        for (uint i = 0; i < array.length; i++){
            if (array[i] == target) {
                array[i] = array[array.length - 1];
                array.pop();
            }
        }
    }
    
    function addToArray (uint256[] storage array, uint256 target)
    private
    {
        if (!isInArray(array, target)) {
            array.push(target);
        }
    }
    
    // Events
    event assetAdded(uint256 tokenId);
    event result(bool);
}

/* 
References:
https://ethereum.stackexchange.com/questions/37026/how-to-calculate-with-time-and-dates/37027
https://stackoverflow.com/questions/37852682/are-there-null-like-thing-in-solidity
https://stackoverflow.com/questions/55345063/how-to-return-array-of-address-in-solidity
https://ethereum.stackexchange.com/questions/1527/how-to-delete-an-element-at-a-certain-index-in-an-array
https://stackoverflow.com/questions/59448336/check-that-object-is-null-in-solidity-mapping
https://ethereum.stackexchange.com/questions/9733/calling-function-from-deployed-contract
https://ethereum.stackexchange.com/questions/42/how-can-a-contract-run-itself-at-a-later-time
https://ethereum.stackexchange.com/questions/30063/consuming-require-errors-in-web3-js-client
https://ethereum.stackexchange.com/questions/13021/how-can-you-figure-out-if-a-certain-key-exists-in-a-mapping-struct-defined-insi
*/