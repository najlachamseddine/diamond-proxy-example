/**
 * Diamond Upgrade Script
 * 
 * This script demonstrates how to:
 * 1. Add new facets to an existing diamond
 * 2. Replace functions in existing facets
 * 3. Remove functions from facets
 */

const { ethers } = require("hardhat");

// Get function selectors from a contract
function getSelectors(contract) {
  const signatures = Object.keys(contract.interface.functions);
  const selectors = signatures.reduce((acc, signature) => {
    if (signature !== "init(bytes)") {
      acc.push(contract.interface.getSighash(signature));
    }
    return acc;
  }, []);
  return selectors;
}

// FacetCutAction enum values
const FacetCutAction = {
  Add: 0,
  Replace: 1,
  Remove: 2
};

async function main() {
  // You need to set this to your deployed diamond address
  const DIAMOND_ADDRESS = process.env.DIAMOND_ADDRESS || "YOUR_DIAMOND_ADDRESS";
  
  if (DIAMOND_ADDRESS === "YOUR_DIAMOND_ADDRESS") {
    console.log("Please set DIAMOND_ADDRESS environment variable");
    console.log("Example: DIAMOND_ADDRESS=0x... npx hardhat run scripts/upgrade.js");
    return;
  }

  const [deployer] = await ethers.getSigners();
  console.log("Upgrading Diamond with account:", deployer.address);
  console.log("Diamond address:", DIAMOND_ADDRESS);
  console.log("-------------------------------------------");

  // ============================================================
  // Example 1: Add a new facet
  // ============================================================
  console.log("\n📦 Example: Adding a new CounterV2 facet...\n");

  // For this example, we'll redeploy CounterFacet as a "new version"
  // In practice, you'd deploy a new contract with different functionality
  const CounterFacet = await ethers.getContractFactory("CounterFacet");
  const counterFacetV2 = await CounterFacet.deploy();
  await counterFacetV2.waitForDeployment();
  console.log("✅ CounterFacetV2 deployed to:", await counterFacetV2.getAddress());

  // Get the DiamondCut facet to make changes
  const diamondCut = await ethers.getContractAt("DiamondCutFacet", DIAMOND_ADDRESS);

  // Example: Replace existing counter functions with new implementation
  const replaceSelectors = getSelectors(counterFacetV2);
  
  const facetCuts = [
    {
      facetAddress: await counterFacetV2.getAddress(),
      action: FacetCutAction.Replace,
      functionSelectors: replaceSelectors
    }
  ];

  console.log("\n🔧 Executing diamondCut to replace Counter functions...\n");
  
  // Execute the diamond cut
  const tx = await diamondCut.diamondCut(
    facetCuts,
    ethers.ZeroAddress, // No initialization function
    "0x" // No initialization data
  );
  await tx.wait();
  
  console.log("✅ Diamond upgraded successfully!");
  console.log("Transaction hash:", tx.hash);

  // ============================================================
  // Verify the upgrade
  // ============================================================
  console.log("\n🔍 Verifying upgrade...\n");

  const loupe = await ethers.getContractAt("DiamondLoupeFacet", DIAMOND_ADDRESS);
  
  // Check which facet handles the getCounter function
  const getCounterSelector = counterFacetV2.interface.getFunction("getCounter").selector;
  const facetAddress = await loupe.facetAddress(getCounterSelector);
  
  console.log("getCounter() is now handled by:", facetAddress);
  console.log("Expected (new facet):", await counterFacetV2.getAddress());

  // Test the upgraded counter
  const counter = await ethers.getContractAt("CounterFacet", DIAMOND_ADDRESS);
  console.log("\nCounter value:", (await counter.getCounter()).toString());
}

// ============================================================
// Example: Removing functions
// ============================================================
async function removeExample() {
  const DIAMOND_ADDRESS = process.env.DIAMOND_ADDRESS;
  
  // To remove functions, use FacetCutAction.Remove with address(0)
  const selectorsToRemove = [
    // Add function selectors to remove
    // e.g., "0x12345678"
  ];

  const facetCuts = [
    {
      facetAddress: ethers.ZeroAddress, // Must be zero address for Remove
      action: FacetCutAction.Remove,
      functionSelectors: selectorsToRemove
    }
  ];

  const diamondCut = await ethers.getContractAt("DiamondCutFacet", DIAMOND_ADDRESS);
  await diamondCut.diamondCut(facetCuts, ethers.ZeroAddress, "0x");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
