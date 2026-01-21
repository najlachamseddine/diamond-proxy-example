# Diamond Proxy Pattern Example (EIP-2535)

A comprehensive implementation of the Diamond Proxy Pattern following EIP-2535 best practices.

**Supports both Hardhat (JavaScript) and Foundry (Solidity) workflows.**

📖 **Documentation:**
- **[Foundry Complete Guide →](./FOUNDRY.md)**
- **[Architecture Diagrams →](./ARCHITECTURE.md)**
- **[Quick Reference →](./QUICKREF.md)**
- **[Summary →](./SUMMARY.md)**

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

#### Using Hardhat (JavaScript/TypeScript)
```bash
npm install
```

#### Using Foundry (Solidity)
```bash
# Install Foundry if you haven't already
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install dependencies
forge install foundry-rs/forge-std
```

### Compile Contracts

#### Hardhat
```bash
npm run compile
```

#### Foundry
```bash
forge build
```

### Run Tests

#### Hardhat
```bash
npm test
```

#### Foundry
```bash
forge test
# Run with verbosity
forge test -vv
# Run with gas report
forge test --gas-report
```

### Deploy

#### Hardhat - Deploy Locally
```bash
# Start a local node
npm run node

# In another terminal, deploy
npm run deploy:local
```

#### Foundry - Deploy Locally
```bash
# Start a local Anvil node
anvil

# In another terminal, set private key and deploy
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
forge script script/Deploy.s.sol:DiamondDeployScript --rpc-url localhost --broadcast
```

#### Foundry - Deploy to Testnet
```bash
# Create .env file from example
cp .env.example .env
# Edit .env with your keys

# Source environment variables
source .env

# Deploy to Sepolia
forge script script/Deploy.s.sol:DiamondDeployScript --rpc-url sepolia --broadcast --verify

# Deploy with custom gas settings
forge script script/Deploy.s.sol:DiamondDeployScript --rpc-url sepolia --broadcast --verify --gas-price 20gwei
```

### Upgrade Diamond

#### Foundry
```bash
# Set the diamond address
export DIAMOND_ADDRESS=0x...
export PRIVATE_KEY=0x...

# Run upgrade script
forge script script/Upgrade.s.sol:DiamondUpgradeScript --rpc-url localhost --broadcast

# Or for testnet
forge script script/Upgrade.s.sol:DiamondUpgradeScript --rpc-url sepolia --broadcast
```

#### Hardhat
```bash
DIAMOND_ADDRESS=0x... npx hardhat run scripts/upgrade.js --network localhost
```

## 🔄 Hardhat vs Foundry

| Feature | Hardhat | Foundry |
|---------|---------|---------|
| **Language** | JavaScript/TypeScript | Solidity |
| **Test Speed** | ~500ms | ~2ms (250x faster) |
| **Gas Reports** | ✅ Via plugins | ✅ Built-in |
| **Fuzzing** | ❌ External tools | ✅ Native |
| **Learning Curve** | Easy for JS devs | Easy for Solidity devs |
| **Ecosystem** | Mature, large | Growing rapidly |
| **Deployment** | scripts/ folder | script/ folder |
| **Best For** | Full-stack devs | Smart contract devs |

**Recommendation**: Use Foundry for testing (faster), either for deployment.

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

#### Using Foundry (cast)

```bash
# Set your diamond address
DIAMOND=0x59624aF30be972C6dbd57Cd89000336a289F7684

# Read the counter value
cast call $DIAMOND "getCounter()(uint256)" --rpc-url sepolia

# Increment counter (requires sending transaction)
cast send $DIAMOND "increment()" --rpc-url sepolia --private-key $PRIVATE_KEY

# Increment by specific amount
cast send $DIAMOND "incrementBy(uint256)" 10 --rpc-url sepolia --private-key $PRIVATE_KEY

# Decrement counter
cast send $DIAMOND "decrement()" --rpc-url sepolia --private-key $PRIVATE_KEY

# Call function that returns string
cast call $DIAMOND "counterFacetNewFunction()(string)" --rpc-url sepolia

# Query which facet handles a function
cast call $DIAMOND "facetAddress(bytes4)(address)" $(cast sig "getCounter()") --rpc-url sepolia

# List all facets and their function selectors
cast call $DIAMOND "facets()(tuple(address,bytes4[])[])" --rpc-url sepolia

# Call function directly on facet (not through diamond)
FACET=0xd12347c1FB663275C18c4Db387e58aBF017CeF73
cast call $FACET "counterFacetNewFunction2()(string)" --rpc-url sepolia
```

#### Using Hardhat (JavaScript)

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

#### Using Foundry

```bash
# Deploy and upgrade using the Upgrade script
source .env
DIAMOND_ADDRESS=0x59624aF30be972C6dbd57Cd89000336a289F7684

# Run the upgrade script (adds Counter2Facet with new function)
forge script script/Upgrade.s.sol:DiamondUpgradeScript --rpc-url sepolia --broadcast

# Verify the new function was added
cast call $DIAMOND_ADDRESS "counterFacetNewFunction2()(string)" --rpc-url sepolia
```

#### Using Hardhat

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

#### Using Foundry

```bash
# Use the upgradeCounterFacet() function in Upgrade.s.sol
# This replaces existing CounterFacet functions with new implementation

# Edit script/Upgrade.s.sol to enable upgradeCounterFacet():
# Uncomment: upgradeCounterFacet();
# Comment out: addNewFacet();

# Run the upgrade
source .env
DIAMOND_ADDRESS=0x59624aF30be972C6dbd57Cd89000336a289F7684
forge script script/Upgrade.s.sol:DiamondUpgradeScript --rpc-url sepolia --broadcast

# Verify state is preserved after upgrade
cast call $DIAMOND_ADDRESS "getCounter()(uint256)" --rpc-url sepolia
```

#### Using Hardhat

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

#### Using Foundry

```bash
# Use the removeFunctions() function in Upgrade.s.sol
# Edit script/Upgrade.s.sol to enable removeFunctions():
# Uncomment: removeFunctions();

# This will remove the resetCounter function from the diamond
forge script script/Upgrade.s.sol:DiamondUpgradeScript --rpc-url sepolia --broadcast

# Verify function is removed (should fail)
cast call $DIAMOND_ADDRESS "resetCounter()" --rpc-url sepolia
```

#### Using Hardhat

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

#### Using Foundry

```bash
DIAMOND=0x59624aF30be972C6dbd57Cd89000336a289F7684

# Get all facets and their function selectors
cast call $DIAMOND "facets()(tuple(address,bytes4[])[])" --rpc-url sepolia

# Get all facet addresses
cast call $DIAMOND "facetAddresses()(address[])" --rpc-url sepolia

# Get which facet handles a specific function
cast call $DIAMOND "facetAddress(bytes4)(address)" $(cast sig "getCounter()") --rpc-url sepolia

# Get all function selectors for a specific facet
FACET_ADDR=0x1044BFbd1d954a4E0998AAb6dCfEE9a9c077170F
cast call $DIAMOND "facetFunctionSelectors(address)(bytes4[])" $FACET_ADDR --rpc-url sepolia

# Get function signature from selector
cast sig "counterFacetNewFunction()"
# Output: 0x12345678... (the bytes4 selector)
```

#### Using Hardhat

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
