// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/CounterFacet.sol";
import "../contracts/libraries/LibDiamond.sol";

/**
 * @title ReplaceFacetScript
 * @dev Auto-generated script to replace existing functions in CounterFacet
 * 
 * Functions to replace: 6
 * - counterFacetNewFunction()
 * - decrement()
 * - getCounter()
 * - increment()
 * - incrementBy(uint256)
 * - resetCounter()
 * 
 * Usage:
 *   DIAMOND_ADDRESS=0x... forge script script/ReplaceFacet.s.sol:ReplaceFacetScript --rpc-url sepolia --broadcast
 */
contract ReplaceFacetScript is Script {
    
    function run() external {
        address diamondAddress = vm.envAddress("DIAMOND_ADDRESS");
        require(diamondAddress != address(0), "DIAMOND_ADDRESS not set");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console.log("==============================================");
        console.log("Replacing Functions in Diamond");
        console.log("==============================================");
        console.log("Diamond Address:", diamondAddress);
        console.log("Facet: CounterFacet");
        console.log("Functions to replace:");
        console.logUint(6);
        console.log("==============================================\n");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy new facet
        CounterFacet newFacet = new CounterFacet();
        console.log("New CounterFacet deployed to:", address(newFacet));
        
        // Prepare selectors for functions to replace
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = 0x03df179c;
        selectors[1] = 0x2baeceb7;
        selectors[2] = 0x796446af;
        selectors[3] = 0x8ada066e;
        selectors[4] = 0xd09de08a;
        selectors[5] = 0xdbdf7fce;
        
        // Prepare diamond cut
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(newFacet),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: selectors
        });
        
        // Execute diamond cut
        DiamondCutFacet(diamondAddress).diamondCut(cuts, address(0), "");
        
        vm.stopBroadcast();
        
        console.log("\nSuccessfully replaced", selectors.length, "functions");
        console.log("==============================================\n");
    }
}
