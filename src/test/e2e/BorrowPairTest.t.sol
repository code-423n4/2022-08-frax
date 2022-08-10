// SPDX-License-Identifier: ISC
pragma solidity ^0.8.15;

import "./BasePairTest.sol";

contract BorrowPairTest is BasePairTest {
    using OracleHelper for AggregatorV3Interface;

    function _borrowTest(
        uint256 _targetLTV,
        uint256 _amountToBorrow,
        uint256 _amountInPool
    ) internal {
        // Lend funds
        faucetFunds(asset, _amountInPool, users[0]);
        lendTokenViaDeposit(_amountInPool, users[0]);

        // Borrow tokens and use collateral value of 1.5 times borrow value
        uint256 _initialBalance = asset.balanceOf(users[2]);
        uint256 _collateralAmount = (_amountToBorrow * exchangeRate(pair) * LTV_PRECISION) /
            (_targetLTV * EXCHANGE_PRECISION);
        faucetFunds(collateral, _collateralAmount, users[2]);
        borrowToken(_amountToBorrow, _collateralAmount, users[2]);
        uint256 _finalBalance = asset.balanceOf(users[2]);

        // Check total borrow amounts
        (uint128 _amount, uint128 _shares) = pair.totalBorrow();
        assertEq(_amountToBorrow, _amount);
        assertEq(_shares, _amountToBorrow); // shares shold be equal because it is the first borrow
        emit log("Check total borrow amounts");

        // Check user borrow shares
        assertEq(_finalBalance - _initialBalance, _amountToBorrow);
        emit log("Check user borrow shares");

        // Check utilization
        uint256 _utilization = getUtilization();
        assertEq(_utilization, (_amountToBorrow * UTIL_PREC) / _amountInPool);
        emit log("Check utilization");
    }

    function testFuzzyMaxLTVBorrowToken(uint64 _maxLTV) public {
        _maxLTV = _maxLTV % (1e8 + 1);
        _maxLTV = _maxLTV == 0 ? _maxLTV + 1 : _maxLTV;

        startHoax(COMPTROLLER_ADDRESS);
        deployNonDynamicExternalContracts();
        vm.stopPrank();
        (uint256 MIN_INT, uint256 MAX_INT, uint256 MAX_VERTEX_UTIL, uint256 UTIL_PREC) = abi.decode(
            linearRateContract.getConstants(),
            (uint256, uint256, uint256, uint256)
        );
        _fuzzySetupBorrowToken(
            MIN_INT,
            (MIN_INT + (MAX_INT / 1000)) / 2,
            MAX_INT / 1000, // 10,000% ÷ 1000 = 10%
            (80 * UTIL_PREC) / 100, // 80%
            _maxLTV,
            DEFAULT_LIQ_FEE,
            1468e8, // 1e8 precision
            300e6 // 1e8 precision
        );
    }

    function _fuzzySetupBorrowToken(
        uint256 _minInterest,
        uint256 _vertexInterest,
        uint256 _maxInterest,
        uint256 _vertexUtilization,
        uint256 _maxLTV,
        uint256 _liquidationFee,
        uint256 _priceTop,
        uint256 _priceDiv
    ) public {
        asset = IERC20(FIL_ERC20);
        collateral = IERC20(MKR_ERC20);
        oracleMultiply = AggregatorV3Interface(CHAINLINK_MKR_ETH);
        oracleMultiply.setPrice(_priceTop, 1e8, vm);
        oracleDivide = AggregatorV3Interface(CHAINLINK_FIL_ETH);
        oracleDivide.setPrice(_priceDiv, 1e8, vm);
        uint256 _oracleNormalization = 1e18;
        (address _rateContract, bytes memory _rateInitData) = fuzzyRateCalculator(
            2,
            _minInterest,
            _vertexInterest,
            _maxInterest,
            _vertexUtilization
        );
        startHoax(COMPTROLLER_ADDRESS);
        setWhitelistTrue();
        vm.stopPrank();

        address[] memory _borrowerWhitelist = _maxLTV >= LTV_PRECISION ? users : new address[](0);
        address[] memory _lenderWhitelist = _maxLTV >= LTV_PRECISION ? users : new address[](0);

        deployFraxlendCustom(
            _oracleNormalization,
            _rateContract,
            _rateInitData,
            _maxLTV,
            _liquidationFee,
            block.timestamp + 30 days,
            1000 * DEFAULT_INT,
            _borrowerWhitelist,
            _lenderWhitelist
        );
        pair.updateExchangeRate();
        _borrowTest(_maxLTV, 15e20, 15e23);
    }

    function testBorrowToken() public {
        // Setup contracts
        defaultSetUp();
        _borrowTest(DEFAULT_MAX_LTV, 15e20, 15e23);
    }

    function testBorrowTokenFuzz(uint128 _amountToBorrow, uint128 _amountInPool) public {
        _amountToBorrow = _amountToBorrow < 1e18 ? _amountToBorrow + 1e18 : _amountToBorrow;
        _amountInPool = _amountInPool < 1e18 ? _amountInPool + 1e18 : _amountToBorrow;
        vm.assume(_amountInPool < type(uint128).max);
        vm.assume(_amountInPool > _amountToBorrow);

        // Setup contracts
        defaultSetUp();

        _borrowTest(6667, _amountToBorrow, _amountInPool);
    }

    function testCannotBorrowTokenIfNotOnBorowWhitelist() public {
        // Setup
        setExternalContracts();
        startHoax(COMPTROLLER_ADDRESS);
        setWhitelistTrue();
        vm.stopPrank();

        address[] memory approvedBorrowers = new address[](1);
        address[] memory approvedLenders = new address[](1);
        approvedBorrowers[0] = users[3];
        approvedLenders[0] = users[0];
        deployFraxlendCustom(
            1e10,
            address(variableRateContract),
            abi.encode(),
            DEFAULT_MAX_LTV,
            DEFAULT_LIQ_FEE,
            block.timestamp + 10 days,
            1000 * DEFAULT_INT,
            approvedBorrowers,
            approvedLenders
        );

        // Test Starts
        uint128 _amountToBorrow = 15e20; // 1.5k
        uint128 _amountInPool = 15e23; // 1.5m
        // collateral is 1.5 times borrow
        uint256 _collateralAmount = (_amountToBorrow * exchangeRate(pair) * 3) / (2 * EXCHANGE_PRECISION);
        faucetFunds(asset, _amountInPool);
        faucetFunds(collateral, _collateralAmount);
        lendTokenViaDeposit(_amountInPool, users[0]);
        startHoax(users[2]);
        vm.expectRevert(FraxlendPairConstants.OnlyApprovedBorrowers.selector);
        pair.borrowAsset(uint128(_amountToBorrow), _collateralAmount, users[2]);
        vm.stopPrank();
    }
}
