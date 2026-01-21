// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/CounterFacet.sol";
import "../contracts/libraries/LibDiamond.sol";

/**
 * @title AddFacetScript
 * @dev Auto-generated script to add new functions to CounterFacet
 * 
 * Functions to add: 1
 * - resetCounter()
 * 
 * Usage:
 *   DIAMOND_ADDRESS=0x... forge script script/AddFacet.s.sol:AddFacetScript --rpc-url sepolia --broadcast
 */
contract AddFacetScript is Script {
    
    function run() external {
        address diamondAddress = vm.envAddress("DIAMOND_ADDRESS");
        require(diamondAddress != address(0), "DIAMOND_ADDRESS not set");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console.log("==============================================");
        console.log("Adding Functions to Diamond");
        console.log("==============================================");
        console.log("Diamond Address:", diamondAddress);
        console.log("Facet: CounterFacet");
        console.log("Functions to add:");
        console.logUint(1);
        console.log("==============================================\n");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy new facet
        CounterFacet newFacet = new CounterFacet();
        console.log("New CounterFacet deployed to:", address(newFacet));
        
        // Prepare selectors for functions to add
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = 0xdbdf7fce;
        
        // Prepare diamond cut
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(newFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
        
        // Execute diamond cut
        DiamondCutFacet(diamondAddress).diamondCut(cuts, address(0), "");
        
        vm.stopBroadcast();
        
        console.log("\nSuccessfully added", selectors.length, "functions");
        console.log("==============================================\n");
    }
}
