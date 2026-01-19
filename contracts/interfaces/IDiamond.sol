// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Interfaces for the Diamond
 * @dev Standard interfaces following EIP-2535
 */

interface IDiamondCut {
    enum FacetCutAction { Add, Replace, Remove }

    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    event DiamondCut(FacetCut[] _diamondCut, address _init, bytes _calldata);

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external;
}

interface IDiamondLoupe {
    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    function facets() external view returns (Facet[] memory facets_);
    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetFunctionSelectors_);
    function facetAddresses() external view returns (address[] memory facetAddresses_);
    function facetAddress(bytes4 _functionSelector) external view returns (address facetAddress_);
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IOwnership {
    function owner() external view returns (address);
    function transferOwnership(address _newOwner) external;
}
