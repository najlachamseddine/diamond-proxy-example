// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/libraries/LibDiamond.sol";

/**
 * @title RemoveFacetScript
 * @dev Auto-generated script to remove functions from CounterFacet
 * 
 * Functions to remove: 20
 * Selectors: 0x06fdde03, 0x095ea7b3, 0x18160ddd, 0x1e912906, 0x1f931c1c, 0x23b872dd, 0x2bc7bdd2, 0x313ce567, 0x40c10f19, 0x42966c68, 0x52ef6b2c, 0x70a08231, 0x7a0ed627, 0x8da5cb5b, 0x95d89b41, 0xa9059cbb, 0xadfca15e, 0xcdffacc6, 0xdd62ed3e, 0xf2fde38b
 * 
 * Usage:
 *   DIAMOND_ADDRESS=0x... forge script script/RemoveFacet.s.sol:RemoveFacetScript --rpc-url sepolia --broadcast
 */
contract RemoveFacetScript is Script {
    
    function run() external {
        address diamondAddress = vm.envAddress("DIAMOND_ADDRESS");
        require(diamondAddress != address(0), "DIAMOND_ADDRESS not set");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console.log("==============================================");
        console.log("Removing Functions from Diamond");
        console.log("==============================================");
        console.log("Diamond Address:", diamondAddress);
        console.log("Facet: CounterFacet");
        console.log("Functions to remove:");
        console.logUint(20);
        console.log("==============================================\n");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Prepare selectors for functions to remove
        bytes4[] memory selectors = new bytes4[](20);
        selectors[0] = 0x06fdde03;
        selectors[1] = 0x095ea7b3;
        selectors[2] = 0x18160ddd;
        selectors[3] = 0x1e912906;
        selectors[4] = 0x1f931c1c;
        selectors[5] = 0x23b872dd;
        selectors[6] = 0x2bc7bdd2;
        selectors[7] = 0x313ce567;
        selectors[8] = 0x40c10f19;
        selectors[9] = 0x42966c68;
        selectors[10] = 0x52ef6b2c;
        selectors[11] = 0x70a08231;
        selectors[12] = 0x7a0ed627;
        selectors[13] = 0x8da5cb5b;
        selectors[14] = 0x95d89b41;
        selectors[15] = 0xa9059cbb;
        selectors[16] = 0xadfca15e;
        selectors[17] = 0xcdffacc6;
        selectors[18] = 0xdd62ed3e;
        selectors[19] = 0xf2fde38b;
        
        // Prepare diamond cut
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(0), // Must be zero for Remove
            action: IDiamondCut.FacetCutAction.Remove,
            functionSelectors: selectors
        });
        
        // Execute diamond cut
        DiamondCutFacet(diamondAddress).diamondCut(cuts, address(0), "");
        
        vm.stopBroadcast();
        
        console.log("\nSuccessfully removed", selectors.length, "functions");
        console.log("==============================================\n");
    }
}
