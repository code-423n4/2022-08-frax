# Fraxlend contest details

- $50,000 USDC in awards
- $47,500 USDC main award pot
- $2,500 USDC gas optimization award pot
- Join [C4 Discord](https://discord.gg/code4rena) to register
- Submit findings [using the C4 form](https://code4rena.com/contests/2022-08-fraxlend-frax-finance-contest/submit)
- [Read our guidelines for more details](https://docs.code4rena.com/roles/wardens)
- Starts Aug 11, 2022 20:00 UTC
- Ends Aug 16, 2022 20:00 UTC

---

### [Fraxlend Documentation](https://docs.frax.finance/fraxlend/fraxlend-overview)

## Contest Scope TLDR

- Fraxlend Repository: [https://github.com/FraxFinance/fraxlend](https://github.com/FraxFinance/fraxlend)
- 7 Non-library contracts in the scope
- 1384 Total sLoC in scope.
- 2 library dependencies
- 4 structs, 1 external interface
- Contracts use inheritance
- 1 external function with external call to UniV2 router, 6 external functions with ERC-20 transfers, 1 external function with call to Chainlink oracle (No other oracles)
- No other external context/code base required
- FraxlendPair.sol conforms to ERC-4626 and ERC-20 standards
- No novel or unique curve logic or mathematical models
- No timelock function
- Not an NFT
- Not an AMM
- Not a fork of a popular project
- Does not use rollups
- Single-chain only

# Introduction to Fraxlend

- The Fraxlend platform allows for the deployment of Fraxlend Pairs, each pair represents an isolated lending market.
- Each pair is configured with one asset and one collateral token, Asset Tokens are borrowed by depositing Collateral Tokens.  Asset Tokens are lent in exchange for fTokens.  fTokens are redeemed for Asset Tokens plus accrued interest.
- Each pair is configured to use one or two Chainlink oracle contracts to provide an exchange rate between the two assets.
- Each pair is configured to use one Rate Calculator contract to determine interest rates.

## Pair Interaction Overview

![https://github.com/FraxFinance/fraxlend/raw/main/documentation/_images/PairOverview.png](https://github.com/FraxFinance/fraxlend/raw/main/documentation/_images/PairOverview.png)

# Deployment & Environment Setup

- Fraxlend Pairs are intended to be deployed from the Fraxlend Pair Deployer
- There are two ways to deploy a Fraxlend Pair:
    - Public Deploy - available to anyone but with limited configuration
    - Custom Deploy - available to whitelisted deployers
- Custom Deployment is only available to addresses whitelisted for deployment

## Intended Deployment Setup

- Fraxlend is intended to be used with whitelisted Chainlink crypto oracles only
- Fraxlend is intended to be used with whitelisted rate contracts **LinearInterestRate.sol** and **VariableInterestRate.sol**
- Fraxlend does not support rebasing tokens
- Fraxlend does not support fee-on-transfer tokens
- COMPTROLLER_ADDRESS is a 4/7 gnosis-safe
- CIRCUIT_BREAKER_ADDRESS is a 1/5 gnosis-safe
- TIME_LOCK_ADDRESS is a time-delay address

## Deployment steps

1. Deploy rate contracts, LinearInterestRate.sol and VariableInterestRate.sol
2. Deploy Fraxlend Whitelist and set owner to COMPTROLLER_ADDRESS
3. Whitelist intended oracles (chainlink crypto only, no FRAX oracles)
    1. Use $USD value for $FRAX, no $FRAX price oracles whitelisted.
4. Whitelist intended rateContracts from step 1
5. Whitelist intended custom deployment addresses
6. Deploy Fraxlend Deployer with proper constructor arguments and set owner to COMPTROLLER_ADDRESS

## Oracle Configuration

- Each Fraxlend Pair takes in two oracle addresses and a normalization parameter.  The normalization parameter helps account for oracle count and for different decimal values between asset and collateral.
- **exchangeRate** is a uint224 value and represents the amount of collateral needed to exchange for 1e18 asset (collateral/asset)
- `_oracleMultiply` - is the chainlink oracle which forms the numerator of the exchange rate
- `_oracleDivide` - is the chainlink oracle address which forms the denominator of the exchange rate
- `_oracleNormalization` - is a value which accounts for differences in precision across both oracles and the asset and denominator
    - It is calculated as: 1^(18 + precision of numerator oracle - precision of denominator oracle + precision of asset token - precision of collateral token)

## Example Deployment Configuration

The deploy() function takes a single abi encoded bytes array as an argument:

```solidity
// Frax asset (1e18 precision), WETH collateral (1e18 precision)
bytes memory _configData = abi.encode(
	FRAX_ERC20_ADDRESS, // asset
	WETH_ERC20_ADDRESS, // collateral
	address(0), // numerator oracle
	CHAINLINK_USD_ETH_ADDRESS, // denominator oracle
	1e10, // oracle normalization (18 + 0 - 8 + 18 - 18)
	VARIABLE_RATE_CONTRACT_ADDRESS,
	abi.encode() // No init for variable rate contract
);

// MKR asset (1e18 precision), WBTC collateral (1e8 precision)
bytes memory _configData = abi.encode(
	MKR_ERC20_ADDRESS, // asset
	WBTC_ERC20_ADDRESS, // collateral
	CHAINLINK_USD_WBTC, // numerator oracle (1e8 precision)
	CHAINLINK_USD_ETH_ADDRESS, // denominator oracle (1e8) precision
	1e28, // oracle normalization (18 + 18 - 8 + 8 - 8)
	VARIABLE_RATE_CONTRACT_ADDRESS,
	abi.encode() // No init for variable rate contract
);

fraxlendPairDeployer.deploy(_configData);
```

# Building and Testing

- First copy `.env.example` to `.env` and fill in archival node URLs as well as a mnemonic (hardhat only)
- To download needed modules run `npm install`
- This repository contains scripts to compile and test using both Hardhat and Foundry
- To run foundry tests you will need to [make sure foundry is installed](https://book.getfoundry.sh/getting-started/installation)
- Install foundry submodules `git submodule init && git submodule update`

Compilation

- `forge build`
- `npx hardhat compile`

Testing

- `source .env && forge test --fork-url $MAINNET_URL --fork-block-number $DEFAULT_FORK_BLOCK`

### Slither Static Analyzer

- If you would like to run slither, move the `src/contracts` directory to the root directory by running `mv src/contracts contracts`
- Then update key `config.paths.sources` in `hardhat.config.ts` (line 70) to be:
    - `sources: "./contracts"`
- Then run `slither .`

# Known Issues

### Misconfigured Oracles

- It is possible to misconfigure pairs and choose oracles and oracle normalization that do not match the assets or that cause prices to be invalid
- Assume that oracles and normalization are properly configured

### Low borrow balance combined with low interest rates

- When there is an exceptionally low borrow balance and a low interest rate, interest does not accrue due to rounding

### Custom Deployment Misconfiguration

- The custom deployment gives significantly more control to deployers, assume that deployer makes reasonable configuration choices on liquidationFee, maxLTV, penaltyRate etc.
- When making under-collateralized loans, lenders know and trust the counter-party

### Chainlink Oracle

- Chainlink oracles can provide outdated answers
- Very large chainlink oracle prices can cause overflow when calculating and when casting to uint224

### Frax Price Volatility

- Because $FRAX is treated as having a price of $1, $FRAX price volatility could cause bad debt or unnecessary liquidations

# Contracts Under Review

## [libraries/SafeERC20.sol](https://github.com/code-423n4/2022-08-frax/blob/main/src/contracts/libraries/SafeERC20.sol)

- Contains helper functions to wrap the symbol(), name(), and decimal() functions found in ERC20 Metadata calls
- Contains Open-Zeppelins SafeTransfer() and SafeTransferFrom() implementations
- LOC: 52

## [libraries/VaultAccount.sol](https://github.com/code-423n4/2022-08-frax/blob/main/src/contracts/libraries/VaultAccount.sol)

- Defines the VaultAccount struct, an instance of the struct is used to keep track of the accounting for borrows and for asset lending (see [Fraxlend - Advanced Concepts - Vault Account](https://docs.frax.finance/fraxlend/advanced-concepts/vault-account))
- Provides helper functions for converting between shares and amounts
- LOC: 35

## [LinearInterestRate.sol](https://github.com/code-423n4/2022-08-frax/blob/main/src/contracts/LinearInterestRate.sol)

- Adheres to the IRateCalculator.sol interface
- Provides logic for calculating the new interest rate as a function of utilization %
- Holds no state
- See: [Fraxlend - Advanced Concepts - Linear Rate](https://docs.frax.finance/fraxlend/advanced-concepts/interest-rates#linear-rate) for an explanation of the math
- LOC: 49

## [VariableInterestRate.sol](https://github.com/code-423n4/2022-08-frax/blob/main/src/contracts/VariableInterestRate.sol)

- Adheres to the IRateCalculator interface
- Provides logic for calculating the new interest rate as a function of utilization and time
- See: [Fraxlend - Advanced Concepts - Time-Weighted Variable Rate](https://docs.frax.finance/fraxlend/advanced-concepts/interest-rates#time-weighted-variable-interest-rate) for an explanation of the math
- LOC: 40

## [FraxlendWhitelist.sol](https://github.com/code-423n4/2022-08-frax/blob/main/src/contracts/FraxlendWhitelist.sol)

- Provides 3 whitelists:
    - RateCalculatorWhitelist - controls which calculators can be used for rate calculations
    - OracleWhitelist - controls which oracle contracts can be used for exchange rates
    - DeployerWhitelist - controls which addresses can deploy custom Fraxlend Pair instances
- LOC: 29

## [FraxlendPairConstants.sol](https://github.com/code-423n4/2022-08-frax/blob/main/src/contracts/FraxlendPairConstants.sol)

- Defines constants and errors only
- Inherited by tests and FraxlendPairCore
- LOC: 32

## [FraxlendPairCore.sol](https://github.com/code-423n4/2022-08-frax/blob/main/src/contracts/FraxlendPairCore.sol)

- Contains all external functions without access modifiers
- Contains core logic for the pair
- Contains all state for the pair
- Inherited by FraxlendPair
- **Libraries:**
    - VaultAccount
    - SafeERC20 (libraries/SafeERC20.sol)
- **External Contract Interactions**:
    - During deployment the constructor Interacts with the FraxlendWhitelist to ensure the configured oracles and rate contracts have been whitelisted
    - During Deposit, Withdraw, Mint, Redeem, Borrow, Repay, Liquidate, RepayAssetWithCollateral, LeveragedPosition interacts with the configured asset contract
    - During Borrow, AddCollateral, RemoveCollateral, Liquidate, RepayAssetWithCollateral, LeveragedPosition interacts with the configured collateral contract
    - Leverage and RepayAssetWithCollateral interact with a whitelisted swapper contract which adheres to the Uniswap V2 Router interface
    - _updateExchangeRate interacts with the two chainlink oracles
    - _addInterest interacts with the configured Rate Calculator contract (adheres to IRateCalculator.sol interface)
- LOC: 693

## [FraxlendPair.sol](https://github.com/code-423n4/2022-08-frax/blob/main/src/contracts/FraxlendPair.sol)

- Contains all view functions necessary to adhere to ERC-4626
- Contains access controlled configuration functions including
- SetSwapper,
- ChangeFee
- WithdrawFees
- Pause/Unpause
- SetApprovedBorrower/Lender
- LOC: 197

## [FraxlendPairDeployer.sol](https://github.com/code-423n4/2022-08-frax/blob/main/src/contracts/FraxlendPairDeployer.sol)

- Contains logic to deploy two pair types: Custom and Public
    - Public pairs are permissionlessly deployed
    - Custom pairs have access to an extra set of configuration items not allowed to pairs deployed via the public function and are only deployable by whitelisted addresses
- Stores information about pairs deployed like name, address, and whether they are custom pairs
- Contains the globalPause function which bulk pauses deployed fraxlend pairs
- **Libraries:**
    - https://github.com/GNSPS/solidity-bytes-utils: Used to concatenate creation code during deployment
    - Strings library from Open Zeppelin
    - SafeERC20 (libraries/SafeERC20.sol)
- **External Contract Interactions:**
    - During customDeployment, calls FraxlendWhitelist to make sure deployer is on whitelist
    - After initial deployment calls initialize() and transferOwnership() on the deployed FraxlendPair instance
- LOC: 257

## Total LOC: 1,384

# Contracts Included but not under review

## [FraxlendPairHelper.sol](https://github.com/code-423n4/2022-08-frax/blob/main/src/contracts/FraxlendPairHelper.sol)

- This contract contains view functions for previewing interest accrued and updating exchange rate
- Can be helpful for predicting the effects of your transaction prior to execution

## interfaces/*

- Interfaces provided for reference but are not included in audit
