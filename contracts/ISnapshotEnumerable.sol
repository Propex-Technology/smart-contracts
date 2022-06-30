// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

// Intended for future snapshot contracts. Currently no snapshot
interface ISnapshotEnumerable {
    function entriesInLastSnapshot() external view returns(uint256);

    function entriesFromLastSnapshot(uint256 page, uint256 perPage) 
    external view returns (address[] memory, uint256[] memory);
}