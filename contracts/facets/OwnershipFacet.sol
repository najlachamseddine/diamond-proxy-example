// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { LibDiamond } from "../libraries/LibDiamond.sol";

/**
 * @title OwnershipFacet
 * @dev Facet for managing diamond ownership
 * 
 * Provides ownership transfer functionality.
 * The owner can add/remove facets via DiamondCutFacet.
 */
contract OwnershipFacet {
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @notice Get the current owner of the diamond
     * @return owner_ The owner address
     */
    function owner() external view returns (address owner_) {
        owner_ = LibDiamond.contractOwner();
    }

    /**
     * @notice Transfer ownership to a new address
     * @param _newOwner The new owner's address
     */
    function transferOwnership(address _newOwner) external {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.setContractOwner(_newOwner);
    }
}
