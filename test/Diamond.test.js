const { expect } = require("chai");
const { ethers } = require("hardhat");

// Helper function to get selectors from a contract
function getSelectors(contract) {
  const selectors = [];
  contract.interface.forEachFunction((func) => {
    selectors.push(func.selector);
  });
  return selectors;
}

const FacetCutAction = {
  Add: 0,
  Replace: 1,
  Remove: 2
};

describe("Diamond", function () {
  let diamond;
  let diamondCutFacet;
  let diamondLoupeFacet;
  let ownershipFacet;
  let counterFacet;
  let erc20Facet;
  let owner;
  let user1;
  let user2;
  let diamondAddress;

  before(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    // Deploy facets
    const DiamondCutFacet = await ethers.getContractFactory("DiamondCutFacet");
    diamondCutFacet = await DiamondCutFacet.deploy();

    const DiamondLoupeFacet = await ethers.getContractFactory("DiamondLoupeFacet");
    diamondLoupeFacet = await DiamondLoupeFacet.deploy();

    const OwnershipFacet = await ethers.getContractFactory("OwnershipFacet");
    ownershipFacet = await OwnershipFacet.deploy();

    const CounterFacet = await ethers.getContractFactory("CounterFacet");
    counterFacet = await CounterFacet.deploy();

    const ERC20Facet = await ethers.getContractFactory("ERC20Facet");
    erc20Facet = await ERC20Facet.deploy();

    // Prepare facet cuts
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

    // Deploy Diamond
    const Diamond = await ethers.getContractFactory("Diamond");
    diamond = await Diamond.deploy(owner.address, facetCuts);
    diamondAddress = await diamond.getAddress();
  });

  describe("DiamondLoupe", function () {
    it("should return all facet addresses", async function () {
      const loupe = await ethers.getContractAt("DiamondLoupeFacet", diamondAddress);
      const addresses = await loupe.facetAddresses();
      expect(addresses.length).to.equal(5);
    });

    it("should return all facets with their selectors", async function () {
      const loupe = await ethers.getContractAt("DiamondLoupeFacet", diamondAddress);
      const facets = await loupe.facets();
      expect(facets.length).to.equal(5);
      
      for (const facet of facets) {
        expect(facet.functionSelectors.length).to.be.greaterThan(0);
      }
    });

    it("should return correct facet address for a selector", async function () {
      const loupe = await ethers.getContractAt("DiamondLoupeFacet", diamondAddress);
      const selector = counterFacet.interface.getFunction("getCounter").selector;
      const facetAddress = await loupe.facetAddress(selector);
      expect(facetAddress).to.equal(await counterFacet.getAddress());
    });
  });

  describe("Ownership", function () {
    it("should return the correct owner", async function () {
      const ownership = await ethers.getContractAt("OwnershipFacet", diamondAddress);
      expect(await ownership.owner()).to.equal(owner.address);
    });

    it("should allow owner to transfer ownership", async function () {
      const ownership = await ethers.getContractAt("OwnershipFacet", diamondAddress);
      await ownership.transferOwnership(user1.address);
      expect(await ownership.owner()).to.equal(user1.address);
      
      // Transfer back to owner for other tests
      await ownership.connect(user1).transferOwnership(owner.address);
      expect(await ownership.owner()).to.equal(owner.address);
    });

    it("should not allow non-owner to transfer ownership", async function () {
      const ownership = await ethers.getContractAt("OwnershipFacet", diamondAddress);
      await expect(
        ownership.connect(user2).transferOwnership(user2.address)
      ).to.be.reverted;
    });
  });

  describe("CounterFacet", function () {
    it("should start with counter at 0", async function () {
      const counter = await ethers.getContractAt("CounterFacet", diamondAddress);
      expect(await counter.getCounter()).to.equal(0);
    });

    it("should increment the counter", async function () {
      const counter = await ethers.getContractAt("CounterFacet", diamondAddress);
      await counter.increment();
      expect(await counter.getCounter()).to.equal(1);
    });

    it("should increment by a specific amount", async function () {
      const counter = await ethers.getContractAt("CounterFacet", diamondAddress);
      await counter.incrementBy(5);
      expect(await counter.getCounter()).to.equal(6);
    });

    it("should decrement the counter", async function () {
      const counter = await ethers.getContractAt("CounterFacet", diamondAddress);
      await counter.decrement();
      expect(await counter.getCounter()).to.equal(5);
    });

    it("should reset the counter", async function () {
      const counter = await ethers.getContractAt("CounterFacet", diamondAddress);
      await counter.resetCounter();
      expect(await counter.getCounter()).to.equal(0);
    });

    it("should not allow decrement below zero", async function () {
      const counter = await ethers.getContractAt("CounterFacet", diamondAddress);
      await expect(counter.decrement()).to.be.revertedWith(
        "Counter: cannot decrement below zero"
      );
    });
  });

  describe("ERC20Facet", function () {
    before(async function () {
      const erc20 = await ethers.getContractAt("ERC20Facet", diamondAddress);
      await erc20.initializeERC20("Diamond Token", "DMD", 18);
    });

    it("should have correct token metadata", async function () {
      const erc20 = await ethers.getContractAt("ERC20Facet", diamondAddress);
      expect(await erc20.name()).to.equal("Diamond Token");
      expect(await erc20.symbol()).to.equal("DMD");
      expect(await erc20.decimals()).to.equal(18);
    });

    it("should not allow re-initialization", async function () {
      const erc20 = await ethers.getContractAt("ERC20Facet", diamondAddress);
      await expect(
        erc20.initializeERC20("New Token", "NEW", 18)
      ).to.be.revertedWith("ERC20: already initialized");
    });

    it("should allow owner to mint tokens", async function () {
      const erc20 = await ethers.getContractAt("ERC20Facet", diamondAddress);
      const amount = ethers.parseEther("1000");
      await erc20.mint(owner.address, amount);
      expect(await erc20.balanceOf(owner.address)).to.equal(amount);
      expect(await erc20.totalSupply()).to.equal(amount);
    });

    it("should allow transfers", async function () {
      const erc20 = await ethers.getContractAt("ERC20Facet", diamondAddress);
      const amount = ethers.parseEther("100");
      await erc20.transfer(user1.address, amount);
      expect(await erc20.balanceOf(user1.address)).to.equal(amount);
    });

    it("should allow approvals and transferFrom", async function () {
      const erc20 = await ethers.getContractAt("ERC20Facet", diamondAddress);
      const amount = ethers.parseEther("50");
      
      // user1 approves user2 to spend
      await erc20.connect(user1).approve(user2.address, amount);
      expect(await erc20.allowance(user1.address, user2.address)).to.equal(amount);
      
      // user2 transfers from user1 to themselves
      await erc20.connect(user2).transferFrom(user1.address, user2.address, amount);
      expect(await erc20.balanceOf(user2.address)).to.equal(amount);
    });

    it("should allow burning tokens", async function () {
      const erc20 = await ethers.getContractAt("ERC20Facet", diamondAddress);
      const burnAmount = ethers.parseEther("10");
      const balanceBefore = await erc20.balanceOf(user2.address);
      
      await erc20.connect(user2).burn(burnAmount);
      
      expect(await erc20.balanceOf(user2.address)).to.equal(balanceBefore - burnAmount);
    });
  });

  describe("DiamondCut", function () {
    it("should allow owner to add new functions", async function () {
      // Deploy a new counter facet (simulating an upgrade)
      const CounterFacet = await ethers.getContractFactory("CounterFacet");
      const newCounterFacet = await CounterFacet.deploy();
      
      // This is just testing that we can call diamondCut
      // In practice, you'd add new selectors
      const diamondCut = await ethers.getContractAt("DiamondCutFacet", diamondAddress);
      
      // Replace existing counter functions
      const selectors = getSelectors(newCounterFacet);
      
      await diamondCut.diamondCut(
        [{
          facetAddress: await newCounterFacet.getAddress(),
          action: FacetCutAction.Replace,
          functionSelectors: selectors
        }],
        ethers.ZeroAddress,
        "0x"
      );
      
      // Verify the new facet is registered
      const loupe = await ethers.getContractAt("DiamondLoupeFacet", diamondAddress);
      const facetAddress = await loupe.facetAddress(selectors[0]);
      expect(facetAddress).to.equal(await newCounterFacet.getAddress());
    });

    it("should not allow non-owner to modify diamond", async function () {
      const diamondCut = await ethers.getContractAt("DiamondCutFacet", diamondAddress);
      
      await expect(
        diamondCut.connect(user1).diamondCut([], ethers.ZeroAddress, "0x")
      ).to.be.reverted;
    });
  });
});
