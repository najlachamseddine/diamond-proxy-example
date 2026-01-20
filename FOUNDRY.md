# Foundry Guide for Diamond Proxy

This guide covers using Foundry for deploying, testing, and upgrading the Diamond proxy pattern.

## Prerequisites

Install Foundry:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

## Project Setup

The project supports both Hardhat (JavaScript) and Foundry (Solidity):

```
script/              # Foundry deployment scripts
├── Deploy.s.sol    # Main deployment script
└── Upgrade.s.sol   # Upgrade examples

test/
├── Diamond.test.js # Hardhat tests (JavaScript)
└── Diamond.t.sol   # Foundry tests (Solidity)
```

## Building

```bash
forge build
```

## Testing

### Run all tests
```bash
forge test
```

### Run with verbosity
```bash
forge test -vv     # Show test execution
forge test -vvv    # Show execution traces
forge test -vvvv   # Show execution + setup traces
forge test -vvvvv  # Show internal calls
```

### Run specific test
```bash
forge test --match-test test_Increment
forge test --match-contract DiamondTest
```

### Gas report
```bash
forge test --gas-report
```

### Coverage
```bash
forge coverage
```

## Deployment

### Local Deployment (Anvil)

1. Start Anvil (local testnet):
```bash
anvil
```

2. Deploy in another terminal:
```bash
# Use Anvil's default private key
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

forge script script/Deploy.s.sol:DiamondDeployScript \
  --rpc-url http://localhost:8545 \
  --broadcast \
  -vvvv
```

### Testnet Deployment (Sepolia)

1. Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your keys:
# PRIVATE_KEY=your_private_key_without_0x
# SEPOLIA_RPC_URL=https://ethereum-sepolia.publicnode.com
# Note: Blockscout doesn't require an API key
```

2. Deploy:
```bash
source .env

forge script script/Deploy.s.sol:DiamondDeployScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv
```

### Mainnet Deployment

```bash
forge script script/Deploy.s.sol:DiamondDeployScript \
  --rpc-url $MAINNET_RPC_URL \
  --broadcast \
  --verify \
  --gas-price 30gwei \
  --priority-gas-price 2gwei
```

## Upgrading the Diamond

The `Upgrade.s.sol` script demonstrates three types of Diamond upgrades. You can enable different upgrade examples by commenting/uncommenting the function calls in the `run()` function.

### Deployment Command

First, deploy your Diamond:

```bash
source .env

# Deploy to local testnet (Anvil)
forge script script/Deploy.s.sol:DiamondDeployScript \
  --rpc-url http://localhost:8545 \
  --broadcast

# Deploy to Sepolia testnet
forge script script/Deploy.s.sol:DiamondDeployScript \
  --rpc-url sepolia \
  --broadcast \
  --verify
```

Save the deployed Diamond address for upgrades.

### Upgrade Example 1: Replace Facet Functions (`upgradeCounterFacet`)

**What it does:** Deploys a new version of CounterFacet and replaces existing function implementations. This is useful when you want to fix bugs or improve existing functionality while preserving the Diamond's state.

**How it works:**
- Deploys a new CounterFacet contract with updated code
- Uses `FacetCutAction.Replace` to swap out the old implementations
- All existing function selectors now point to the new facet address
- Diamond storage (like the counter value) is preserved

**Command:**

```bash
source .env
export DIAMOND_ADDRESS=0x59624aF30be972C6dbd57Cd89000336a289F7684

# Edit script/Upgrade.s.sol to enable upgradeCounterFacet():
# Uncomment: upgradeCounterFacet();
# Comment out: addNewFacet(); and removeFunctions();

# Run the upgrade
forge script script/Upgrade.s.sol:DiamondUpgradeScript \
  --rpc-url sepolia \
  --broadcast

