# Diamond Proxy Pattern Example (EIP-2535)

A comprehensive implementation of the Diamond Proxy Pattern following EIP-2535 best practices using **Foundry**.

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
    ├── Counter2Facet.sol      # Example: Extended counter
    └── ERC20Facet.sol         # Example: ERC20 token

script/                         # Foundry deployment & upgrade scripts
├── Deploy.s.sol               # Deploy Diamond with initial facets
├── Upgrade.s.sol              # Manual upgrade examples
├── AddFacet.s.sol             # Auto-generated: Add new functions
├── ReplaceFacet.s.sol         # Auto-generated: Replace existing functions
├── RemoveFacet.s.sol          # Auto-generated: Remove functions
└── InteractWithCounter.s.sol  # Example interaction script

scripts/                        # Automation tools
├── auto_upgrade.py            # Python automation tool for intelligent upgrades
├── README.md                  # Automation tool documentation
├── deploy.js                  # Legacy Hardhat deployment
└── upgrade.js                 # Legacy Hardhat upgrade

test/
└── Diamond.t.sol              # Foundry tests
```

## 🚀 Quick Start

### Installation

```bash
# Install Foundry if you haven't already
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install dependencies
forge install foundry-rs/forge-std
```

### Compile Contracts

```bash
forge build
```

### Run Tests

```bash
forge test
# Run with verbosity
forge test -vv
# Run with gas report
forge test --gas-report
```

### Deploy

#### Deploy Locally
```bash
# Start a local Anvil node
anvil

# In another terminal, set private key and deploy
export PRIVATE_KEY=0x...
forge script script/Deploy.s.sol:DiamondDeployScript --rpc-url localhost --broadcast
```

#### Deploy to Testnet
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

### Automated Upgrade Analysis

The project includes a Python automation tool that intelligently analyzes your contracts and generates upgrade scripts:

```bash
# Analyze a facet and generate upgrade scripts
python3 scripts/auto_upgrade.py --facet CounterFacet --diamond 0x59624aF30be972C6dbd57Cd89000336a289F7684 --network sepolia
```

**Example Output:**

```
📝 Analyzing CounterFacet contract...
   Compiling contracts...
   Reading artifact from out/CounterFacet.sol/CounterFacet.json
   Found 6 functions in CounterFacet:
   - counterFacetNewFunction() → 0x796446af
   - decrement() → 0x2baeceb7
   - getCounter() → 0x8ada066e
   - increment() → 0xd09de08a
   - incrementBy(uint256) → 0x03df179c
   - resetCounter() → 0xdbdf7fce

🔄 Determining upgrade actions...

🔍 Querying Diamond at 0x59624aF30be972C6dbd57Cd89000336a289F7684...
   Found 5 selectors in Diamond
   Selectors: 0x03df179c, 0x2baeceb7, 0x796446af, 0x8ada066e, 0xd09de08a

📊 Upgrade Summary:
   ✅ Add:     1 functions
      - 0xdbdf7fce resetCounter()
   🔄 Replace: 5 functions
      - 0x03df179c counterFacetNewFunction()
      - 0x2baeceb7 decrement()
      - 0x796446af getCounter()
      - 0x8ada066e increment()
      - 0xd09de08a incrementBy(uint256)
   ❌ Remove:  0 functions

📝 Generating upgrade scripts...
   ✅ Generated script/AddFacet.s.sol
   🔄 Generated script/ReplaceFacet.s.sol
   Generated scripts in script/ directory

🚀 Executing upgrades...

📋 To execute upgrades, run the following commands:

   # Replace functions
   DIAMOND_ADDRESS=0x59624aF30be972C6dbd57Cd89000336a289F7684 forge script script/ReplaceFacet.s.sol:ReplaceFacetScript \
     --rpc-url sepolia --broadcast

   # Add functions
   DIAMOND_ADDRESS=0x59624aF30be972C6dbd57Cd89000336a289F7684 forge script script/AddFacet.s.sol:AddFacetScript \
     --rpc-url sepolia --broadcast

✨ Upgrade analysis complete!
```

The tool automatically:
- ✅ Compiles your contracts and extracts function selectors
- ✅ Queries the Diamond to compare current vs. desired state
- ✅ Determines which functions need to be Added, Replaced, or Removed
- ✅ Generates ready-to-execute Foundry scripts (AddFacet.s.sol, ReplaceFacet.s.sol, RemoveFacet.s.sol)
- ✅ Displays function selectors in bytes4 format for verification

#### How It Works

1. **Analyze**: The Python script reads your facet contract's compiled ABI and extracts all function selectors
2. **Compare**: It queries the deployed Diamond to get currently registered selectors
3. **Generate**: Based on the comparison, it generates Foundry scripts:
   - `script/AddFacet.s.sol` - For functions that exist in your facet but not in the Diamond
   - `script/ReplaceFacet.s.sol` - For functions that exist in both (to update implementation)
   - `script/RemoveFacet.s.sol` - For functions in the Diamond that are no longer in your facet
4. **Execute**: You run the generated Foundry scripts to apply the upgrades

```bash
# Step 1: Analyze and generate upgrade scripts
python3 scripts/auto_upgrade.py --facet CounterFacet --diamond 0x... --network sepolia

# Step 2: Execute the generated scripts
DIAMOND_ADDRESS=0x... forge script script/AddFacet.s.sol:AddFacetScript --rpc-url sepolia --broadcast
DIAMOND_ADDRESS=0x... forge script script/ReplaceFacet.s.sol:ReplaceFacetScript --rpc-url sepolia --broadcast
```

You can also check for selector conflicts across all facets before deployment:
```bash
python3 scripts/auto_upgrade.py --check-conflicts
```

See [scripts/README.md](./scripts/README.md) for complete documentation.

### Querying the Diamond (Loupe)

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
