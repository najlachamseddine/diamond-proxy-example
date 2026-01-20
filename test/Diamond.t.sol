// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/CounterFacet.sol";
import "../contracts/facets/ERC20Facet.sol";
import "../contracts/libraries/LibDiamond.sol";

contract DiamondTest is Test {
    Diamond public diamond;
    DiamondCutFacet public diamondCutFacet;
    DiamondLoupeFacet public diamondLoupeFacet;
    OwnershipFacet public ownershipFacet;
    CounterFacet public counterFacet;
    ERC20Facet public erc20Facet;
    
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy facets
        diamondCutFacet = new DiamondCutFacet();
        diamondLoupeFacet = new DiamondLoupeFacet();
        ownershipFacet = new OwnershipFacet();
        counterFacet = new CounterFacet();
        erc20Facet = new ERC20Facet();

        // Prepare facet cuts
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

        // Deploy Diamond
        diamond = new Diamond(owner, cuts);
    }

    // ============================================================
    //                     LOUPE TESTS
    // ============================================================

    function test_FacetAddresses() public view {
        DiamondLoupeFacet loupe = DiamondLoupeFacet(address(diamond));
        address[] memory addresses = loupe.facetAddresses();
        assertEq(addresses.length, 5);
    }

    function test_Facets() public view {
        DiamondLoupeFacet loupe = DiamondLoupeFacet(address(diamond));
        IDiamondLoupe.Facet[] memory facets = loupe.facets();
        assertEq(facets.length, 5);
        
        for (uint256 i = 0; i < facets.length; i++) {
            assertTrue(facets[i].functionSelectors.length > 0);
        }
    }

    function test_FacetAddress() public view {
        DiamondLoupeFacet loupe = DiamondLoupeFacet(address(diamond));
        bytes4 selector = CounterFacet.getCounter.selector;
        address facetAddress = loupe.facetAddress(selector);
        assertEq(facetAddress, address(counterFacet));
    }

    // ============================================================
    //                     OWNERSHIP TESTS
    // ============================================================

    function test_Owner() public view {
        OwnershipFacet ownership = OwnershipFacet(address(diamond));
        assertEq(ownership.owner(), owner);
    }

    function test_TransferOwnership() public {
        OwnershipFacet ownership = OwnershipFacet(address(diamond));
        ownership.transferOwnership(user1);
        assertEq(ownership.owner(), user1);
        
        vm.prank(user1);
        ownership.transferOwnership(owner);
        assertEq(ownership.owner(), owner);
    }

    function test_RevertWhen_NonOwnerTransfersOwnership() public {
        OwnershipFacet ownership = OwnershipFacet(address(diamond));
        vm.prank(user2);
        vm.expectRevert();
        ownership.transferOwnership(user2);
    }

    // ============================================================
    //                     COUNTER TESTS
    // ============================================================

    function test_CounterStartsAtZero() public view {
        CounterFacet counter = CounterFacet(address(diamond));
        assertEq(counter.getCounter(), 0);
    }

    function test_Increment() public {
        CounterFacet counter = CounterFacet(address(diamond));
        counter.increment();
        assertEq(counter.getCounter(), 1);
    }

    function test_IncrementBy() public {
        CounterFacet counter = CounterFacet(address(diamond));
        counter.incrementBy(5);
        assertEq(counter.getCounter(), 5);
    }

    function test_Decrement() public {
        CounterFacet counter = CounterFacet(address(diamond));
        counter.incrementBy(10);
        counter.decrement();
        assertEq(counter.getCounter(), 9);
    }

    function test_ResetCounter() public {
        CounterFacet counter = CounterFacet(address(diamond));
        counter.incrementBy(100);
        counter.resetCounter();
        assertEq(counter.getCounter(), 0);
    }

    function test_RevertWhen_DecrementBelowZero() public {
        CounterFacet counter = CounterFacet(address(diamond));
        vm.expectRevert("Counter: cannot decrement below zero");
        counter.decrement();
    }

    // ============================================================
    //                     ERC20 TESTS
    // ============================================================

    function test_InitializeERC20() public {
        ERC20Facet erc20 = ERC20Facet(address(diamond));
        erc20.initializeERC20("Diamond Token", "DMD", 18);
        
        assertEq(erc20.name(), "Diamond Token");
        assertEq(erc20.symbol(), "DMD");
        assertEq(erc20.decimals(), 18);
    }

    function test_RevertWhen_ReinitializeERC20() public {
        ERC20Facet erc20 = ERC20Facet(address(diamond));
        erc20.initializeERC20("Diamond Token", "DMD", 18);
        
        vm.expectRevert("ERC20: already initialized");
        erc20.initializeERC20("New Token", "NEW", 18);
    }

    function test_Mint() public {
        ERC20Facet erc20 = ERC20Facet(address(diamond));
        erc20.initializeERC20("Diamond Token", "DMD", 18);
        
        uint256 amount = 1000 ether;
        erc20.mint(owner, amount);
        
        assertEq(erc20.balanceOf(owner), amount);
        assertEq(erc20.totalSupply(), amount);
    }

    function test_Transfer() public {
        ERC20Facet erc20 = ERC20Facet(address(diamond));
        erc20.initializeERC20("Diamond Token", "DMD", 18);
        erc20.mint(owner, 1000 ether);
        
        uint256 amount = 100 ether;
        erc20.transfer(user1, amount);
        
        assertEq(erc20.balanceOf(user1), amount);
        assertEq(erc20.balanceOf(owner), 900 ether);
    }

    function test_ApproveAndTransferFrom() public {
        ERC20Facet erc20 = ERC20Facet(address(diamond));
        erc20.initializeERC20("Diamond Token", "DMD", 18);
        erc20.mint(owner, 1000 ether);
        erc20.transfer(user1, 100 ether);
        
        uint256 amount = 50 ether;
        
        vm.prank(user1);
        erc20.approve(user2, amount);
        assertEq(erc20.allowance(user1, user2), amount);
        
        vm.prank(user2);
        erc20.transferFrom(user1, user2, amount);
        assertEq(erc20.balanceOf(user2), amount);
    }

    function test_Burn() public {
        ERC20Facet erc20 = ERC20Facet(address(diamond));
        erc20.initializeERC20("Diamond Token", "DMD", 18);
        erc20.mint(owner, 1000 ether);
        
        uint256 burnAmount = 100 ether;
        erc20.burn(burnAmount);
        
        assertEq(erc20.balanceOf(owner), 900 ether);
        assertEq(erc20.totalSupply(), 900 ether);
    }

    // ============================================================
    //                     DIAMOND CUT TESTS
    // ============================================================

    function test_UpgradeCounterFacet() public {
        // Deploy new version
        CounterFacet newCounterFacet = new CounterFacet();
        
        bytes4[] memory selectors = getSelectorsForCounter();
        
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(newCounterFacet),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: selectors
        });
        
        DiamondCutFacet diamondCut = DiamondCutFacet(address(diamond));
        diamondCut.diamondCut(cuts, address(0), "");
        
        // Verify
        DiamondLoupeFacet loupe = DiamondLoupeFacet(address(diamond));
        address facetAddress = loupe.facetAddress(selectors[0]);
        assertEq(facetAddress, address(newCounterFacet));
    }

    function test_RevertWhen_NonOwnerCallsDiamondCut() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](0);
        
        DiamondCutFacet diamondCut = DiamondCutFacet(address(diamond));
        vm.prank(user1);
        vm.expectRevert();
        diamondCut.diamondCut(cuts, address(0), "");
    }

    function test_RemoveFunction() public {
        bytes4[] memory selectorsToRemove = new bytes4[](1);
        selectorsToRemove[0] = CounterFacet.resetCounter.selector;
        
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(0),
            action: IDiamondCut.FacetCutAction.Remove,
            functionSelectors: selectorsToRemove
        });
        
        DiamondCutFacet diamondCut = DiamondCutFacet(address(diamond));
        diamondCut.diamondCut(cuts, address(0), "");
        
        // Verify removal
        DiamondLoupeFacet loupe = DiamondLoupeFacet(address(diamond));
        address facetAddress = loupe.facetAddress(selectorsToRemove[0]);
        assertEq(facetAddress, address(0));
    }

    // ============================================================
    //                     HELPER FUNCTIONS
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
