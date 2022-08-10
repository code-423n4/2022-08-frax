// SPDX-License-Identifier: ISC
pragma solidity ^0.8.15;

import "./BasePairTest.sol";

contract LiquidatePairTest is BasePairTest {
    using OracleHelper for AggregatorV3Interface;

    function testLiquidate() public {
        // Setup contracts
        defaultSetUp();
        // Sets price to 3200 USD per ETH

        uint256 _amountToBorrow = 16e20; // 1.5k
        uint256 _amountInPool = 15e23; // 1.5m

        // collateral is 1.5 times borrow amount
        oracleDivide.setPrice(3200, 1, vm);
        mineBlocks(1);
        (, uint256 _exchangeRate) = pair.exchangeRateInfo();
        uint256 _collateralAmount = (_amountToBorrow * _exchangeRate * 3) / (2 * 1e18);
        faucetFunds(asset, _amountInPool);
        faucetFunds(collateral, _collateralAmount);
        lendTokenViaDeposit(_amountInPool, users[0]);
        borrowToken(uint128(_amountToBorrow), _collateralAmount, users[2]);
        uint256 mxltv = pair.maxLTV();
        uint256 liquidationFee = pair.liquidationFee();
        uint256 liquidation_price = ((((1e18 / _exchangeRate) * mxltv) / 1e5) * (1e5 + liquidationFee)) / 1e5;
        oracleDivide.setPrice(liquidation_price, 1, vm);
        mineBlocks(1);
        uint256 _shares = pair.userBorrowShares(users[2]);
        for (uint256 i = 0; i < 1; i++) {
            pair.addInterest();
            mineOneBlock();
        }
        vm.startPrank(users[1]);
        pair.addInterest();
        asset.approve(address(pair), toBorrowAmount(_shares, true));
        pair.liquidate(_shares, users[2]);
        assertEq(pair.userBorrowShares(users[2]), 0);
        vm.stopPrank();
    }

    function testCannotLiquidateWhenSolvent() public {
        // Setup contracts
        defaultSetUp();
        uint256 _amountToBorrow = 16e20; // 1.5k
        uint256 _amountInPool = 15e23; // 1.5m

        // collateral is 1.5 times borrow amount
        (, uint256 _exchangeRate) = pair.exchangeRateInfo();
        uint256 _collateralAmount = (_amountToBorrow * _exchangeRate * 3) / (2 * 1e18);
        faucetFunds(asset, _amountInPool);
        faucetFunds(collateral, _collateralAmount);
        lendTokenViaDeposit(_amountInPool, users[0]);
        borrowToken(uint128(_amountToBorrow), _collateralAmount, users[2]);
        uint256 _shares = pair.userBorrowShares(users[2]);
        for (uint256 i = 0; i < 100; i++) {
            pair.addInterest();
            mineOneBlock();
        }
        vm.startPrank(users[1]);
        pair.addInterest();
        asset.approve(address(pair), toBorrowAmount(_shares, true));
        vm.expectRevert(FraxlendPairConstants.BorrowerSolvent.selector);
        pair.liquidate(_shares, users[2]);
        vm.stopPrank();
        // assertEq(pair.userBorrowShares(users[2]), 0);
    }

    function testCannotLiquidateWhenCollateralCannotCover() public {
        // Setup contracts
        defaultSetUp();

        // Test Starts
        uint256 _amountToBorrow = 12e23; // 1.2m
        uint256 _amountInPool = 15e23; // 1.5m
        mineOneBlock();
        oracleDivide.setPrice(3200, 1, vm);
        mineOneBlock();

        // collateral is 1.5 times borrow amount
        uint256 _exchangeRate = pair.updateExchangeRate();
        uint256 _collateralAmount = (_amountToBorrow * _exchangeRate * 3) / (2 * 1e18);
        faucetFunds(asset, _amountInPool);
        faucetFunds(collateral, _collateralAmount);
        lendTokenViaDeposit(_amountInPool, users[0]);
        borrowToken(uint128(_amountToBorrow), _collateralAmount, users[2]);
        oracleDivide.setPrice(500, 1, vm);
        mineOneBlock();
        uint256 _shares = pair.userBorrowShares(users[2]);
        addInterestAndMineBulk(100);
        vm.startPrank(users[1]);
        pair.addInterest();
        asset.approve(address(pair), toBorrowAmount(_shares, true));
        vm.expectRevert(stdError.arithmeticError);
        pair.liquidate(_shares, users[2]);
        vm.stopPrank();
        // assertEq(pair.userBorrowShares(users[2]), 0);
    }
}
