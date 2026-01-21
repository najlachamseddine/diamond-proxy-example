# Diamond Proxy Auto-Upgrade Tool

Automate Diamond proxy upgrades by intelligently detecting which functions need to be Added, Replaced, or Removed.

## Features

✅ **Automatic Detection**: Analyzes your modified facet contract and determines upgrade actions
✅ **Smart Comparison**: Compares new contract with Diamond's current state
✅ **Script Generation**: Creates separate Solidity scripts for Add/Replace/Remove operations
✅ **Safe Execution**: Optionally auto-execute or review scripts before running
✅ **Network Support**: Works with local, testnet, and mainnet deployments

## How It Works

1. **Scans the modified facet contract** - Extracts all function signatures and selectors
2. **Queries the Diamond** - Gets currently registered selectors for that facet
3. **Determines actions** - Compares and categorizes functions:
   - **Add**: Function exists in new contract but not in Diamond
   - **Replace**: Function exists in both (implementation changed)
   - **Remove**: Function exists in Diamond but not in new contract
4. **Generates scripts** - Creates `AddFacet.s.sol`, `ReplaceFacet.s.sol`, `RemoveFacet.s.sol`
5. **Executes** - Optionally runs the upgrade scripts automatically

## Installation

### Prerequisites

- Python 3.7+
- Foundry (forge, cast)
- A deployed Diamond contract

### Setup

```bash
# No additional dependencies needed - uses standard library
cd scripts/
chmod +x auto_upgrade.py
```

## Usage

### Basic Usage (Generate Scripts Only)

```bash
# Analyze CounterFacet and generate upgrade scripts
python scripts/auto_upgrade.py \
  --facet CounterFacet \
  --diamond 0x59624aF30be972C6dbd57Cd89000336a289F7684 \
  --network sepolia
```

**Output:**
- Analyzes the contract
- Shows what will be Added/Replaced/Removed
- Generates `script/AddFacet.s.sol`, `script/ReplaceFacet.s.sol`, `script/RemoveFacet.s.sol`
- Displays commands to execute manually

### Auto-Execute Mode

```bash
# Analyze and automatically execute upgrades
source .env
python scripts/auto_upgrade.py \
  --facet CounterFacet \
  --diamond 0x59624aF30be972C6dbd57Cd89000336a289F7684 \
  --network sepolia \
  --execute
```

### Custom RPC URL

```bash
python scripts/auto_upgrade.py \
  --facet ERC20Facet \
  --diamond 0x59624aF30be972C6dbd57Cd89000336a289F7684 \
  --network https://my-custom-rpc.com \
  --execute
```

### Local Development

```bash
# Start Anvil
anvil

# In another terminal
python scripts/auto_upgrade.py \
  --facet CounterFacet \
  --diamond 0x5FbDB2315678afecb367f032d93F642f64180aa3 \
  --network localhost \
  --execute
```

## Command-Line Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `--facet` | Yes | Facet contract name (e.g., `CounterFacet`) |
| `--diamond` | Yes | Diamond proxy contract address |
| `--network` | No | Network name (`localhost`, `sepolia`, `mainnet`) or custom RPC URL (default: `sepolia`) |
| `--execute` | No | Auto-execute upgrades instead of just generating scripts |
| `--private-key` | No | Private key (or set `PRIVATE_KEY` environment variable) |

## Example Workflow

### Scenario: You modified CounterFacet

1. **Changed** the message in `counterFacetNewFunction()`
2. **Added** a new function `multiplyCounter(uint256)`
3. **Removed** the function `resetCounter()`

### Run the tool:

```bash
python scripts/auto_upgrade.py \
  --facet CounterFacet \
  --diamond 0x59624aF30be972C6dbd57Cd89000336a289F7684 \
  --network sepolia
```

### Output:

```
📝 Analyzing CounterFacet contract...
   Found 6 functions in CounterFacet:
   - getCounter() → 0x8ada066e
   - increment() → 0xd09de08a
   - decrement() → 0x2baeceb7
   - incrementBy(uint256) → 0x03df179c
   - multiplyCounter(uint256) → 0x9f2a1234
   - counterFacetNewFunction() → 0x796446af

🔍 Querying Diamond at 0x59624aF30be972C6dbd57Cd89000336a289F7684...
   Found 5 selectors in Diamond

🔄 Determining upgrade actions...

📊 Upgrade Summary:
   ✅ Add:     1 functions
      - multiplyCounter(uint256)
   🔄 Replace: 5 functions
      - getCounter()
      - increment()
      - decrement()
      - incrementBy(uint256)
      - counterFacetNewFunction()
   ❌ Remove:  1 functions
      - 0xdbdf7fce

📝 Generating upgrade scripts...
   🔄 Generated script/ReplaceFacet.s.sol
   ✅ Generated script/AddFacet.s.sol
   ❌ Generated script/RemoveFacet.s.sol

🚀 Executing upgrades...

📋 To execute upgrades, run the following commands:

   # Replace functions
   DIAMOND_ADDRESS=0x59624aF30be972C6dbd57Cd89000336a289F7684 forge script script/ReplaceFacet.s.sol:ReplaceFacetScript \
     --rpc-url sepolia --broadcast

   # Add functions
   DIAMOND_ADDRESS=0x59624aF30be972C6dbd57Cd89000336a289F7684 forge script script/AddFacet.s.sol:AddFacetScript \
     --rpc-url sepolia --broadcast

   # Remove functions
   DIAMOND_ADDRESS=0x59624aF30be972C6dbd57Cd89000336a289F7684 forge script script/RemoveFacet.s.sol:RemoveFacetScript \
     --rpc-url sepolia --broadcast

✨ Upgrade analysis complete!
```

