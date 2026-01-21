#!/usr/bin/env python3
"""
Diamond Proxy Auto-Upgrade Script

This script automates the upgrade process for Diamond proxy contracts by:
1. Analyzing a modified facet contract to extract function selectors
2. Querying the Diamond to get currently registered selectors for that facet
3. Determining which functions need to be Added, Replaced, or Removed
4. Generating and executing the appropriate diamondCut transactions

Usage:
    python scripts/auto_upgrade.py --facet CounterFacet --diamond 0x... --network sepolia
"""

import json
import subprocess
import sys
import argparse
from typing import List, Dict, Set, Tuple
from dataclasses import dataclass
import os

def load_env_file(env_path=".env"):
    """Load environment variables from .env file"""
    if os.path.exists(env_path):
        with open(env_path, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    # Remove quotes if present
                    value = value.strip('"').strip("'")
                    os.environ[key] = value

@dataclass
class FunctionInfo:
    """Represents a function with its selector and signature"""
    name: str
    signature: str
    selector: str

@dataclass
class UpgradeAction:
    """Represents an upgrade action (Add/Replace/Remove)"""
    action: str  # "Add", "Replace", or "Remove"
    selectors: List[str]
    signatures: List[str]

class DiamondUpgrader:
    def __init__(self, facet_name: str, diamond_address: str, network: str, private_key: str = None):
        self.facet_name = facet_name
        self.diamond_address = diamond_address
        self.network = network
        self.private_key = private_key or os.getenv("PRIVATE_KEY")
        self.rpc_url = self._get_rpc_url(network)
        
        if not self.private_key:
            raise ValueError("PRIVATE_KEY not set. Set it in .env or pass it as argument")
    
    def _get_rpc_url(self, network: str) -> str:
        """Get RPC URL for the network"""
        urls = {
            "localhost": "http://localhost:8545",
            "sepolia": os.getenv("SEPOLIA_RPC_URL", "https://ethereum-sepolia.publicnode.com"),
            "mainnet": os.getenv("MAINNET_RPC_URL", "https://eth.llamarpc.com"),
        }
        return urls.get(network, network)  # Allow custom RPC URL
    
    def run_command(self, cmd: List[str], capture_output=True) -> str:
        """Run a shell command and return output"""
        try:
            result = subprocess.run(
                cmd,
                capture_output=capture_output,
                text=True,
                check=True
            )
            return result.stdout.strip()
        except subprocess.CalledProcessError as e:
            print(f"Error running command: {' '.join(cmd)}")
            print(f"Error: {e.stderr}")
            raise
    
    def get_facet_functions(self) -> List[FunctionInfo]:
        """Extract all function signatures and selectors from the facet contract"""
        print(f"\n📝 Analyzing {self.facet_name} contract...")
        
        # First, ensure contracts are compiled
        print("   Compiling contracts...")
        self.run_command(["forge", "build", "--force"])
        
        # Get contract ABI from compiled artifacts
        artifact_path = f"out/{self.facet_name}.sol/{self.facet_name}.json"
        
        if not os.path.exists(artifact_path):
            raise FileNotFoundError(f"Compiled artifact not found: {artifact_path}. Run 'forge build' first.")
        
        print(f"   Reading artifact from {artifact_path}")
        with open(artifact_path, 'r') as f:
            artifact = json.load(f)
        abi = artifact.get('abi', [])
        
        functions = []
        for item in abi:
            if item["type"] == "function":
                # Build function signature
                params = ",".join([param["type"] for param in item["inputs"]])
                signature = f"{item['name']}({params})"
                
                # Get selector using cast
                selector = self.run_command(["cast", "sig", signature])
                
                functions.append(FunctionInfo(
                    name=item["name"],
                    signature=signature,
                    selector=selector
                ))
        
        print(f"   Found {len(functions)} functions in {self.facet_name}:")
        for func in functions:
            print(f"   - {func.signature} → {func.selector}")
        
        return functions
    
    def get_diamond_selectors(self, facet_address: str = None) -> Set[str]:
        """Get all selectors currently registered in the Diamond (optionally for a specific facet)"""
        print(f"\n🔍 Querying Diamond at {self.diamond_address}...")
        
        if facet_address:
            # Get selectors for specific facet
            result = self.run_command([
                "cast", "call",
                self.diamond_address,
                "facetFunctionSelectors(address)(bytes4[])",
                facet_address,
                "--rpc-url", self.rpc_url
            ])
        else:
            # Get all selectors from all facets using facetAddresses() and facetFunctionSelectors()
            # First, get all facet addresses
            facets_result = self.run_command([
                "cast", "call",
                self.diamond_address,
                "facetAddresses()(address[])",
                "--rpc-url", self.rpc_url
            ])
            
            # Parse facet addresses
            facet_addresses = []
            if facets_result:
                # Extract addresses from the result
                import re
                addresses = re.findall(r'0x[a-fA-F0-9]{40}', facets_result)
                facet_addresses = addresses
            
            # Now get selectors from each facet
            result_parts = []
            for addr in facet_addresses:
                facet_selectors = self.run_command([
                    "cast", "call",
                    self.diamond_address,
                    "facetFunctionSelectors(address)(bytes4[])",
                    addr,
                    "--rpc-url", self.rpc_url
                ])
                if facet_selectors and facet_selectors != "[]":
                    result_parts.append(facet_selectors)
            
            # Combine all results
            result = ",".join(result_parts) if result_parts else "[]"
        
        # Parse the result to extract selectors
        # Result format: [0x12345678,0x87654321,...]
        selectors = set()
        if result and result != "[]":
            # Clean up the result and extract hex values
            cleaned = result.replace("[", "").replace("]", "").replace(" ", "")
            if cleaned:
                for item in cleaned.split(","):
                    if item.startswith("0x") and len(item) == 10:  # bytes4 selector
                        selectors.add(item)
        
        print(f"   Found {len(selectors)} selectors in Diamond")
        if selectors:
            print(f"   Selectors: {', '.join(sorted(selectors))}")
        
        return selectors
    
    def get_facet_address(self, selector: str) -> str:
        """Get the facet address that handles a specific selector"""
        result = self.run_command([
            "cast", "call",
            self.diamond_address,
            "facetAddress(bytes4)(address)",
            selector,
            "--rpc-url", self.rpc_url
        ])
        return result
    
    def determine_upgrade_actions(self, new_functions: List[FunctionInfo]) -> Tuple[UpgradeAction, UpgradeAction, UpgradeAction]:
        """
        Determine which functions need to be Added, Replaced, or Removed
        
        Returns:
            (add_action, replace_action, remove_action)
        """
        print(f"\n🔄 Determining upgrade actions...")
        
        # Get ALL selectors currently in the Diamond (across all facets)
        # We need to check all selectors to properly detect Add vs Replace
        diamond_selectors = self.get_diamond_selectors()
        
        # Create sets for comparison
        new_selectors = {func.selector for func in new_functions}
        
        # Determine actions
        to_add = new_selectors - diamond_selectors
        to_replace = new_selectors & diamond_selectors
        to_remove = diamond_selectors - new_selectors
        
        # Build action objects
        add_action = UpgradeAction(
            action="Add",
            selectors=sorted(list(to_add)),
            signatures=[f.signature for f in new_functions if f.selector in to_add]
        )
        
        replace_action = UpgradeAction(
            action="Replace",
            selectors=sorted(list(to_replace)),
            signatures=[f.signature for f in new_functions if f.selector in to_replace]
        )
        
        remove_action = UpgradeAction(
            action="Remove",
            selectors=sorted(list(to_remove)),
            signatures=[]  # We don't have signatures for removed functions
        )
        
        # Print summary
        print(f"\n📊 Upgrade Summary:")
        print(f"   ✅ Add:     {len(add_action.selectors)} functions")
        for i, sig in enumerate(add_action.signatures):
            selector = add_action.selectors[i]
            print(f"      - {selector} {sig}")
        print(f"   🔄 Replace: {len(replace_action.selectors)} functions")
        for i, sig in enumerate(replace_action.signatures):
            selector = replace_action.selectors[i]
            print(f"      - {selector} {sig}")
        print(f"   ❌ Remove:  {len(remove_action.selectors)} functions")
        for sel in remove_action.selectors:
            print(f"      - {sel}")
        
        return add_action, replace_action, remove_action
    
    def generate_upgrade_scripts(self, add_action: UpgradeAction, replace_action: UpgradeAction, remove_action: UpgradeAction):
        """Generate Solidity upgrade scripts for Add, Replace, and Remove actions"""
        print(f"\n📝 Generating upgrade scripts...")
        
        # Generate AddFacet.s.sol
        if add_action.selectors:
            self._generate_add_script(add_action)
        
        # Generate ReplaceFacet.s.sol
        if replace_action.selectors:
            self._generate_replace_script(replace_action)
        
        # Generate RemoveFacet.s.sol
        if remove_action.selectors:
            self._generate_remove_script(remove_action)
        
        print(f"   Generated scripts in script/ directory")
    
    def _generate_add_script(self, action: UpgradeAction):
        """Generate script for adding new functions"""
        selectors_array = "\n        ".join([f'selectors[{i}] = {sel};' for i, sel in enumerate(action.selectors)])
        
        script = f'''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/{self.facet_name}.sol";
import "../contracts/libraries/LibDiamond.sol";

/**
 * @title AddFacetScript
 * @dev Auto-generated script to add new functions to {self.facet_name}
 * 
 * Functions to add: {len(action.selectors)}
{self._format_function_list(action.signatures)}
 * 
 * Usage:
 *   DIAMOND_ADDRESS=0x... forge script script/AddFacet.s.sol:AddFacetScript --rpc-url sepolia --broadcast
 */
contract AddFacetScript is Script {{
    
    function run() external {{
        address diamondAddress = vm.envAddress("DIAMOND_ADDRESS");
        require(diamondAddress != address(0), "DIAMOND_ADDRESS not set");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console.log("==============================================");
        console.log("Adding Functions to Diamond");
        console.log("==============================================");
        console.log("Diamond Address:", diamondAddress);
        console.log("Facet: {self.facet_name}");
        console.log("Functions to add:");
        console.logUint({len(action.selectors)});
        console.log("==============================================\\n");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy new facet
        {self.facet_name} newFacet = new {self.facet_name}();
        console.log("New {self.facet_name} deployed to:", address(newFacet));
        
        // Prepare selectors for functions to add
        bytes4[] memory selectors = new bytes4[]({len(action.selectors)});
        {selectors_array}
        
        // Prepare diamond cut
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({{
            facetAddress: address(newFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        }});
        
        // Execute diamond cut
        DiamondCutFacet(diamondAddress).diamondCut(cuts, address(0), "");
        
        vm.stopBroadcast();
        
        console.log("\\nSuccessfully added", selectors.length, "functions");
        console.log("==============================================\\n");
    }}
}}
'''
        
        with open("script/AddFacet.s.sol", "w") as f:
            f.write(script)
        
        print(f"   ✅ Generated script/AddFacet.s.sol")
    
    def _generate_replace_script(self, action: UpgradeAction):
        """Generate script for replacing existing functions"""
        selectors_array = "\n        ".join([f'selectors[{i}] = {sel};' for i, sel in enumerate(action.selectors)])
        
        script = f'''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/{self.facet_name}.sol";
import "../contracts/libraries/LibDiamond.sol";

/**
 * @title ReplaceFacetScript
 * @dev Auto-generated script to replace existing functions in {self.facet_name}
 * 
 * Functions to replace: {len(action.selectors)}
{self._format_function_list(action.signatures)}
 * 
 * Usage:
 *   DIAMOND_ADDRESS=0x... forge script script/ReplaceFacet.s.sol:ReplaceFacetScript --rpc-url sepolia --broadcast
 */
contract ReplaceFacetScript is Script {{
    
    function run() external {{
        address diamondAddress = vm.envAddress("DIAMOND_ADDRESS");
        require(diamondAddress != address(0), "DIAMOND_ADDRESS not set");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console.log("==============================================");
        console.log("Replacing Functions in Diamond");
        console.log("==============================================");
        console.log("Diamond Address:", diamondAddress);
        console.log("Facet: {self.facet_name}");
        console.log("Functions to replace:");
        console.logUint({len(action.selectors)});
        console.log("==============================================\\n");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy new facet
        {self.facet_name} newFacet = new {self.facet_name}();
        console.log("New {self.facet_name} deployed to:", address(newFacet));
        
        // Prepare selectors for functions to replace
        bytes4[] memory selectors = new bytes4[]({len(action.selectors)});
        {selectors_array}
        
        // Prepare diamond cut
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({{
            facetAddress: address(newFacet),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: selectors
        }});
        
        // Execute diamond cut
        DiamondCutFacet(diamondAddress).diamondCut(cuts, address(0), "");
        
        vm.stopBroadcast();
        
        console.log("\\nSuccessfully replaced", selectors.length, "functions");
        console.log("==============================================\\n");
    }}
}}
'''
        
        with open("script/ReplaceFacet.s.sol", "w") as f:
            f.write(script)
        
        print(f"   🔄 Generated script/ReplaceFacet.s.sol")
    
    def _generate_remove_script(self, action: UpgradeAction):
        """Generate script for removing functions"""
        selectors_array = "\n        ".join([f'selectors[{i}] = {sel};' for i, sel in enumerate(action.selectors)])
        
        script = f'''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/Diamond.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/libraries/LibDiamond.sol";

/**
 * @title RemoveFacetScript
 * @dev Auto-generated script to remove functions from {self.facet_name}
 * 
 * Functions to remove: {len(action.selectors)}
 * Selectors: {', '.join(action.selectors)}
 * 
 * Usage:
 *   DIAMOND_ADDRESS=0x... forge script script/RemoveFacet.s.sol:RemoveFacetScript --rpc-url sepolia --broadcast
 */
contract RemoveFacetScript is Script {{
    
    function run() external {{
        address diamondAddress = vm.envAddress("DIAMOND_ADDRESS");
        require(diamondAddress != address(0), "DIAMOND_ADDRESS not set");
        
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console.log("==============================================");
        console.log("Removing Functions from Diamond");
        console.log("==============================================");
        console.log("Diamond Address:", diamondAddress);
        console.log("Facet: {self.facet_name}");
        console.log("Functions to remove:");
        console.logUint({len(action.selectors)});
        console.log("==============================================\\n");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Prepare selectors for functions to remove
        bytes4[] memory selectors = new bytes4[]({len(action.selectors)});
        {selectors_array}
        
        // Prepare diamond cut
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({{
            facetAddress: address(0), // Must be zero for Remove
            action: IDiamondCut.FacetCutAction.Remove,
            functionSelectors: selectors
        }});
        
        // Execute diamond cut
        DiamondCutFacet(diamondAddress).diamondCut(cuts, address(0), "");
        
        vm.stopBroadcast();
        
        console.log("\\nSuccessfully removed", selectors.length, "functions");
        console.log("==============================================\\n");
    }}
}}
'''
        
        with open("script/RemoveFacet.s.sol", "w") as f:
            f.write(script)
        
        print(f"   ❌ Generated script/RemoveFacet.s.sol")
    
    def _format_function_list(self, signatures: List[str]) -> str:
        """Format function signatures as comments"""
        if not signatures:
            return " * (none)"
        return "\n".join([f" * - {sig}" for sig in signatures])
    
    def execute_upgrades(self, add_action: UpgradeAction, replace_action: UpgradeAction, remove_action: UpgradeAction, auto_execute: bool = False):
        """Execute the generated upgrade scripts"""
        print(f"\n🚀 Executing upgrades...")
        
        scripts_to_run = []
        
        if replace_action.selectors:
            scripts_to_run.append(("Replace", "script/ReplaceFacet.s.sol:ReplaceFacetScript"))
        
        if add_action.selectors:
            scripts_to_run.append(("Add", "script/AddFacet.s.sol:AddFacetScript"))
        
        if remove_action.selectors:
            scripts_to_run.append(("Remove", "script/RemoveFacet.s.sol:RemoveFacetScript"))
        
        if not scripts_to_run:
            print("   ℹ️  No upgrades needed")
            return
        
        if not auto_execute:
            print(f"\n📋 To execute upgrades, run the following commands:")
            for action_name, script_path in scripts_to_run:
                print(f"\n   # {action_name} functions")
                print(f"   DIAMOND_ADDRESS={self.diamond_address} forge script {script_path} \\")
                print(f"     --rpc-url {self.network} --broadcast")
            return
        
        # Auto-execute
        for action_name, script_path in scripts_to_run:
            print(f"\n   Executing {action_name}...")
            try:
                self.run_command([
                    "forge", "script", script_path,
                    "--rpc-url", self.rpc_url,
                    "--broadcast"
                ], capture_output=False)
                print(f"   ✅ {action_name} completed")
            except Exception as e:
                print(f"   ❌ {action_name} failed: {e}")
                raise

def main():
    # Load .env file first
    load_env_file()
    
    parser = argparse.ArgumentParser(
        description="Automate Diamond proxy upgrades by analyzing contract changes",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Analyze CounterFacet and generate upgrade scripts
  python scripts/auto_upgrade.py --facet CounterFacet --diamond 0x5962... --network sepolia

  # Analyze and auto-execute upgrades
  python scripts/auto_upgrade.py --facet CounterFacet --diamond 0x5962... --network sepolia --execute

  # Use custom RPC URL
  python scripts/auto_upgrade.py --facet ERC20Facet --diamond 0x5962... --network https://my-rpc-url.com
        """
    )
    
    parser.add_argument("--facet", required=True, help="Facet contract name (e.g., CounterFacet)")
    parser.add_argument("--diamond", required=True, help="Diamond proxy address")
    parser.add_argument("--network", default="sepolia", help="Network name or RPC URL (default: sepolia)")
    parser.add_argument("--execute", action="store_true", help="Auto-execute the upgrades (default: only generate scripts)")
    parser.add_argument("--private-key", help="Private key (or set PRIVATE_KEY env var)")
    
    args = parser.parse_args()
    
    try:
        # Create upgrader instance
        upgrader = DiamondUpgrader(
            facet_name=args.facet,
            diamond_address=args.diamond,
            network=args.network,
            private_key=args.private_key
        )
        
        # Step 1: Analyze facet contract
        new_functions = upgrader.get_facet_functions()
        
        # Step 2: Determine upgrade actions
        add_action, replace_action, remove_action = upgrader.determine_upgrade_actions(new_functions)
        
        # Step 3: Generate upgrade scripts
        upgrader.generate_upgrade_scripts(add_action, replace_action, remove_action)
        
        # Step 4: Execute (if requested)
        upgrader.execute_upgrades(add_action, replace_action, remove_action, auto_execute=args.execute)
        
        print(f"\n✨ Upgrade analysis complete!")
        
    except Exception as e:
        print(f"\n❌ Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
