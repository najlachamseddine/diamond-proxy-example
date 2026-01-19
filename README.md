# Diamond Proxy Pattern Example (EIP-2535)

A comprehensive implementation of the Diamond Proxy Pattern following EIP-2535 best practices.

## 🔷 What is the Diamond Pattern?

The Diamond Pattern is a proxy pattern that allows a single contract address to support an unlimited number of functions by delegating calls to multiple implementation contracts called **facets**.

### Key Benefits

1. **No Size Limit**: Bypass the 24KB contract size limit
2. **Modular Upgrades**: Add, replace, or remove functions independently
3. **Shared Storage**: All facets share the same storage context
4. **Single Address**: Users interact with one contract address
5. **Gas Efficient**: No extra proxy hops

### Architecture

```
                    ┌─────────────────┐
                    │     Diamond     │
                    │   (fallback)    │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
       ┌──────────┐   ┌──────────┐   ┌──────────┐
       │  Facet A │   │  Facet B │   │  Facet C │
       │ func1()  │   │ func3()  │   │ func5()  │
       │ func2()  │   │ func4()  │   │ func6()  │
       └──────────┘   └──────────┘   └──────────┘
```

## 📁 Project Structure

```
contracts/
├── Diamond.sol                 # Main proxy contract
├── interfaces/
│   └── IDiamond.sol           # Standard interfaces
├── libraries/
│   ├── LibDiamond.sol         # Core diamond storage & logic
│   └── LibAppStorage.sol      # Application-specific storage
└── facets/
    ├── DiamondCutFacet.sol    # Add/replace/remove functions
    ├── DiamondLoupeFacet.sol  # Introspection (query facets)
    ├── OwnershipFacet.sol     # Ownership management
    ├── CounterFacet.sol       # Example: Counter functionality
    └── ERC20Facet.sol         # Example: ERC20 token
scripts/
├── deploy.js                   # Deployment script
└── upgrade.js                  # Upgrade example
test/
└── Diamond.test.js            # Comprehensive tests
```

## 🚀 Quick Start

### Installation

```bash
npm install
```

### Compile Contracts

```bash
npm run compile
```

### Run Tests

```bash
npm test
```

### Deploy Locally

```bash
# Start a local node
npm run node

# In another terminal, deploy
npm run deploy:local
```

## 🔧 Core Concepts

### 1. Diamond Storage (LibDiamond.sol)

The diamond uses a special storage pattern to avoid collisions:

```solidity
bytes32 constant DIAMOND_STORAGE_POSITION = 
    keccak256("diamond.standard.diamond.storage");

function diamondStorage() internal pure returns (DiamondStorage storage ds) {
    bytes32 position = DIAMOND_STORAGE_POSITION;
    assembly {
        ds.slot := position
    }
}
```

### 2. Function Selector Mapping

Each function selector is mapped to its facet address:

```solidity
struct DiamondStorage {
    mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;
    mapping(address => FacetFunctionSelectors) facetFunctionSelectors;
    address[] facetAddresses;
    address contractOwner;
}
```

### 3. Fallback Delegation

The Diamond's fallback function routes calls:

```solidity
fallback() external payable {
    address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;
    
    assembly {
        calldatacopy(0, 0, calldatasize())
        let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
        returndatacopy(0, 0, returndatasize())
        
        switch result
        case 0 { revert(0, returndatasize()) }
        default { return(0, returndatasize()) }
    }
}
```

### 4. DiamondCut Operations

Three operations for modifying the diamond:

```solidity
enum FacetCutAction { Add, Replace, Remove }

struct FacetCut {
    address facetAddress;
    FacetCutAction action;
    bytes4[] functionSelectors;
}
```

## 📝 Usage Examples

### Calling Diamond Functions

```javascript
// Get facet interfaces attached to diamond
const counter = await ethers.getContractAt("CounterFacet", diamondAddress);
const erc20 = await ethers.getContractAt("ERC20Facet", diamondAddress);

// Call counter functions
await counter.increment();
const value = await counter.getCounter();

// Call ERC20 functions
await erc20.transfer(recipient, amount);
```

### Adding a New Facet

```javascript
// Deploy new facet
const NewFacet = await ethers.getContractFactory("NewFacet");
const newFacet = await NewFacet.deploy();

// Get selectors
const selectors = getSelectors(newFacet);

// Execute diamond cut
const diamondCut = await ethers.getContractAt("DiamondCutFacet", diamondAddress);
await diamondCut.diamondCut(
    [{
        facetAddress: await newFacet.getAddress(),
        action: 0, // Add
        functionSelectors: selectors
    }],
    ethers.ZeroAddress,
    "0x"
);
```

### Upgrading a Facet

```javascript
// Deploy updated facet
const UpdatedFacet = await ethers.getContractFactory("UpdatedCounterFacet");
const updatedFacet = await UpdatedFacet.deploy();

// Replace functions
await diamondCut.diamondCut(
    [{
        facetAddress: await updatedFacet.getAddress(),
        action: 1, // Replace
        functionSelectors: getSelectors(updatedFacet)
    }],
    ethers.ZeroAddress,
    "0x"
);
```

### Removing Functions

```javascript
await diamondCut.diamondCut(
    [{
        facetAddress: ethers.ZeroAddress, // Must be zero for Remove
        action: 2, // Remove
        functionSelectors: selectorsToRemove
    }],
    ethers.ZeroAddress,
    "0x"
);
```

### Querying the Diamond (Loupe)

```javascript
const loupe = await ethers.getContractAt("DiamondLoupeFacet", diamondAddress);

// Get all facets
const facets = await loupe.facets();

// Get facet for a specific function
const facetAddress = await loupe.facetAddress(selector);

// Get all functions for a facet
const selectors = await loupe.facetFunctionSelectors(facetAddress);
```

## 🛡️ Best Practices

### Storage Safety

1. **Never remove or reorder storage variables** - only append
2. **Use unique storage positions** for each storage struct
3. **Document storage layouts** clearly

### Security

1. **Protect DiamondCut** - only owner should modify
2. **Consider timelocks** for production upgrades
3. **Verify facet code** before adding
4. **Test thoroughly** - bugs affect all facets

### Code Organization

1. **One facet per logical feature**
2. **Keep facets focused** and small
3. **Share common logic** through libraries
4. **Use events** for transparency

### Gas Optimization

1. **Batch related functions** in same facet
2. **Minimize storage reads** across facets
3. **Use appropriate data types**

## 🔍 DiamondLoupe Functions

Required by EIP-2535 for introspection:

| Function | Description |
|----------|-------------|
| `facets()` | Returns all facets and their selectors |
| `facetFunctionSelectors(address)` | Returns selectors for a facet |
| `facetAddresses()` | Returns all facet addresses |
| `facetAddress(bytes4)` | Returns facet for a selector |

## 📚 Resources

- [EIP-2535: Diamonds, Multi-Facet Proxy](https://eips.ethereum.org/EIPS/eip-2535)
- [Diamond Reference Implementation](https://github.com/mudgen/diamond-3-hardhat)
- [CertiK: Diamond Proxy Best Practices](https://www.certik.com/resources/blog/diamond-proxy-contracts-best-practices)
- [RareSkills: Diamond Proxy Guide](https://rareskills.io/post/diamond-proxy)

## 📄 License

MIT
