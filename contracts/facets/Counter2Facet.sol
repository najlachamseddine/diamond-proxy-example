// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { LibAppStorage } from "../libraries/LibAppStorage.sol";

/**
 * @title Counter2Facet
 * @dev Extended counter facet with additional functions
 * 
 * This facet demonstrates how to add new functionality
 * to an existing diamond through upgrades.
 */
contract Counter2Facet {
    
    event CounterIncremented(uint256 newValue);
    event CounterDecremented(uint256 newValue);
    event CounterReset();
    event CounterNewSelectorAdded();

    /**
     * @notice Get the current counter value
     * @return The counter value
     */
    function getCounter() external view returns (uint256) {
        return LibAppStorage.appStorage().counter;
    }

    /**
     * @notice Increment the counter by 1
     */
    function increment() external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        s.counter += 1;
        emit CounterIncremented(s.counter);
    }

    /**
     * @notice Decrement the counter by 1
     */
    function decrement() external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        require(s.counter > 0, "Counter: cannot decrement below zero");
        s.counter -= 1;
        emit CounterDecremented(s.counter);
    }

    /**
     * @notice Increment the counter by a specific amount
     * @param _amount The amount to increment by
     */
    function incrementBy(uint256 _amount) external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        s.counter += _amount;
        emit CounterIncremented(s.counter);
    }

    /**
     * @notice Reset the counter to zero
     */
    function resetCounter() external {
        LibAppStorage.appStorage().counter = 0;
        emit CounterReset();
    }

    function counterFacetNewFunction() external returns (string memory) {
        emit CounterNewSelectorAdded();
        return "This is a new function added in an upgrade";
    }


    function counterFacetNewFunction2() external returns (string memory) {
        emit CounterNewSelectorAdded();
        return "This is a new function 2 added in an upgrade";
    }
}
