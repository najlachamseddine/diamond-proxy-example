// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { LibDiamond, IDiamondCut } from "./libraries/LibDiamond.sol";

/**
 * @title Diamond
 * @dev The main Diamond proxy contract (EIP-2535)
 * 
 * This is the entry point for all calls to the diamond.
 * It uses the fallback function to delegatecall to the appropriate facet.
 * 
 * Key Features:
 * 1. Single entry point for all facet functions
 * 2. Uses delegatecall to preserve msg.sender and msg.value
 * 3. Storage is shared across all facets
 * 4. No limit on contract size (24KB limit bypassed)
 * 
 * Best Practices:
 * 1. Initialize all facets in constructor or via diamondCut
 * 2. Use proper access control on diamondCut
 * 3. Consider implementing a pause mechanism
 * 4. Test thoroughly as bugs affect all facets
 */
contract Diamond {
    
    error FunctionNotFound(bytes4 _functionSelector);

    /**
     * @dev Constructor sets up the diamond with initial facets
     * @param _contractOwner The address that will be the owner of the diamond
     * @param _diamondCut Initial facets to add to the diamond
     */
    constructor(
        address _contractOwner,
        IDiamondCut.FacetCut[] memory _diamondCut
    ) payable {
        LibDiamond.setContractOwner(_contractOwner);
        LibDiamond.diamondCut(_diamondCut, address(0), "");
    }

    /**
     * @dev Fallback function that delegates calls to facets
     * 
     * How it works:
     * 1. Look up the facet address for the called function selector
     * 2. If no facet is found, revert with FunctionNotFound
     * 3. Delegatecall to the facet
     * 4. Return any return data or revert with error
     */
    fallback() external payable {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        
        // Get facet from function selector
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;
        
        if (facet == address(0)) {
            revert FunctionNotFound(msg.sig);
        }
        
        // Execute external function from facet using delegatecall
        // This preserves msg.sender, msg.value, and uses diamond's storage
        assembly {
            // Copy function selector and any arguments
            calldatacopy(0, 0, calldatasize())
            
            // Execute function call using the facet
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            
            // Get any return value
            returndatacopy(0, 0, returndatasize())
            
            // Return any return value or revert if call failed
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev Receive function to accept ETH transfers
     */
    receive() external payable {}
}
