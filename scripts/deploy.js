/**
 * Diamond Deployment Script
 * 
 * This script demonstrates how to:
 * 1. Deploy all facet contracts
 * 2. Get function selectors from each facet
 * 3. Deploy the Diamond with initial facets
 * 4. Add additional facets after deployment
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

// Get a specific function selector
function getSelector(func) {
  const abiInterface = new ethers.Interface([func]);
  return abiInterface.getFunction(func.split("(")[0]).selector;
}

// Remove specific selectors from an array
function removeSelectors(selectors, selectorsToRemove) {
  return selectors.filter(selector => !selectorsToRemove.includes(selector));
}

// FacetCutAction enum values
const FacetCutAction = {
  Add: 0,
  Replace: 1,
  Remove: 2
};

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying Diamond with account:", deployer.address);
  console.log("Account balance:", (await ethers.provider.getBalance(deployer.address)).toString());
  console.log("-------------------------------------------");

  // ============================================================
  // Step 1: Deploy all facet contracts
  // ============================================================
  console.log("\n📦 Deploying Facets...\n");

  // Deploy DiamondCutFacet
  const DiamondCutFacet = await ethers.getContractFactory("DiamondCutFacet");
  const diamondCutFacet = await DiamondCutFacet.deploy();
  await diamondCutFacet.waitForDeployment();
  console.log("✅ DiamondCutFacet deployed to:", await diamondCutFacet.getAddress());

  // Deploy DiamondLoupeFacet
  const DiamondLoupeFacet = await ethers.getContractFactory("DiamondLoupeFacet");
  const diamondLoupeFacet = await DiamondLoupeFacet.deploy();
  await diamondLoupeFacet.waitForDeployment();
  console.log("✅ DiamondLoupeFacet deployed to:", await diamondLoupeFacet.getAddress());

  // Deploy OwnershipFacet
  const OwnershipFacet = await ethers.getContractFactory("OwnershipFacet");
  const ownershipFacet = await OwnershipFacet.deploy();
  await ownershipFacet.waitForDeployment();
  console.log("✅ OwnershipFacet deployed to:", await ownershipFacet.getAddress());

  // Deploy CounterFacet
  const CounterFacet = await ethers.getContractFactory("CounterFacet");
  const counterFacet = await CounterFacet.deploy();
  await counterFacet.waitForDeployment();
  console.log("✅ CounterFacet deployed to:", await counterFacet.getAddress());

  // Deploy ERC20Facet
  const ERC20Facet = await ethers.getContractFactory("ERC20Facet");
  const erc20Facet = await ERC20Facet.deploy();
  await erc20Facet.waitForDeployment();
  console.log("✅ ERC20Facet deployed to:", await erc20Facet.getAddress());

  // ============================================================
  // Step 2: Prepare FacetCuts for Diamond deployment
  // ============================================================
  console.log("\n🔧 Preparing FacetCuts...\n");

  const facetCuts = [
    {
      facetAddress: await diamondCutFacet.getAddress(),
      action: FacetCutAction.Add,
      functionSelectors: getSelectors(diamondCutFacet)
    },
    {
      facetAddress: await diamondLoupeFacet.getAddress(),
      action: FacetCutAction.Add,
      functionSelectors: getSelectors(diamondLoupeFacet)
    },
    {
      facetAddress: await ownershipFacet.getAddress(),
      action: FacetCutAction.Add,
      functionSelectors: getSelectors(ownershipFacet)
    },
    {
      facetAddress: await counterFacet.getAddress(),
      action: FacetCutAction.Add,
      functionSelectors: getSelectors(counterFacet)
    },
    {
      facetAddress: await erc20Facet.getAddress(),
      action: FacetCutAction.Add,
      functionSelectors: getSelectors(erc20Facet)
    }
  ];

  // Log the facet cuts
  for (const cut of facetCuts) {
    console.log(`Facet: ${cut.facetAddress}`);
    console.log(`  Selectors: ${cut.functionSelectors.length}`);
  }

  // ============================================================
  // Step 3: Deploy the Diamond
  // ============================================================
  console.log("\n💎 Deploying Diamond...\n");

  const Diamond = await ethers.getContractFactory("Diamond");
  const diamond = await Diamond.deploy(deployer.address, facetCuts);
  await diamond.waitForDeployment();
  
  const diamondAddress = await diamond.getAddress();
  console.log("✅ Diamond deployed to:", diamondAddress);

  // ============================================================
  // Step 4: Verify deployment using DiamondLoupe
  // ============================================================
  console.log("\n🔍 Verifying Diamond deployment...\n");

  // Connect to diamond using DiamondLoupe interface
  const loupe = await ethers.getContractAt("DiamondLoupeFacet", diamondAddress);
  
  const facets = await loupe.facets();
  console.log("Registered facets:");
  for (const facet of facets) {
    console.log(`  Address: ${facet.facetAddress}`);
    console.log(`  Selectors: ${facet.functionSelectors.length}`);
    console.log("");
  }

  // ============================================================
  // Step 5: Test the Counter facet
  // ============================================================
  console.log("\n🧪 Testing Counter facet...\n");

  const counter = await ethers.getContractAt("CounterFacet", diamondAddress);
  
  console.log("Initial counter value:", (await counter.getCounter()).toString());
  
  console.log("Incrementing counter...");
  await counter.increment();
  console.log("Counter after increment:", (await counter.getCounter()).toString());
  
  console.log("Incrementing by 5...");
  await counter.incrementBy(5);
  console.log("Counter after incrementBy(5):", (await counter.getCounter()).toString());

  // ============================================================
  // Step 6: Test the ERC20 facet
  // ============================================================
  console.log("\n🪙 Testing ERC20 facet...\n");

  const erc20 = await ethers.getContractAt("ERC20Facet", diamondAddress);
  
  // Initialize the token
  console.log("Initializing ERC20 token...");
  await erc20.initializeERC20("Diamond Token", "DMD", 18);
  console.log("Name:", await erc20.name());
  console.log("Symbol:", await erc20.symbol());
  console.log("Decimals:", await erc20.decimals());
  
  // Mint some tokens
  console.log("\nMinting 1000 tokens to deployer...");
  await erc20.mint(deployer.address, ethers.parseEther("1000"));
  console.log("Balance:", ethers.formatEther(await erc20.balanceOf(deployer.address)));

  // ============================================================
  // Summary
  // ============================================================
  console.log("\n" + "=".repeat(50));
  console.log("🎉 Diamond Deployment Complete!");
  console.log("=".repeat(50));
  console.log("\nDeployed Contracts:");
  console.log(`  Diamond:          ${diamondAddress}`);
  console.log(`  DiamondCutFacet:  ${await diamondCutFacet.getAddress()}`);
  console.log(`  DiamondLoupeFacet: ${await diamondLoupeFacet.getAddress()}`);
  console.log(`  OwnershipFacet:   ${await ownershipFacet.getAddress()}`);
  console.log(`  CounterFacet:     ${await counterFacet.getAddress()}`);
  console.log(`  ERC20Facet:       ${await erc20Facet.getAddress()}`);
  console.log("\nOwner:", deployer.address);

  return {
    diamond: diamondAddress,
    facets: {
      diamondCut: await diamondCutFacet.getAddress(),
      diamondLoupe: await diamondLoupeFacet.getAddress(),
      ownership: await ownershipFacet.getAddress(),
      counter: await counterFacet.getAddress(),
      erc20: await erc20Facet.getAddress()
    }
  };
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
