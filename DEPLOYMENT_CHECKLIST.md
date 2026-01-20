# Diamond Proxy Deployment Checklist

Use this checklist when deploying your Diamond to production.

## Pre-Deployment

### Security Review
- [ ] Code has been audited by professional security firm
- [ ] All facets have been formally verified
- [ ] Access control mechanisms reviewed (ownership, modifiers)
- [ ] Storage collision prevention verified
- [ ] All events properly emitted for transparency
- [ ] Error handling covers all edge cases

### Testing
- [ ] All unit tests pass (Foundry: 21/21, Hardhat: 20/20)
- [ ] Integration tests completed
- [ ] Upgrade scenarios tested on testnet
- [ ] Gas optimization verified
- [ ] Fuzz testing completed (Foundry)
- [ ] Load testing performed

### Documentation
- [ ] All functions have NatSpec comments
- [ ] Architecture documented
- [ ] Upgrade procedures documented
- [ ] Emergency procedures defined
- [ ] User guides created

## Environment Setup

### Keys & Access
- [ ] Hardware wallet connected (Ledger/Trezor)
- [ ] Private key stored securely (never in code)
- [ ] Multi-sig wallet configured for ownership
- [ ] Timelock contract deployed (recommended)
- [ ] RPC endpoint configured and tested

### Configuration
- [ ] `.env` file created from `.env.example`
- [ ] RPC URLs verified and working
- [ ] Gas price strategy determined
- [ ] Etherscan API key configured for verification
- [ ] Network chain ID confirmed

## Testnet Deployment

### Sepolia/Goerli Deployment
```bash
# Set environment
source .env

# Verify RPC connection
cast block latest --rpc-url $SEPOLIA_RPC_URL

# Deploy
forge script script/Deploy.s.sol:DiamondDeployScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv

# Save deployment addresses
echo "DIAMOND_ADDRESS=0x..." >> .env.testnet
```

- [ ] Diamond deployed successfully
- [ ] All facets deployed
- [ ] Contracts verified on Etherscan
- [ ] Deployment transaction confirmed
- [ ] Addresses saved to `.env.testnet`

### Testnet Verification
- [ ] Call `facets()` to verify all facets registered
- [ ] Test each facet function
- [ ] Verify ownership set correctly
- [ ] Test DiamondCut operation (add/replace/remove)
- [ ] Verify events emitted correctly
- [ ] Check gas usage is acceptable
- [ ] Simulate emergency scenarios

### Testnet Testing Period
- [ ] Community testing (if applicable)
- [ ] Bug bounty program (recommended)
- [ ] Minimum 1 week testing period
- [ ] Monitor for any issues
- [ ] Collect feedback

## Mainnet Deployment

### Pre-Mainnet Checks
- [ ] All testnet tests successful
- [ ] No outstanding bugs or issues
- [ ] Team review completed
- [ ] Gas price strategy confirmed
- [ ] Emergency pause mechanism ready
- [ ] Monitoring tools configured

### Mainnet Deployment
```bash
# TRIPLE CHECK everything!
source .env

# Verify RPC
cast block latest --rpc-url $MAINNET_RPC_URL

# CHECK GAS PRICES
cast gas-price --rpc-url $MAINNET_RPC_URL

# Deploy with explicit gas settings
forge script script/Deploy.s.sol:DiamondDeployScript \
  --rpc-url $MAINNET_RPC_URL \
  --broadcast \
  --verify \
  --gas-price 30gwei \
  --priority-gas-price 2gwei \
  -vvvv

# SAVE ADDRESSES IMMEDIATELY
echo "DIAMOND_ADDRESS=..." >> .env.mainnet
```

- [ ] Diamond address: `0x...`
- [ ] DiamondCutFacet: `0x...`
- [ ] DiamondLoupeFacet: `0x...`
- [ ] OwnershipFacet: `0x...`
- [ ] CounterFacet: `0x...`
- [ ] ERC20Facet: `0x...`
- [ ] All addresses saved securely

