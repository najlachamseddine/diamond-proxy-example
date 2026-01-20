// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/CounterFacet.sol";
import "../contracts/facets/Counter2Facet.sol";
import "../contracts/libraries/LibDiamond.sol";

/**
 * @title DiamondUpgradeScript
 * @dev Foundry script to upgrade an existing Diamond
 * 
 * This demonstrates three types of upgrades:
 * 1. Adding new functions (new facet)
 * 2. Replacing existing functions (upgrade facet)
 * 3. Removing functions
 * 
 * Usage:
 *   DIAMOND_ADDRESS=0x... forge script script/Upgrade.s.sol:DiamondUpgradeScript --rpc-url localhost --broadcast
 */
contract DiamondUpgradeScript is Script {
    
    address public diamondAddress;
    Diamond public diamond;

    function run() external {
        // Get diamond address from environment
        diamondAddress = vm.envAddress("DIAMOND_ADDRESS");
        require(diamondAddress != address(0), "DIAMOND_ADDRESS not set");
        
        diamond = Diamond(payable(diamondAddress));
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("==============================================");
        console.log("Upgrading Diamond");
        console.log("==============================================");
        console.log("Diamond Address:", diamondAddress);
        console.log("Deployer:", deployer);
        console.log("==============================================\n");

        vm.startBroadcast(deployerPrivateKey);

        // Example 1: Replace existing Counter functions with new implementation
        upgradeCounterFacet();

        // Example 2: Add a completely new facet (uncomment to use)
        // addNewFacet();

        // Example 3: Remove specific functions (uncomment to use)
        // removeFunctions();

        vm.stopBroadcast();

        // Verify the upgrade
        verifyUpgrade();
    }

    /**
     * @dev Example: Replace existing counter implementation
     * Deploy a new CounterFacet and replace the old one
     */
    function upgradeCounterFacet() internal {
        console.log("Example 1: Upgrading Counter Facet\n");
        
        // Deploy new version of CounterFacet
        CounterFacet newCounterFacet = new CounterFacet();
        console.log("New CounterFacet deployed to:", address(newCounterFacet));
        
        // Get selectors for existing and new functions
        bytes4[] memory existingSelectors = getExistingCounterSelectors();
        // bytes4[] memory newSelectors = getNewCounterSelectors();
        
        // Prepare the facet cuts: Replace existing, Add new
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        
        // Replace existing functions
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(newCounterFacet),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: existingSelectors
        });
        
        // Add new function
        // cuts[1] = IDiamondCut.FacetCut({
        //     facetAddress: address(newCounterFacet),
        //     action: IDiamondCut.FacetCutAction.Add,
        //     functionSelectors: newSelectors
        // });
        
        // Execute the diamond cut
        DiamondCutFacet diamondCut = DiamondCutFacet(diamondAddress);
        diamondCut.diamondCut(cuts, address(0), "");
        
        console.log("Counter functions replaced successfully");
        console.log("Replaced", existingSelectors.length, "existing function selectors");
        // console.log("Added", newSelectors.length, "new function selectors\n");
    }

    /**
     * @dev Example: Add a completely new facet
     * This shows how to extend diamond functionality
     */
    function addNewFacet() internal {
        console.log("Example 2: Adding New Facet\n");
        
        // Deploy Counter2Facet with new functions
        Counter2Facet newFacet = new Counter2Facet();
        console.log("New facet deployed to:", address(newFacet));
        
        // Get selectors (these are NEW selectors not already in the diamond)
        bytes4[] memory selectors = new bytes4[](1);
        // Add the new function from Counter2Facet
        selectors[0] = Counter2Facet.counterFacetNewFunction2.selector;
        
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(newFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
        
        DiamondCutFacet diamondCut = DiamondCutFacet(diamondAddress);
        diamondCut.diamondCut(cuts, address(0), "");
        
        console.log("New facet added successfully\n");
    }

    /**
     * @dev Example: Remove functions from the diamond
     * Useful when deprecating functionality
     */
    function removeFunctions() internal {
        console.log("Example 3: Removing Functions\n");
        
        // Specify which functions to remove
        bytes4[] memory selectorsToRemove = new bytes4[](1);
        selectorsToRemove[0] = CounterFacet.resetCounter.selector;
        
        console.log("Removing resetCounter function...");
        
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(0), // Must be address(0) for Remove action
            action: IDiamondCut.FacetCutAction.Remove,
            functionSelectors: selectorsToRemove
        });
        
        DiamondCutFacet diamondCut = DiamondCutFacet(diamondAddress);
        diamondCut.diamondCut(cuts, address(0), "");
        
        console.log("Functions removed successfully\n");
    }

    /**
     * @dev Verify the upgrade was successful
     */
    function verifyUpgrade() internal view {
        console.log("Verifying Upgrade...\n");
        
        DiamondLoupeFacet loupe = DiamondLoupeFacet(diamondAddress);
        
        // Get all facets
        IDiamondLoupe.Facet[] memory facets = loupe.facets();
        console.log("Total facets:", facets.length);
        
        for (uint256 i = 0; i < facets.length; i++) {
            console.log("  Facet", i, ":", facets[i].facetAddress);
            console.log("    Selectors:", facets[i].functionSelectors.length);
        }
        
        // Check which facet handles getCounter
        bytes4 selector = CounterFacet.getCounter.selector;
        address facetAddress = loupe.facetAddress(selector);
        console.log("\ngetCounter() is handled by:", facetAddress);
        
        // Test the counter still works
        CounterFacet counter = CounterFacet(diamondAddress);
        uint256 currentValue = counter.getCounter();
        console.log("Current counter value:", currentValue);
        
        console.log("\n==============================================");
        console.log("Upgrade Complete!");
        console.log("==============================================\n");
    }

    /**
     * @dev Get all selectors for CounterFacet
     */
    /**
     * @dev Get selectors for existing counter functions
     */
    function getExistingCounterSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = CounterFacet.getCounter.selector;
        selectors[1] = CounterFacet.increment.selector;
        selectors[2] = CounterFacet.decrement.selector;
        selectors[3] = CounterFacet.incrementBy.selector;
        selectors[4] = CounterFacet.counterFacetNewFunction.selector;
        return selectors;
    }

    /**
     * @dev Get selectors for new counter functions
     */
    function getNewCounterSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = CounterFacet.counterFacetNewFunction.selector;
        return selectors;
    }

    /**
     * @dev Get all selectors (for compatibility)
     */
    function getSelectorsForCounter() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = CounterFacet.getCounter.selector;
        selectors[1] = CounterFacet.increment.selector;
        selectors[2] = CounterFacet.decrement.selector;
        selectors[3] = CounterFacet.incrementBy.selector;
        selectors[4] = CounterFacet.resetCounter.selector;
        selectors[5] = CounterFacet.counterFacetNewFunction.selector;
        return selectors;
    }
}

