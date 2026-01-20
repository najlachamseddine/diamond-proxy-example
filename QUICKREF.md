# Diamond Proxy - Quick Reference

## Foundry Commands

### Setup
```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install dependencies
forge install foundry-rs/forge-std --no-git
```

### Build & Test
```bash
forge build                    # Compile contracts
forge test                     # Run tests
forge test -vv                 # Verbose output
forge test --gas-report        # Show gas usage
forge coverage                 # Code coverage
```

### Deploy Local
```bash
# Terminal 1: Start Anvil
anvil

# Terminal 2: Deploy
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
forge script script/Deploy.s.sol:DiamondDeployScript --rpc-url localhost --broadcast
```

### Deploy Testnet
```bash
source .env
forge script script/Deploy.s.sol:DiamondDeployScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify

# Or with manual verification
forge script script/Deploy.s.sol:DiamondDeployScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast

# Then verify on Blockscout
forge verify-contract \
  --chain-id 11155111 \
  --verifier blockscout \
  --verifier-url https://eth-sepolia.blockscout.com/api \
  DIAMOND_ADDRESS \
  contracts/Diamond.sol:Diamond
```

### Upgrade
```bash
export DIAMOND_ADDRESS=0x...
forge script script/Upgrade.s.sol:DiamondUpgradeScript \
  --rpc-url localhost \
  --broadcast
```

### Interact with Cast
```bash
# View functions
cast call $DIAMOND_ADDRESS "getCounter()(uint256)" --rpc-url localhost
cast call $DIAMOND_ADDRESS "owner()(address)" --rpc-url localhost

# Transactions
cast send $DIAMOND_ADDRESS "increment()" --private-key $PRIVATE_KEY --rpc-url localhost

# Get function selector
cast sig "increment()"
```

## Hardhat Commands

### Setup
```bash
npm install
```

### Build & Test
```bash
npm run compile               # Compile contracts
npm test                      # Run tests
```

### Deploy Local
```bash
# Terminal 1: Start node
npm run node

# Terminal 2: Deploy
npm run deploy:local
```

### Deploy Testnet
```bash
npm run deploy:sepolia
```

## Key File Locations

```
contracts/
├── Diamond.sol                    # Main proxy
├── libraries/
│   ├── LibDiamond.sol            # Core diamond logic
│   └── LibAppStorage.sol         # Shared storage
└── facets/
    ├── DiamondCutFacet.sol       # Add/replace/remove
    ├── DiamondLoupeFacet.sol     # Introspection
    ├── OwnershipFacet.sol        # Owner management
    ├── CounterFacet.sol          # Example feature
    └── ERC20Facet.sol            # Token example

script/
├── Deploy.s.sol                  # Foundry deploy
└── Upgrade.s.sol                 # Foundry upgrade

test/
├── Diamond.test.js               # Hardhat tests
└── Diamond.t.sol                 # Foundry tests
```

## Common Function Selectors

```
DiamondCut:
  diamondCut((address,uint8,bytes4[])[],address,bytes) → 0x1f931c1c

DiamondLoupe:
  facets() → 0x7a0ed627
  facetAddresses() → 0x52ef6b2c
  facetAddress(bytes4) → 0xcdffacc6

Ownership:
  owner() → 0x8da5cb5b
  transferOwnership(address) → 0xf2fde38b

Counter:
  getCounter() → 0x8ada066e
  increment() → 0xd09de08a
  decrement() → 0x2baeceb7
```

## Environment Variables

```bash
# .env file
PRIVATE_KEY=your_private_key
SEPOLIA_RPC_URL=https://ethereum-sepolia.publicnode.com
DIAMOND_ADDRESS=0x...
# Note: Blockscout verification doesn't require an API key
```

## Troubleshooting

### Foundry
```bash
forge clean && forge build       # Fix compilation
cast block latest --rpc-url $URL # Test RPC
forge test --match-test NAME -vvvv # Debug test
```

### Hardhat
```bash
npx hardhat clean && npx hardhat compile
npx hardhat node --verbose
npx hardhat test --verbose
```

## Quick Links

- [Full README](./README.md)
- [Foundry Guide](./FOUNDRY.md)
- [EIP-2535 Spec](https://eips.ethereum.org/EIPS/eip-2535)