# Verify the upgrade worked
cast call $DIAMOND_ADDRESS "counterFacetNewFunction()(string)" --rpc-url sepolia
cast call $DIAMOND_ADDRESS "getCounter()(uint256)" --rpc-url sepolia
```

**Use cases:**
- Bug fixes in existing functions
- Performance improvements
- Logic updates while maintaining the same interface
- Changing return messages or event data

### Upgrade Example 2: Add New Facet (`addNewFacet`)

**What it does:** Deploys a completely new facet (Counter2Facet) and adds new functions to the Diamond. Existing functions are not affected.

**How it works:**
- Deploys Counter2Facet with new functions
- Uses `FacetCutAction.Add` to register new function selectors
- New functions become callable through the Diamond
- Existing facets remain unchanged

**Command:**

```bash
source .env
export DIAMOND_ADDRESS=0x59624aF30be972C6dbd57Cd89000336a289F7684

# Edit script/Upgrade.s.sol to enable addNewFacet():
# Comment out: upgradeCounterFacet(); and removeFunctions();
# Uncomment: addNewFacet();

# Run the upgrade
forge script script/Upgrade.s.sol:DiamondUpgradeScript \
  --rpc-url sepolia \
  --broadcast

# Verify the new function was added
cast call $DIAMOND_ADDRESS "counterFacetNewFunction2()(string)" --rpc-url sepolia

# Check all facets
cast call $DIAMOND_ADDRESS "facets()(tuple(address,bytes4[])[])" --rpc-url sepolia
```

**Use cases:**
- Adding new features to your protocol
- Extending functionality without touching existing code
- Modular architecture (e.g., adding governance, staking, rewards)
- Breaking past the 24KB contract size limit

### Upgrade Example 3: Remove Functions (`removeFunctions`)

**What it does:** Removes specific functions from the Diamond, making them no longer callable. Useful for deprecating features or removing vulnerable code.

**How it works:**
- Uses `FacetCutAction.Remove` with function selectors
- Facet address must be `address(0)` for remove operations
- Function selectors are deleted from the Diamond's mapping
- Calling removed functions will revert

**Command:**

```bash
source .env
export DIAMOND_ADDRESS=0x59624aF30be972C6dbd57Cd89000336a289F7684

# Edit script/Upgrade.s.sol to enable removeFunctions():
# Comment out: upgradeCounterFacet(); and addNewFacet();
# Uncomment: removeFunctions();

# Run the upgrade (removes resetCounter function)
forge script script/Upgrade.s.sol:DiamondUpgradeScript \
  --rpc-url sepolia \
  --broadcast

# Verify function is removed (should fail)
cast call $DIAMOND_ADDRESS "resetCounter()" --rpc-url sepolia
# Expected: Error - function selector not found

# Check remaining functions
cast call $DIAMOND_ADDRESS "facetFunctionSelectors(address)(bytes4[])" \
  0x1044BFbd1d954a4E0998AAb6dCfEE9a9c077170F \
  --rpc-url sepolia
```

**Use cases:**
- Deprecating old features
- Removing vulnerable functions quickly
- Cleaning up unused code
- Emergency response to security issues

### Upgrade with Initialization

For complex upgrades that require state initialization:

```bash
forge script script/Upgrade.s.sol:UpgradeWithInitScript \
  --rpc-url localhost \
  --broadcast
```

This runs custom initialization logic during the `diamondCut` call.

### Complete Upgrade Workflow

```bash
# 1. Deploy Diamond
source .env
forge script script/Deploy.s.sol:DiamondDeployScript --rpc-url sepolia --broadcast

# 2. Save the Diamond address
export DIAMOND_ADDRESS=0x... # from deployment output

# 3. Interact with it
cast call $DIAMOND_ADDRESS "getCounter()(uint256)" --rpc-url sepolia
cast send $DIAMOND_ADDRESS "increment()" --rpc-url sepolia --private-key $PRIVATE_KEY

# 4. Upgrade (choose your upgrade type in Upgrade.s.sol)
forge script script/Upgrade.s.sol:DiamondUpgradeScript --rpc-url sepolia --broadcast

# 5. Verify upgrade
cast call $DIAMOND_ADDRESS "facets()(tuple(address,bytes4[])[])" --rpc-url sepolia
cast call $DIAMOND_ADDRESS "counterFacetNewFunction()(string)" --rpc-url sepolia
```

## Verification

### Verify on Blockscout (Sepolia)

During deployment:
```bash
forge script script/Deploy.s.sol:DiamondDeployScript \
  --rpc-url sepolia \
  --broadcast \
  --verify
