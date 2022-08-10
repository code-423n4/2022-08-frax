// SPDX-License-Identifier: ISC
pragma solidity ^0.8.15;

import "./BasePairTest.sol";

contract InterestPairTest is BasePairTest {
    // test

    function testInterest() public {
        // Setup contracts
        defaultSetUp();

        // Test Starts
        uint256 _amountToBorrow = 16e20; // 1.5k
        uint256 _amountInPool = 15e23; // 1.5m

        // collateral is 1.5 times borrow amount
        (, uint256 _exchangeRate) = pair.exchangeRateInfo();
        uint256 _collateralAmount = (_amountToBorrow * _exchangeRate * 3) / (2 * 1e18);
        faucetFunds(asset, _amountInPool);
        faucetFunds(collateral, _collateralAmount);
        lendTokenViaDeposit(_amountInPool, users[0]);
        borrowToken(uint128(_amountToBorrow), _collateralAmount, users[2]);
        (, , , uint256 _interestRatePerSecond) = pair.currentRateInfo();
        mineOneBlock();
        pair.addInterest();
        uint256 _utilization = getUtilization();
        uint256 newInterestRate;
        IRateCalculator _rateCalculator = IRateCalculator(pair.rateContract());

        newInterestRate = interestCalculator(_rateCalculator.getConstants(), _utilization, _interestRatePerSecond, 15);

        (, , , uint256 _finalInterestRatePerSecond) = pair.currentRateInfo();
        assertEq(_finalInterestRatePerSecond, newInterestRate);
        console2.log("newInterestRate");

        // Repay all loans
        uint256 _shares = pair.userBorrowShares(users[2]);
        (uint256 amount, uint256 shares) = pair.totalBorrow();
        uint256 _amountToReturn = (_shares * amount) / shares;

        vm.startPrank(users[2]);
        asset.approve(address(pair), _amountToReturn);
        pair.repayAsset(_shares, users[2]);
        vm.stopPrank();

        mineOneBlock();
        pair.addInterest();

        (, , , uint256 _rateAfterNoBorrows) = pair.currentRateInfo();
        assertEq(_rateAfterNoBorrows, DEFAULT_INT);
        emit log("_rateAfterNoBorrows == DEFAULT_INT");
    }

    function testFeesLarge() public {
        setExternalContracts();
        startHoax(COMPTROLLER_ADDRESS);
        setWhitelistTrue();
        vm.stopPrank();

        deployFraxlendPublic(1, address(linearRateContract), defaultRateInitForLinear());
        uint256 _amountInPool = 15e23; // 1.5m
        uint256 _amountToBorrow = 16e20; // 1.5k

        _feeTest(_amountInPool, _amountToBorrow, 10000);
    }

    function testFeesSmall() public {
        setExternalContracts();
        startHoax(COMPTROLLER_ADDRESS);
        setWhitelistTrue();
        vm.stopPrank();

        deployFraxlendPublic(1, address(linearRateContract), defaultRateInitForLinear());
        uint256 _amountInPool = 15e23; // 1.5m
        uint256 _amountToBorrow = 16e20; // 1.5k

        _feeTest(_amountInPool, _amountToBorrow, 1);
    }

    function _feeTest(
        uint256 _amountToLend,
        uint256 _amountToBorrow,
        uint256 _blocksToMine
    ) public {
        faucetFunds(asset, _amountToLend);

        // Lend some shares
        lendTokenViaMint(toAssetShares(_amountToLend, false), users[2]);

        {
            // borrow some tokens
            uint256 _collateralAmount = (_amountToBorrow * pair.updateExchangeRate() * LTV_PRECISION) /
                ((pair.maxLTV()) * EXCHANGE_PRECISION);
            faucetFunds(collateral, _collateralAmount);
            borrowToken(_amountToBorrow, _collateralAmount, users[1]);
        }

        mineBlocks(_blocksToMine);
        uint256 _initialAmountAsset;
        uint256 _netSharesProtocol;
        uint256 _netAmountProtocol;
        uint256 _netAmountAsset;
        uint256 _netAmountBorrow;
        uint256 _interestEarned;
        uint256 _initialSharesAsset;
        uint256 _finalAmountAsset;
        uint256 _finalSharesAsset;
        {
            // Set initial values
            (_initialAmountAsset, _initialSharesAsset) = pair.totalAsset();
            (uint256 _initialAmountBorrow, ) = pair.totalBorrow();
            uint256 _initialSharesProtocol = pair.balanceOf(address(pair));
            uint256 _initialFeeAmountProtocol = toAssetAmount(_initialSharesProtocol, true);

            // Apply interest
            (_interestEarned, , , ) = pair.addInterest();

            // Set final values
            (_finalAmountAsset, _finalSharesAsset) = pair.totalAsset();
            (uint256 _finalAmountBorrow, ) = pair.totalBorrow();
            uint256 _finalSharesProtocol = pair.balanceOf(address(pair));
            uint256 _finalFeeAmountProtocol = toAssetAmount(_finalSharesProtocol, true);

            // Net Movements
            _netSharesProtocol = _finalSharesProtocol - _initialSharesProtocol;
            _netAmountProtocol = _finalFeeAmountProtocol - _initialFeeAmountProtocol;
            _netAmountAsset = _finalAmountAsset - _initialAmountAsset;
            _netAmountBorrow = _finalAmountBorrow - _initialAmountBorrow;
        }

        (, uint256 _feeToProtocolRate, , ) = pair.currentRateInfo();
        uint256 _initFeeAmount = (_interestEarned * _feeToProtocolRate) / FEE_PRECISION;

        uint256 _expectedProtocolShares = (_initialSharesAsset * _initFeeAmount) / (_finalAmountAsset - _initFeeAmount);
        assertEq(_interestEarned, _netAmountAsset);
        emit log("_interestEarned == _netAmountAsset");
        assertEq(_interestEarned, _netAmountBorrow);
        emit log("_interestEarned == _netAmountBorrow");
        assertApproxEqRel(_netAmountProtocol, _initFeeAmount, 1e18 / _initFeeAmount);
        emit log("_netAmountProtocol == _expectedProtocolFeesAmount");
        assertApproxEqRel(_netSharesProtocol, _expectedProtocolShares, 1e18 / _expectedProtocolShares);
        emit log("_netSharesProtocol == _expectedProtocolShares");
    }
}
