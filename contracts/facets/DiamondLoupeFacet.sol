// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { LibDiamond } from "../libraries/LibDiamond.sol";

/**
 * @title IDiamondLoupe
 * @dev Standard interface for the Diamond Loupe
 * See: https://eips.ethereum.org/EIPS/eip-2535
 */
interface IDiamondLoupe {
    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    function facets() external view returns (Facet[] memory facets_);
    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetFunctionSelectors_);
    function facetAddresses() external view returns (address[] memory facetAddresses_);
    function facetAddress(bytes4 _functionSelector) external view returns (address facetAddress_);
}

/**
 * @title DiamondLoupeFacet
 * @dev Implements IDiamondLoupe for introspection of the diamond
 * 
 * The Loupe allows external contracts and users to query:
 * - All facets and their selectors
 * - Which facet handles a specific function
 * - All functions a facet provides
 * 
 * This is essential for transparency and verification of diamond state.
 */
contract DiamondLoupeFacet is IDiamondLoupe {
    
    /**
     * @notice Gets all facet addresses and their four byte function selectors
     * @return facets_ Array of Facet structs
     */
    function facets() external view override returns (Facet[] memory facets_) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        uint256 numFacets = ds.facetAddresses.length;
        facets_ = new Facet[](numFacets);
        
        for (uint256 i; i < numFacets; i++) {
            address facetAddress_ = ds.facetAddresses[i];
            facets_[i].facetAddress = facetAddress_;
            facets_[i].functionSelectors = ds.facetFunctionSelectors[facetAddress_].functionSelectors;
        }
    }

    /**
     * @notice Gets all the function selectors provided by a facet
     * @param _facet The facet address
     * @return facetFunctionSelectors_ Array of function selectors
     */
    function facetFunctionSelectors(address _facet) 
        external 
        view 
        override 
        returns (bytes4[] memory facetFunctionSelectors_) 
    {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        facetFunctionSelectors_ = ds.facetFunctionSelectors[_facet].functionSelectors;
    }

    /**
     * @notice Get all the facet addresses used by a diamond
     * @return facetAddresses_ Array of facet addresses
     */
    function facetAddresses() external view override returns (address[] memory facetAddresses_) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        facetAddresses_ = ds.facetAddresses;
    }

    /**
     * @notice Gets the facet that supports the given selector
     * @dev If facet is not found return address(0)
     * @param _functionSelector The function selector
     * @return facetAddress_ The facet address
     */
    function facetAddress(bytes4 _functionSelector) 
        external 
        view 
        override 
        returns (address facetAddress_) 
    {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        facetAddress_ = ds.selectorToFacetAndPosition[_functionSelector].facetAddress;
    }
}