### Post-Deployment Verification
```bash
# Verify all facets
cast call $DIAMOND_ADDRESS "facets()(tuple(address,bytes4[])[])" \
  --rpc-url $MAINNET_RPC_URL

# Verify owner
cast call $DIAMOND_ADDRESS "owner()(address)" \
  --rpc-url $MAINNET_RPC_URL

# Test a function
cast call $DIAMOND_ADDRESS "getCounter()(uint256)" \
  --rpc-url $MAINNET_RPC_URL
```

- [ ] All facets registered correctly
- [ ] Owner address correct (should be multi-sig)
- [ ] All function selectors working
- [ ] Contracts verified on Etherscan
- [ ] No errors in deployment

## Post-Deployment

### Security Measures
- [ ] Transfer ownership to multi-sig (if not already)
- [ ] Set up timelock for upgrades (recommended 24-48 hours)
- [ ] Configure emergency pause if implemented
- [ ] Set up monitoring alerts
- [ ] Configure access control for critical functions

### Monitoring Setup
- [ ] Etherscan alerts configured
- [ ] Transaction monitoring active
- [ ] Error tracking configured
- [ ] Gas usage monitoring
- [ ] Event log monitoring

### Documentation & Communication
- [ ] Deployment announcement prepared
- [ ] Contract addresses published
- [ ] User documentation updated
- [ ] API documentation updated
- [ ] Community notified

### Backup & Recovery
- [ ] Private keys backed up securely
- [ ] Multi-sig recovery process documented
- [ ] Upgrade procedures documented
- [ ] Emergency contact list created
- [ ] Incident response plan ready

## Upgrade Procedures

### Planning an Upgrade
- [ ] New facet code reviewed and tested
- [ ] Upgrade script tested on testnet
- [ ] Gas costs estimated
- [ ] Upgrade announcement prepared
- [ ] Timelock delay considered

### Executing an Upgrade
```bash
# Test on testnet first!
export DIAMOND_ADDRESS=0x... # testnet

forge script script/Upgrade.s.sol:DiamondUpgradeScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast

# If successful, upgrade mainnet
export DIAMOND_ADDRESS=0x... # mainnet

forge script script/Upgrade.s.sol:DiamondUpgradeScript \
  --rpc-url $MAINNET_RPC_URL \
  --broadcast \
  --gas-price 30gwei
```

- [ ] Upgrade tested on testnet
- [ ] Community notified (if applicable)
- [ ] Timelock wait period observed
- [ ] Upgrade executed successfully
- [ ] New facet verified
- [ ] Functionality tested
- [ ] Users notified

## Maintenance

### Regular Checks (Weekly)
- [ ] Monitor gas prices for upgrades
- [ ] Check for security advisories
- [ ] Review transaction patterns
- [ ] Check error logs
- [ ] Verify all facets functioning

### Regular Checks (Monthly)
- [ ] Review access control
- [ ] Audit event logs
- [ ] Check for unused facets
- [ ] Review upgrade opportunities
- [ ] Community feedback review

## Emergency Procedures

### If Bug Discovered
1. [ ] Assess severity immediately
2. [ ] Pause contract if possible
3. [ ] Notify users if critical
4. [ ] Deploy fix to testnet
5. [ ] Test fix thoroughly
6. [ ] Deploy fix to mainnet via upgrade
7. [ ] Post-mortem analysis

### Contact Information
- Lead Developer: _______________
- Security Team: _______________
- Multi-sig Signers: _______________
- Audit Firm: _______________

## Sign-Off

Deployment completed by: _______________
Date: _______________
Network: _______________
Diamond Address: _______________

Verified by: _______________
Date: _______________

Approved for production: _______________
Date: _______________

---

**Remember**: 
- Never rush deployment
- Always test on testnet first
- Use multi-sig for mainnet
- Monitor continuously after deployment
- Have emergency procedures ready
