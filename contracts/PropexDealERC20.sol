// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC20Enumerable.sol";
import "./ISnapshotEnumerable.sol";

// Uses ERC20Enumerable
// Recommended not to use this contract for very large deals
contract PropexDealERC20 is ERC20Enumerable, Ownable, ISnapshotEnumerable {

    uint128 public assetId;
    uint120 public maxAmount;
    bool public paused;
    string public arweaveTx;

    constructor(
        string memory _name, 
        string memory _symbol, 
        uint128 _assetId, 
        uint120 _maxAmount, 
        string memory _arweaveTx) ERC20Enumerable(_name, _symbol) {
        assetId = _assetId;
        maxAmount = _maxAmount;
        arweaveTx = _arweaveTx;
    }

    error MintOverMax();
    error UnbalancedArrays();
    error IsPaused();

    function mintForUser(address user, uint256 quantity) external onlyOwner {
        if(quantity + totalSupply() > maxAmount) revert MintOverMax();
        _mint(user, quantity);
    }

    function batchMintForUser(address[] calldata users, uint256[] calldata quantities) external onlyOwner {
        if (users.length != quantities.length) revert UnbalancedArrays();
        for(uint256 index = 0; index < users.length; index++) {
            _mint(users[index], quantities[index]);
        }
        if(totalSupply() > maxAmount) revert MintOverMax();
    }

    function decimals() public view virtual override returns (uint8) {
        return 0;
    }

    function entriesInLastSnapshot() public view returns(uint256) {
        return mappingLength();
    }

    function entriesFromLastSnapshot(uint256 page, uint256 perPage) 
    external view returns (address[] memory owners, uint256[] memory balances) {
        owners = new address[](perPage);
        balances = new uint256[](perPage);
        uint256 totalEntries = entriesInLastSnapshot();

        uint256 last = (page + 1) * perPage;
        uint256 index = 0;
        for(uint256 next = page * perPage; next < last && next < totalEntries; ) {
            (address a, uint256 b) = entryAt(next);
            owners[index] = a;
            balances[index] = b;
            next++; 
            index++;
        }
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if(paused) revert IsPaused();
        ERC20Enumerable._beforeTokenTransfer(from, to, amount);
    }

}