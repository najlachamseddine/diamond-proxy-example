// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { LibDiamond, IDiamondCut } from "../libraries/LibDiamond.sol";

/**
 * @title DiamondCutFacet
 * @dev Facet for adding, replacing, and removing functions in the diamond
 * 
 * This is a critical facet that should be carefully protected.
 * Only the contract owner can call diamondCut.
 * 
 * Best Practices:
 * 1. Always verify the facet addresses have code before adding
 * 2. Consider using a timelock for production diamonds
 * 3. Emit events for all changes for transparency
 */
contract DiamondCutFacet is IDiamondCut {
    
    /**
     * @notice Add/replace/remove any number of functions and optionally execute
     *         a function with delegatecall
     * @param _diamondCut Contains the facet addresses and function selectors
     * @param _init The address of the contract or facet to execute _calldata
     * @param _calldata A function call, including function selector and arguments
     *                  _calldata is executed with delegatecall on _init
     */
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external {
        // Only owner can make changes
        LibDiamond.enforceIsContractOwner();
        LibDiamond.diamondCut(_diamondCut, _init, _calldata);
    }
}
