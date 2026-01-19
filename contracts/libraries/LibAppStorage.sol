// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title LibAppStorage
 * @dev Shared application storage for facets
 * 
 * This demonstrates the "AppStorage" pattern where facets
 * share common application state through a single storage struct.
 * 
 * Best Practices:
 * 1. Only append new fields, never remove or reorder
 * 2. Use a unique storage position like in LibDiamond
 * 3. Document each field for clarity
 */
library LibAppStorage {
    
    bytes32 constant APP_STORAGE_POSITION = 
        keccak256("diamond.app.storage");

    struct AppStorage {
        // ERC20-like storage
        string name;
        string symbol;
        uint8 decimals;
        uint256 totalSupply;
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
        
        // Counter example storage  
        uint256 counter;
        
        // Additional app-specific storage can be added here
        bool initialized;
        mapping(address => bool) admins;
    }

    function appStorage() internal pure returns (AppStorage storage s) {
        bytes32 position = APP_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }
}
