// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title LibDiamond
 * @dev Diamond Storage library implementing EIP-2535
 * 
 * This library contains the core storage structure and functions
 * for managing facets, function selectors, and ownership.
 * 
 * Best Practices:
 * 1. Use a unique storage position to avoid collisions
 * 2. All facets share this storage through delegatecall
 * 3. Each facet can have its own AppStorage for facet-specific data
 */

interface IDiamondCut {
    enum FacetCutAction { Add, Replace, Remove }

    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    event DiamondCut(FacetCut[] _diamondCut, address _init, bytes _calldata);
}

library LibDiamond {
    // =============================================================
    //                        STORAGE
    // =============================================================
    
    /**
     * @dev Storage position for diamond storage
     * keccak256("diamond.standard.diamond.storage") - 1
     * This ensures no collision with other storage patterns
     */
    bytes32 constant DIAMOND_STORAGE_POSITION = 
        keccak256("diamond.standard.diamond.storage");

    struct FacetAddressAndPosition {
        address facetAddress;
        uint96 functionSelectorPosition; // position in facetFunctionSelectors.functionSelectors array
    }

    struct FacetFunctionSelectors {
        bytes4[] functionSelectors;
        uint256 facetAddressPosition; // position of facetAddress in facetAddresses array
    }

    struct DiamondStorage {
        // Maps function selector to the facet address and
        // the position of the selector in the facetFunctionSelectors.selectors array
        mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;
        // Maps facet addresses to function selectors
        mapping(address => FacetFunctionSelectors) facetFunctionSelectors;
        // Facet addresses
        address[] facetAddresses;
        // Owner of the contract
        address contractOwner;
        // Used to query if a contract implements an interface (ERC-165)
        mapping(bytes4 => bool) supportedInterfaces;
    }

    // =============================================================
    //                        EVENTS
    // =============================================================

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event DiamondCut(IDiamondCut.FacetCut[] _diamondCut, address _init, bytes _calldata);

    // =============================================================
    //                        ERRORS
    // =============================================================

    error NotContractOwner(address _user, address _contractOwner);
    error NoSelectorsProvidedForFacetForCut(address _facetAddress);
    error CannotAddSelectorsToZeroAddress(bytes4[] _selectors);
    error NoBytecodeAtAddress(address _contractAddress, string _message);
    error IncorrectFacetCutAction(uint8 _action);
    error CannotAddFunctionToDiamondThatAlreadyExists(bytes4 _selector);
    error CannotReplaceFunctionsFromFacetWithZeroAddress(bytes4[] _selectors);
    error CannotReplaceImmutableFunction(bytes4 _selector);
    error CannotReplaceFunctionWithTheSameFunctionFromTheSameFacet(bytes4 _selector);
    error CannotReplaceFunctionThatDoesNotExists(bytes4 _selector);
    error RemoveFacetAddressMustBeZeroAddress(address _facetAddress);
    error CannotRemoveFunctionThatDoesNotExist(bytes4 _selector);
    error CannotRemoveImmutableFunction(bytes4 _selector);
    error InitializationFunctionReverted(address _initializationContractAddress, bytes _calldata);

    // =============================================================
    //                     STORAGE ACCESS
    // =============================================================

    /**
     * @dev Returns the diamond storage struct
     * Uses assembly to set storage position to avoid conflicts
     */
    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    // =============================================================
    //                     OWNERSHIP
    // =============================================================

    function setContractOwner(address _newOwner) internal {
        DiamondStorage storage ds = diamondStorage();
        address previousOwner = ds.contractOwner;
        ds.contractOwner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    function contractOwner() internal view returns (address contractOwner_) {
        contractOwner_ = diamondStorage().contractOwner;
    }

    function enforceIsContractOwner() internal view {
        DiamondStorage storage ds = diamondStorage();
        if (msg.sender != ds.contractOwner) {
            revert NotContractOwner(msg.sender, ds.contractOwner);
        }
    }

    // =============================================================
    //                     DIAMOND CUT
    // =============================================================

    /**
     * @dev Main function to add, replace, or remove facet functions
     * @param _diamondCut Array of facet cuts to execute
     * @param _init Address of contract to execute _calldata on
     * @param _calldata Data to delegatecall to _init
     */
    function diamondCut(
        IDiamondCut.FacetCut[] memory _diamondCut,
        address _init,
        bytes memory _calldata
    ) internal {
        for (uint256 facetIndex; facetIndex < _diamondCut.length; facetIndex++) {
            IDiamondCut.FacetCutAction action = _diamondCut[facetIndex].action;
            if (action == IDiamondCut.FacetCutAction.Add) {
                addFunctions(
                    _diamondCut[facetIndex].facetAddress,
                    _diamondCut[facetIndex].functionSelectors
                );
            } else if (action == IDiamondCut.FacetCutAction.Replace) {
                replaceFunctions(
                    _diamondCut[facetIndex].facetAddress,
                    _diamondCut[facetIndex].functionSelectors
                );
            } else if (action == IDiamondCut.FacetCutAction.Remove) {
                removeFunctions(
                    _diamondCut[facetIndex].facetAddress,
                    _diamondCut[facetIndex].functionSelectors
                );
            } else {
                revert IncorrectFacetCutAction(uint8(action));
            }
        }
        emit DiamondCut(_diamondCut, _init, _calldata);
        initializeDiamondCut(_init, _calldata);
    }

    /**
     * @dev Add new functions to the diamond
     */
    function addFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        if (_functionSelectors.length == 0) {
            revert NoSelectorsProvidedForFacetForCut(_facetAddress);
        }
        DiamondStorage storage ds = diamondStorage();
        if (_facetAddress == address(0)) {
            revert CannotAddSelectorsToZeroAddress(_functionSelectors);
        }
        uint96 selectorPosition = uint96(
            ds.facetFunctionSelectors[_facetAddress].functionSelectors.length
        );
        // Add new facet address if it does not exist
        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            if (oldFacetAddress != address(0)) {
                revert CannotAddFunctionToDiamondThatAlreadyExists(selector);
            }
            addFunction(ds, selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    /**
     * @dev Replace existing functions in the diamond
     */
    function replaceFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        if (_functionSelectors.length == 0) {
            revert NoSelectorsProvidedForFacetForCut(_facetAddress);
        }
        DiamondStorage storage ds = diamondStorage();
        if (_facetAddress == address(0)) {
            revert CannotReplaceFunctionsFromFacetWithZeroAddress(_functionSelectors);
        }
        uint96 selectorPosition = uint96(
            ds.facetFunctionSelectors[_facetAddress].functionSelectors.length
        );
        // Add new facet address if it does not exist
        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            if (oldFacetAddress == _facetAddress) {
                revert CannotReplaceFunctionWithTheSameFunctionFromTheSameFacet(selector);
            }
            if (oldFacetAddress == address(0)) {
                revert CannotReplaceFunctionThatDoesNotExists(selector);
            }
            // Can't replace immutable functions -- functions defined directly in the diamond
            if (oldFacetAddress == address(this)) {
                revert CannotReplaceImmutableFunction(selector);
            }
            removeFunction(ds, oldFacetAddress, selector);
            addFunction(ds, selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    /**
     * @dev Remove functions from the diamond
     */
    function removeFunctions(
        address _facetAddress,
        bytes4[] memory _functionSelectors
    ) internal {
        if (_functionSelectors.length == 0) {
            revert NoSelectorsProvidedForFacetForCut(_facetAddress);
        }
        DiamondStorage storage ds = diamondStorage();
        // _facetAddress must be zero for removing functions
        if (_facetAddress != address(0)) {
            revert RemoveFacetAddressMustBeZeroAddress(_facetAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            if (oldFacetAddress == address(0)) {
                revert CannotRemoveFunctionThatDoesNotExist(selector);
            }
            // Can't remove immutable function
            if (oldFacetAddress == address(this)) {
                revert CannotRemoveImmutableFunction(selector);
            }
            removeFunction(ds, oldFacetAddress, selector);
        }
    }

    // =============================================================
    //                     INTERNAL HELPERS
    // =============================================================

    function addFacet(DiamondStorage storage ds, address _facetAddress) internal {
        enforceHasContractCode(_facetAddress, "LibDiamond: New facet has no code");
        ds.facetFunctionSelectors[_facetAddress].facetAddressPosition = ds.facetAddresses.length;
        ds.facetAddresses.push(_facetAddress);
    }

    function addFunction(
        DiamondStorage storage ds,
        bytes4 _selector,
        uint96 _selectorPosition,
        address _facetAddress
    ) internal {
        ds.selectorToFacetAndPosition[_selector].functionSelectorPosition = _selectorPosition;
        ds.selectorToFacetAndPosition[_selector].facetAddress = _facetAddress;
        ds.facetFunctionSelectors[_facetAddress].functionSelectors.push(_selector);
    }

    function removeFunction(
        DiamondStorage storage ds,
        address _facetAddress,
        bytes4 _selector
    ) internal {
        // Get position of selector in functionSelectors array
        uint256 selectorPosition = ds.selectorToFacetAndPosition[_selector].functionSelectorPosition;
        uint256 lastSelectorPosition = ds.facetFunctionSelectors[_facetAddress].functionSelectors.length - 1;
        
        // If not the last selector, swap with last and pop
        if (selectorPosition != lastSelectorPosition) {
            bytes4 lastSelector = ds.facetFunctionSelectors[_facetAddress].functionSelectors[lastSelectorPosition];
            ds.facetFunctionSelectors[_facetAddress].functionSelectors[selectorPosition] = lastSelector;
            ds.selectorToFacetAndPosition[lastSelector].functionSelectorPosition = uint96(selectorPosition);
        }
        
        ds.facetFunctionSelectors[_facetAddress].functionSelectors.pop();
        delete ds.selectorToFacetAndPosition[_selector];

        // If no more selectors for this facet, remove the facet address
        if (lastSelectorPosition == 0) {
            uint256 lastFacetAddressPosition = ds.facetAddresses.length - 1;
            uint256 facetAddressPosition = ds.facetFunctionSelectors[_facetAddress].facetAddressPosition;
            if (facetAddressPosition != lastFacetAddressPosition) {
                address lastFacetAddress = ds.facetAddresses[lastFacetAddressPosition];
                ds.facetAddresses[facetAddressPosition] = lastFacetAddress;
                ds.facetFunctionSelectors[lastFacetAddress].facetAddressPosition = facetAddressPosition;
            }
            ds.facetAddresses.pop();
            delete ds.facetFunctionSelectors[_facetAddress].facetAddressPosition;
        }
    }

    function initializeDiamondCut(address _init, bytes memory _calldata) internal {
        if (_init == address(0)) {
            return;
        }
        enforceHasContractCode(_init, "LibDiamond: _init address has no code");
        (bool success, bytes memory error) = _init.delegatecall(_calldata);
        if (!success) {
            if (error.length > 0) {
                // Bubble up the error
                assembly {
                    let returndata_size := mload(error)
                    revert(add(32, error), returndata_size)
                }
            } else {
                revert InitializationFunctionReverted(_init, _calldata);
            }
        }
    }

    function enforceHasContractCode(address _contract, string memory _errorMessage) internal view {
        uint256 contractSize;
        assembly {
            contractSize := extcodesize(_contract)
        }
        if (contractSize == 0) {
            revert NoBytecodeAtAddress(_contract, _errorMessage);
        }
    }
}
