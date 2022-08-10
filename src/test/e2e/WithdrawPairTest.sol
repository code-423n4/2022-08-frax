// SPDX-License-Identifier: ISC
pragma solidity ^0.8.15;
import "./BasePairTest.sol";

contract WithdrawPairTest is BasePairTest {
    // test
    function testWithdrawLoanViaRedeem() public {
        // Setup contracts
        defaultSetUp();

        // Test Starts
        uint128 _amountToBorrow = 15e20; // 1.5k
        uint128 _amountInPool = 15e23; // 1.5m

        // collateral is 1.5 times borrow
        (, uint256 _exchangeRate) = pair.exchangeRateInfo();
        uint256 _collateralAmount = (_amountToBorrow * _exchangeRate * 3) / (2 * 1e18);

        // Add assets to all users equal to amountInPool
        faucetFunds(asset, _amountInPool);

        // add collateral to all users equalt to collateral amount
        faucetFunds(collateral, _collateralAmount);

        // Fill the pool
        uint256 _lenderShares = lendTokenViaDeposit(_amountInPool, users[0]);

        // Borrow
        (uint256 _borrowShares, ) = borrowToken(_amountToBorrow, _collateralAmount, users[2]);

        // Simulate a lot of time passing
        vm.warp(block.timestamp + 50000);
        vm.roll(block.number + 1);
        (uint256 _interestEarned, , , ) = pair.addInterest();

        // Repay borrows
        repayToken(_borrowShares, users[2]);

        // Lender withdraws
        uint256 _initialBalance = asset.balanceOf(users[0]);
        vm.startPrank(users[0]);
        pair.redeem(_lenderShares, users[0], users[0]);
        uint256 _finalBalance = asset.balanceOf(users[0]);
        uint256 _diffBalance = _finalBalance - _initialBalance;
        uint256 _sharesAsFees = toAssetAmount(pair.balanceOf(address(pair)), true);
        uint256 _expectedRepayment = _amountInPool + _interestEarned - _sharesAsFees; // Account for Fees
        assertEq(_diffBalance, _expectedRepayment);
        emit log("_diffBalance == _expectedRepayment");
        vm.stopPrank();
    }

    function testWithdrawLoanViaWithdraw() public {
        // Setup contracts
        defaultSetUp();

        // Test Starts
        uint128 _amountToBorrow = 15e20; // 1.5k
        uint128 _amountInPool = 15e23; // 1.5m

        // collateral is 1.5 times borrow
        (, uint256 _exchangeRate) = pair.exchangeRateInfo();
        uint256 _collateralAmount = (_amountToBorrow * _exchangeRate * 3) / (2 * 1e18);

        // Add assets to all users equal to amountInPool
        faucetFunds(asset, _amountInPool, users[0]);
        faucetFunds(asset, _amountInPool, users[2]);

        // add collateral to all users equalt to collateral amount
        faucetFunds(collateral, _collateralAmount, users[2]);

        // Fill the pool
        uint256 _lenderShares = lendTokenViaDeposit(_amountInPool, users[0]);

        // Borrow
        (uint256 _borrowShares, ) = borrowToken(_amountToBorrow, _collateralAmount, users[2]);

        // Simulate a lot of time passing
        vm.warp(block.timestamp + 50000);
        vm.roll(block.number + 1);
        (uint256 _interestEarned, , , ) = pair.addInterest();

        // Repay borrows
        repayToken(_borrowShares, users[2]);

        // Lender withdraws
        uint256 _initialBalance = asset.balanceOf(users[0]);
        vm.startPrank(users[0]);
        uint256 _lenderAmount = pair.convertToAssets(_lenderShares);
        mineOneBlock();
        pair.withdraw(_lenderAmount, users[0], users[0]);
        uint256 _finalBalance = asset.balanceOf(users[0]);
        uint256 _diffBalance = _finalBalance - _initialBalance;
        uint256 _sharesAsFees = toAssetAmount(pair.balanceOf(address(pair)), true);
        uint256 _expectedRepayment = _amountInPool + _interestEarned - _sharesAsFees; // Account for Fees
        assertEq(_diffBalance, _expectedRepayment);
        emit log("_diffBalance == _expectedRepayment");
        vm.stopPrank();
    }
}
