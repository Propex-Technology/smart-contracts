// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import "erc721a/contracts/extensions/ERC721AQueryable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PropexDealNFT is ERC721AQueryable, Ownable {

    uint128 public assetId;
    uint128 public maxAmount;

    error MintOverMax();

    constructor(string memory _name, string memory _symbol, uint128 _assetId, uint128 _maxAmount) 
    ERC721A(_name, _symbol) {
        assetId = _assetId;
        maxAmount = _maxAmount;
    }

    function mintForUser(address user, uint256 quantity) external onlyOwner {
        if(quantity + _totalMinted() > maxAmount) revert MintOverMax();
        _safeMint(user, quantity);
    }

    // TODO: allow purchase as long person is reserved (oracle)
    
}