```

After deployment (manual verification):
```bash
forge verify-contract \
  --chain-id 11155111 \
  --compiler-version 0.8.20 \
  --verifier blockscout \
  --verifier-url https://eth-sepolia.blockscout.com/api \
  ADDRESS \
  contracts/Diamond.sol:Diamond
```

### Verify on Etherscan (Alternative)

If you prefer Etherscan, update `foundry.toml`:
```toml
[etherscan]
sepolia = { key = "${ETHERSCAN_API_KEY}" }
```

Then verify:
```bash
forge verify-contract \
  --chain-id 11155111 \
  --compiler-version 0.8.20 \
  ADDRESS \
  contracts/Diamond.sol:Diamond
```

## Useful Foundry Commands

### Inspect contract
```bash
forge inspect Diamond abi
forge inspect Diamond storageLayout
forge inspect Diamond methods
```

### Get function selectors
```bash
cast sig "increment()"
cast sig "getCounter()"
```

### Interact with deployed diamond
```bash
# Call view function
cast call $DIAMOND_ADDRESS "getCounter()(uint256)" --rpc-url localhost

# Send transaction
cast send $DIAMOND_ADDRESS "increment()" \
  --private-key $PRIVATE_KEY \
  --rpc-url localhost

# Query facets
cast call $DIAMOND_ADDRESS "facets()(tuple(address,bytes4[])[])" \
  --rpc-url localhost
```

### Debug transaction
```bash
cast run TX_HASH --rpc-url localhost --debug
```

### Estimate gas
```bash
cast estimate $DIAMOND_ADDRESS "increment()" \
  --from $YOUR_ADDRESS \
  --rpc-url localhost
```

## Script Customization

### Adding a New Facet

Edit `script/Deploy.s.sol`:

```solidity
// Deploy new facet
NewFacet newFacet = new NewFacet();

// Add to cuts array
cuts[5] = IDiamondCut.FacetCut({
    facetAddress: address(newFacet),
    action: IDiamondCut.FacetCutAction.Add,
    functionSelectors: getSelectorsForNewFacet()
});

// Add selector helper
function getSelectorsForNewFacet() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](2);
    selectors[0] = NewFacet.func1.selector;
    selectors[1] = NewFacet.func2.selector;
    return selectors;
}
```

## Troubleshooting

### Error: "PRIVATE_KEY not set"
```bash
export PRIVATE_KEY=0x...
# Or source your .env file
source .env
```

### Error: "DIAMOND_ADDRESS not set"
```bash
export DIAMOND_ADDRESS=0x...
```

### Compilation issues
```bash
forge clean
forge build
```

### RPC issues
Check your RPC URL is correct and accessible:
```bash
cast block latest --rpc-url $SEPOLIA_RPC_URL
```

## Best Practices

1. **Always test locally first** with Anvil before deploying to testnet
2. **Use `--verify`** flag to automatically verify contracts on Etherscan
3. **Set gas price** explicitly for mainnet: `--gas-price 30gwei`
4. **Keep private keys secure** - never commit them to git
5. **Use hardware wallets** for mainnet via `--ledger` or `--trezor`
6. **Simulate before broadcasting**: Remove `--broadcast` flag first
7. **Test upgrades** thoroughly on testnet before mainnet

## Advanced: Cast Integration

### Monitor diamond state
```bash
# Watch counter changes
watch -n 2 "cast call $DIAMOND_ADDRESS 'getCounter()(uint256)' --rpc-url localhost"

# Get ERC20 balance
cast call $DIAMOND_ADDRESS "balanceOf(address)(uint256)" $ADDRESS --rpc-url localhost

# Get owner
cast call $DIAMOND_ADDRESS "owner()(address)" --rpc-url localhost
```

### Batch operations
```bash
# Create a batch upgrade
cast calldata "diamondCut((address,uint8,bytes4[])[],address,bytes)" \
  "[($FACET_ADDRESS,1,[$SELECTOR1,$SELECTOR2])]" \
  "0x0000000000000000000000000000000000000000" \
  "0x"
```

## Resources

- [Foundry Book](https://book.getfoundry.sh/)
- [Cast Reference](https://book.getfoundry.sh/reference/cast/)
- [Forge Reference](https://book.getfoundry.sh/reference/forge/)
