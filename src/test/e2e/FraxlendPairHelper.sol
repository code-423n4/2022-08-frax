// SPDX-License-Identifier: ISC
pragma solidity ^0.8.15;

import "./BasePairTest.sol";

contract FraxlendPairHelperTest is BasePairTest {
    function testPreviewInterestRate() public {
        // Default setup
        defaultSetUp();

        // Create some configs with high utilization
        uint128 _amountToBorrow = 14e23; // 1.4m
        uint128 _amountInPool = 15e23; // 1.5m

        // Lend a bit
        // collateral is 1.5 times borrow
        faucetFunds(asset, _amountInPool, users[0]);
        lendTokenViaDeposit(_amountInPool, users[0]);

        // Borrow a bit
        uint256 _targetLTV = 70e5 / 100; // 70% 1e5 precision
        uint256 _collateralAmount = (_amountToBorrow * exchangeRate(pair) * LTV_PRECISION) /
            (_targetLTV * EXCHANGE_PRECISION);
        faucetFunds(collateral, _collateralAmount, users[2]);
        borrowToken(_amountToBorrow, _collateralAmount, users[2]);

        // mine 10k blocks to generate some interest accrual
        mineBlocks(10000);

        (
            uint256 _interestEarnedPreview,
            uint256 _feesAmountPreview,
            uint256 _feesSharePreview,
            uint256 _newRatePreview
        ) = fraxlendPairHelper.previewRateInterestFees(address(pair), block.timestamp, block.number);
        (uint256 _interestEarned, uint256 _feesAmount, uint256 _feesShare, uint64 _newRate) = pair.addInterest();
        assertEq(_interestEarnedPreview, _interestEarned);
        emit log("_interestEarnedPreview == _interestEarned");
        assertEq(_feesAmountPreview, _feesAmount);
        emit log("_feesAmountPreview == _feesAmount");
        assertEq(_feesSharePreview, _feesShare);
        emit log("_feesSharePreview == _feesShare");
        assertEq(_newRatePreview, _newRate);
        emit log("_newRatePreview == _newRate");
    }
}
