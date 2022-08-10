# Fraxlend contest details
- $50,000 USDC total awards
- $47,500 USDC main award pot
- $2,500 USDC gas optimization award pot
- Join [C4 Discord](https://discord.gg/code4rena) to register
- Submit findings [using the C4 form](https://code4rena.com/contests/2022-08-fraxlend-frax-finance-contest/submit)
- [Read our guidelines for more details](https://docs.code4rena.com/roles/wardens)
- Starts Aug 11, 2022 20:00 UTC
- Ends Aug 16, 2022 20:00 UTC

# Building and Testing

- First copy `sample.env` to `.env` and fill in archival node URLs as well as a mnemonic (hardhat only)
- This repository contains scripts to compile and test using both Hardhat and Foundry
    - Compile
        - `forge build`
        - `npx hardhat compile`
    - Testing
        - `source .env && forge test --fork-url $MAINNET_URL --fork-block-number $DEFAULT_FORK_BLOCK` (mainnet forking)
        - `forge test` (without mainnet forking)
  


<br>
<br>

# Contracts Under Review

## libraries/SafeERC20.sol

- Contains helper functions to wrap the symbol(), name(), and decimal() functions found in ERC20 Metadata calls
- Contains Open-Zeppelins SafeTransfer() and SafeTransferFrom() implementations
- LOC: 52

## libraries/VaultAccount.sol

- Defines the VaultAccount struct, an instance of the struct is used to keep track of the accounting for borrows and for asset lending
- Provides helper functions for converting between shares and amounts
- LOC: 35

## LinearInterestRate.sol

- Adheres to the IRateCaclulator.sol interface
- Provides logic for calculating the new interest rate as a function of utilization %
- Holds no state
- See: [Fraxlend - Advanced Concepts - Linear Rate](https://docs.frax.finance/fraxlend/advanced-concepts/interest-rates#linear-rate) for an explanation of the math
- LOC: 46

## VariableInterestRate.sol

- Adheres to the IRateCalculator interface
- Provides logic for calculating the new interest rate as a function of utilization and time
- See: [Fraxlend - Advanced Concepts - Time-Weighted Variable Rate](https://docs.frax.finance/fraxlend/advanced-concepts/interest-rates#time-weighted-variable-interest-rate) for an explanation of the math
- LOC: 40

## FraxlendWhitelist.sol

- Provides 3 whitelists:
    - RateCalculatorWhitelist - controls which calculators can be used for rate calculations
    - OracleWhitelist - controls which oracle contracts can be used for exchange rates
    - DeployerWhitelist - controls which addresses can deploy custom Fraxlend Pair instances
- LOC: 29

## FraxlendPairConstants.sol

- Defines constants and errors only
- Inherited by tests and FraxlendPairCore
- LOC: 33

## FraxlendPairCore.sol

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
    - _addInterst interacts with the configured Rate Calculator contract (adheres to IRateCalculator.sol interface)
- LOC: 642

## FraxlendPair.sol

- Contains all view functions necessary to adhere to ERC-4626
- Contains access controlled configuration functions including
- SetSwapper,
- ChangeFee
- WithdrawFees
- Pause/Unpause
- SetApprovedBorrower/Lender
- LOC: 189

## FraxlendPairDeployer.sol

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
- LOC: 252

## Total LOC: 1,318

# Contracts Included but not under review

## FraxlendPairHelper.sol

- This contract contains view functions for previewing interest accrued and updating exchange rate
- Can be helpful for predicting the effects of your transaction prior to execution


