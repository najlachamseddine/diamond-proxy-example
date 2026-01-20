// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/CounterFacet.sol";
import "../contracts/facets/ERC20Facet.sol";
import "../contracts/libraries/LibDiamond.sol";

/**
 * @title DiamondDeployScript
 * @dev Foundry script to deploy the Diamond proxy with all facets
 * 
 * Usage:
 *   forge script script/Deploy.s.sol:DiamondDeployScript --rpc-url localhost --broadcast
 *   forge script script/Deploy.s.sol:DiamondDeployScript --rpc-url sepolia --broadcast --verify
 */
contract DiamondDeployScript is Script {
    
    // Deployment addresses (will be set during deployment)
    Diamond public diamond;
    DiamondCutFacet public diamondCutFacet;
    DiamondLoupeFacet public diamondLoupeFacet;
    OwnershipFacet public ownershipFacet;
    CounterFacet public counterFacet;
    ERC20Facet public erc20Facet;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("==============================================");
        console.log("Deploying Diamond with account:", deployer);
        console.log("==============================================\n");

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy all facets
        console.log("Step 1: Deploying Facets...\n");
        
        diamondCutFacet = new DiamondCutFacet();
        console.log("DiamondCutFacet deployed to:", address(diamondCutFacet));
        
        diamondLoupeFacet = new DiamondLoupeFacet();
        console.log("DiamondLoupeFacet deployed to:", address(diamondLoupeFacet));
        
        ownershipFacet = new OwnershipFacet();
        console.log("OwnershipFacet deployed to:", address(ownershipFacet));
        
        counterFacet = new CounterFacet();
        console.log("CounterFacet deployed to:", address(counterFacet));
        
        erc20Facet = new ERC20Facet();
        console.log("ERC20Facet deployed to:", address(erc20Facet));

        // Step 2: Prepare FacetCuts
        console.log("\nStep 2: Preparing FacetCuts...\n");
        
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](5);
        
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondCutFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectorsForDiamondCut()
        });
        
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectorsForDiamondLoupe()
        });
        
        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectorsForOwnership()
        });
        
        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: address(counterFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectorsForCounter()
        });
        
        cuts[4] = IDiamondCut.FacetCut({
            facetAddress: address(erc20Facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSelectorsForERC20()
        });

        console.log("Total facets to add:", cuts.length);
        for (uint256 i = 0; i < cuts.length; i++) {
            console.log("  Facet", i, ":", cuts[i].facetAddress);
            console.log("    Selectors:", cuts[i].functionSelectors.length);
        }

        // Step 3: Deploy Diamond
        console.log("\nStep 3: Deploying Diamond...\n");
        
        diamond = new Diamond(deployer, cuts);
        console.log("Diamond deployed to:", address(diamond));

        // Step 4: Verify deployment
        console.log("\nStep 4: Verifying Deployment...\n");
        
        DiamondLoupeFacet loupe = DiamondLoupeFacet(address(diamond));
        IDiamondLoupe.Facet[] memory facets = loupe.facets();
        
        console.log("Total facets registered:", facets.length);
        for (uint256 i = 0; i < facets.length; i++) {
            console.log("  Facet", i, ":", facets[i].facetAddress);
            console.log("    Selectors:", facets[i].functionSelectors.length);
        }

        // Step 5: Test Counter
        console.log("\nStep 5: Testing Counter Facet...\n");
        
        CounterFacet counter = CounterFacet(address(diamond));
        console.log("Initial counter:", counter.getCounter());
        
        counter.increment();
        console.log("After increment:", counter.getCounter());
        
        counter.incrementBy(5);
        console.log("After incrementBy(5):", counter.getCounter());

        // Step 6: Initialize ERC20
        console.log("\nStep 6: Initializing ERC20 Facet...\n");
        
        ERC20Facet erc20 = ERC20Facet(address(diamond));
        erc20.initializeERC20("Diamond Token", "DMD", 18);
        
        console.log("Token Name:", erc20.name());
        console.log("Token Symbol:", erc20.symbol());
        console.log("Token Decimals:", erc20.decimals());
        
        erc20.mint(deployer, 1000 ether);
        console.log("Minted 1000 tokens to deployer");
        console.log("Deployer balance:", erc20.balanceOf(deployer) / 1e18, "DMD");

        vm.stopBroadcast();

        // Summary
        console.log("\n==============================================");
        console.log("Deployment Complete!");
        console.log("==============================================");
        console.log("Diamond:", address(diamond));
        console.log("DiamondCutFacet:", address(diamondCutFacet));
        console.log("DiamondLoupeFacet:", address(diamondLoupeFacet));
        console.log("OwnershipFacet:", address(ownershipFacet));
        console.log("CounterFacet:", address(counterFacet));
        console.log("ERC20Facet:", address(erc20Facet));
        console.log("Owner:", deployer);
        console.log("==============================================\n");
    }

    // ============================================================
    //                     SELECTOR HELPERS
    // ============================================================

    function getSelectorsForDiamondCut() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = DiamondCutFacet.diamondCut.selector;
        return selectors;
    }

    function getSelectorsForDiamondLoupe() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = DiamondLoupeFacet.facets.selector;
        selectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        selectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        selectors[3] = DiamondLoupeFacet.facetAddress.selector;
        return selectors;
    }

    function getSelectorsForOwnership() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = OwnershipFacet.owner.selector;
        selectors[1] = OwnershipFacet.transferOwnership.selector;
        return selectors;
    }

    function getSelectorsForCounter() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = CounterFacet.getCounter.selector;
        selectors[1] = CounterFacet.increment.selector;
        selectors[2] = CounterFacet.decrement.selector;
        selectors[3] = CounterFacet.incrementBy.selector;
        selectors[4] = CounterFacet.resetCounter.selector;
        return selectors;
    }


    function getSelectorsForCounter2() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = Counter2Facet.getCounter.selector;
        selectors[1] = Counter2Facet.increment.selector;
        selectors[2] = Counter2Facet.decrement.selector;
        selectors[3] = Counter2Facet.incrementBy.selector;
        selectors[4] = Counter2Facet.resetCounter.selector;
        selectors[5] = Counter2Facet.counterFacetNewFunction.selector;
        selectors[6] = Counter2Facet.counterFacetNewFunction2.selector;
        return selectors;
    }

    function getSelectorsForERC20() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](12);
        selectors[0] = ERC20Facet.initializeERC20.selector;
        selectors[1] = ERC20Facet.name.selector;
        selectors[2] = ERC20Facet.symbol.selector;
        selectors[3] = ERC20Facet.decimals.selector;
        selectors[4] = ERC20Facet.totalSupply.selector;
        selectors[5] = ERC20Facet.balanceOf.selector;
        selectors[6] = ERC20Facet.transfer.selector;
        selectors[7] = ERC20Facet.allowance.selector;
        selectors[8] = ERC20Facet.approve.selector;
        selectors[9] = ERC20Facet.transferFrom.selector;
        selectors[10] = ERC20Facet.mint.selector;
        selectors[11] = ERC20Facet.burn.selector;
        return selectors;
    }
}
