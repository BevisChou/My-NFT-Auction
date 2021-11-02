//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Item is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    string private baseURI = "ipfs://";

    constructor(string memory tokenName, string memory symbol) ERC721(tokenName, symbol) {}

    function mintToken(address owner, string memory metadataURI)
    public
    {
        _tokenIds.increment();

        uint256 id = _tokenIds.current();
        _safeMint(owner, id);
        
        _setTokenURI(id, string(abi.encodePacked(baseURI, metadataURI)));

        emit tokenMinted(id);
    }
    
    function isTokenValid(uint256 tokenId)
    public view
    returns (bool)
    {
        return _exists(tokenId);
    }
    
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    )
    public override
    {
        _transfer(from, to, tokenId);
    }

    event tokenMinted(uint256 tokenId);
}

/* 
Reference:
https://ethereum.stackexchange.com/questions/93917/function-settokenuri-in-erc721-is-gone-in-openzeppelin-0-8-0-contracts
https://stackoverflow.com/questions/66789290/declarationerror-undeclared-identifier-although-its-present-in-erc721-sol
https://ethereum.stackexchange.com/questions/47660/how-to-get-metadata-from-erc721/48663
https://ethereum.stackexchange.com/questions/19283/in-the-truffle-console-how-to-set-and-get-current-account/19284
*/