/**
 * @title UpgradeWithInitScript
 * @dev Example of upgrading with initialization function
 * 
 * Sometimes you need to run initialization code during an upgrade.
 * This shows how to use the _init and _calldata parameters.
 */
contract UpgradeWithInitScript is Script {
    
    function run() external {
        address diamondAddress = vm.envAddress("DIAMOND_ADDRESS");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy new facet
        CounterFacet newFacet = new CounterFacet();
        
        // Deploy an initializer contract
        CounterInitializer initializer = new CounterInitializer();
        
        // Prepare the cut
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = CounterFacet.increment.selector;
        
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(newFacet),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: selectors
        });
        
        // Prepare initialization call
        bytes memory initCalldata = abi.encodeWithSelector(
            CounterInitializer.init.selector
        );
        
        // Execute diamond cut with initialization
        DiamondCutFacet diamondCut = DiamondCutFacet(diamondAddress);
        diamondCut.diamondCut(cuts, address(initializer), initCalldata);
        
        vm.stopBroadcast();
        
        console.log("Upgraded with initialization");
    }
}

/**
 * @dev Example initializer contract
 * This runs during the diamond cut to perform one-time setup
 */
contract CounterInitializer {
    function init() external {
        // Initialization logic here
        // Can access diamond storage via LibAppStorage
        console.log("Initializer executed during upgrade");
    }
}
