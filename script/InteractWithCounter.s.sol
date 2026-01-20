// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/facets/CounterFacet.sol";

/**
 * @title InteractWithCounter
 * @dev Script to interact with the Counter facet on deployed Diamond
 * 
 * Usage:
 *   DIAMOND_ADDRESS=0x59624aF30be972C6dbd57Cd89000336a289F7684 \
 *   forge script script/InteractWithCounter.s.sol:InteractWithCounter \
 *   --rpc-url sepolia \
 *   --broadcast
 */
contract InteractWithCounter is Script {
    
    function run() external {
        // Get diamond address from environment
        address diamondAddress = vm.envAddress("DIAMOND_ADDRESS");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console.log("==============================================");
        console.log("Interacting with Diamond Counter Facet");
        console.log("==============================================");
        console.log("Diamond Address:", diamondAddress);
        console.log("==============================================\n");

        // Connect to counter facet through diamond
        CounterFacet counter = CounterFacet(diamondAddress);

        // Step 1: Read initial counter value
        console.log("Step 1: Reading initial counter value...");
        uint256 initialValue = counter.getCounter();
        console.log("Initial counter value:", initialValue);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Step 2: Increment by 10
        console.log("Step 2: Incrementing counter by 10...");
        counter.incrementBy(10);
        uint256 afterIncrement = counter.getCounter();
        console.log("Counter after increment by 10:", afterIncrement);
        console.log("");

        // Step 3: Decrement by 5
        console.log("Step 3: Decrementing counter by 5...");
        for (uint256 i = 0; i < 5; i++) {
            counter.decrement();
        }
        uint256 afterDecrement = counter.getCounter();
        console.log("Counter after decrement by 5:", afterDecrement);
        console.log("");

        vm.stopBroadcast();

        // Step 4: Read final value
        console.log("Step 4: Reading final counter value...");
        uint256 finalValue = counter.getCounter();
        console.log("Final counter value:", finalValue);
        console.log("");

        // Summary
        console.log("==============================================");
        console.log("Summary");
        console.log("==============================================");
        console.log("Initial value:", initialValue);
        console.log("After +10:    ", afterIncrement);
        console.log("After -5:     ", afterDecrement);
        console.log("Final value:  ", finalValue);
        
        int256 change = int256(finalValue) - int256(initialValue);
        if (change >= 0) {
            console.log("Total change:  +", uint256(change));
        } else {
            console.log("Total change:  -", uint256(-change));
        }
        console.log("==============================================\n");
    }
}