### Execute the upgrades:

```bash
# Option 1: Run commands manually (copy from output)
DIAMOND_ADDRESS=0x5962... forge script script/ReplaceFacet.s.sol:ReplaceFacetScript --rpc-url sepolia --broadcast

# Option 2: Use --execute flag to run automatically
python scripts/auto_upgrade.py --facet CounterFacet --diamond 0x5962... --network sepolia --execute
```

### Verify:

```bash
# Check new function was added
cast call 0x59624aF30be972C6dbd57Cd89000336a289F7684 "multiplyCounter(uint256)" 5 --rpc-url sepolia

# Check replaced function has new behavior
cast call 0x59624aF30be972C6dbd57Cd89000336a289F7684 "counterFacetNewFunction()(string)" --rpc-url sepolia

# Verify removed function fails
cast call 0x59624aF30be972C6dbd57Cd89000336a289F7684 "resetCounter()" --rpc-url sepolia
# Should fail: function selector not found
```

## Generated Scripts

The tool generates three Solidity scripts in the `script/` directory:

### 1. `AddFacet.s.sol`
- Deploys new facet
- Adds new function selectors to Diamond
- Uses `FacetCutAction.Add`

### 2. `ReplaceFacet.s.sol`
- Deploys updated facet
- Replaces existing function implementations
- Uses `FacetCutAction.Replace`

### 3. `RemoveFacet.s.sol`
- Removes deprecated function selectors
- Uses `FacetCutAction.Remove`
- Facet address is `address(0)`

Each script is:
- ✅ **Self-documenting** - Lists all functions being modified
- ✅ **Ready to execute** - Can run immediately with `forge script`
- ✅ **Auditable** - Clear what will happen before execution

## Environment Variables

```bash
# Required
PRIVATE_KEY=your_private_key_without_0x_prefix

# Optional (if not using default)
SEPOLIA_RPC_URL=https://ethereum-sepolia.publicnode.com
MAINNET_RPC_URL=https://eth.llamarpc.com
```

## Safety Features

1. **Review Before Execute**: By default, only generates scripts for manual review
2. **Clear Output**: Shows exactly what will be Added/Replaced/Removed
3. **Selective Execution**: Scripts can be run independently
4. **State Preservation**: Diamond storage is maintained through upgrades

## Troubleshooting

### Error: "PRIVATE_KEY not set"
```bash
# Set in environment
export PRIVATE_KEY=0xabc...

# Or in .env file
echo "PRIVATE_KEY=abc..." >> .env
source .env
```

### Error: "DIAMOND_ADDRESS not set"
Make sure you're passing `--diamond` argument:
```bash
python scripts/auto_upgrade.py --facet CounterFacet --diamond 0x... --network sepolia
```

### Error: "forge: command not found"
Install Foundry:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Error parsing selectors
The Diamond might not have the facet deployed yet. This is normal for first-time deployments - all functions will be marked as "Add".

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Diamond Upgrade
on:
  push:
    paths:
      - 'contracts/facets/**'

jobs:
  upgrade:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install Foundry
        uses: foundry-rs/foundry-toolchain@v1
      
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.9'
      
      - name: Analyze Upgrades
        run: |
          python scripts/auto_upgrade.py \
            --facet CounterFacet \
            --diamond ${{ secrets.DIAMOND_ADDRESS }} \
            --network sepolia
      
      - name: Upload Scripts
        uses: actions/upload-artifact@v3
        with:
          name: upgrade-scripts
          path: script/*Facet.s.sol
```

## Advanced Usage

### Multiple Facets

```bash
# Upgrade multiple facets sequentially
for facet in CounterFacet ERC20Facet OwnershipFacet; do
  python scripts/auto_upgrade.py \
    --facet $facet \
    --diamond 0x5962... \
    --network sepolia \
    --execute
done
```

### Dry Run on Mainnet

```bash
# Generate scripts for mainnet without executing
python scripts/auto_upgrade.py \
  --facet CounterFacet \
  --diamond 0x... \
  --network mainnet

# Review generated scripts, then execute manually with higher gas
DIAMOND_ADDRESS=0x... forge script script/ReplaceFacet.s.sol:ReplaceFacetScript \
  --rpc-url mainnet \
  --broadcast \
  --gas-price 50gwei
```

## Best Practices

1. **Always test locally first** using Anvil
2. **Review generated scripts** before executing on testnet/mainnet
3. **Use `--execute` only after** verifying the analysis output
4. **Keep facets focused** - upgrade one facet at a time
5. **Document changes** in your facet contracts
6. **Verify after upgrade** using cast commands

## License

MIT
