// SPDX-License-Identifier: ISC
pragma solidity ^0.8.15;

import "./BasePairTest.sol";
import "../interfaces/IUniswapV2Router02.sol";
import "../interfaces/UniswapV2Library.sol";

contract LiquidatePairTest is BasePairTest {
    function testLeverageAndDeleverage() public {
        // Override setup
        setExternalContracts();
        asset = IERC20(FRAX_ERC20);
        collateral = IERC20(WETH_ERC20);

        IUniswapV2Router02 _uniV2Router = IUniswapV2Router02(UNIV2_ROUTER);
        address _factory = _uniV2Router.factory();
        (address _token0, ) = UniswapV2Library.sortTokens(address(asset), address(collateral));
        (uint256 _reserves0, uint256 _reserves1) = UniswapV2Library.getReserves(
            _factory,
            address(asset),
            address(collateral)
        );

        oracleDivide = AggregatorV3Interface(CHAINLINK_ETH_USD); // USD :: WETH
        startHoax(COMPTROLLER_ADDRESS);
        setWhitelistTrue();
        vm.stopPrank();

        deployFraxlendPublic(1e10, address(variableRateContract), abi.encode());

        uint256 _uniPrice = _token0 == address(asset)
            ? (_reserves1 * 1e18) / _reserves0
            : (_reserves0 * 1e18) / _reserves1;
        uint256 _exchangeRate = pair.updateExchangeRate();
        // Start Test
        uint256 _amountToBorrow = 2e20; // 0.6k
        uint256 _amountInPool = 15e23; // 1.5m
        uint256 _targetLTV = 65e16; // Target LTV is 75%
        uint256 _targetLeverage = (_targetLTV * 1e18) / (1e18 - _targetLTV);
        uint256 _maxSlippage = 98e16; // Max Slippage 90%

        uint256 _initialCollateral = (_amountToBorrow * _exchangeRate) / _targetLeverage;
        uint256 _amountCollateralOutMin = (_amountToBorrow * _uniPrice * _maxSlippage) / (1e36);
        address[] memory _path2 = new address[](2);
        _path2[0] = address(pair.asset());
        _path2[1] = address(pair.collateralContract());

        faucetFunds(asset, _amountInPool);
        faucetFunds(collateral, _initialCollateral);
        lendTokenViaDeposit(_amountInPool, users[0]);
        vm.startPrank(users[1]);
        uint256 _initialCollateralBalance = pair.userCollateralBalance(users[1]);
        uint256 _initialBorrowShares = pair.userBorrowShares(users[1]);
        collateral.approve(address(pair), _initialCollateral);
        pair.leveragedPosition(UNIV2_ROUTER, _amountToBorrow, _initialCollateral, _amountCollateralOutMin, _path2);
        uint256 _finalCollateral = pair.userCollateralBalance(users[1]);
        uint256 _finalBorrowShares = pair.userBorrowShares(users[1]);
        assertEq(_finalBorrowShares - _initialBorrowShares, toBorrowShares(_amountToBorrow, true));
        assertGt(_finalCollateral - _initialCollateralBalance, _initialCollateral + _amountCollateralOutMin);

        // deleverageTest();
    }

    function deleverageTest() public {
        (, uint256 _exchangeRate) = pair.exchangeRateInfo();

        uint256 _idealCollateral2 = pair.userCollateralBalance(users[1]) / 2;
        uint256 _amountAssetOutMin = (_idealCollateral2 * 85) / (100 * _exchangeRate);
        address[] memory _path = new address[](2);
        _path[0] = address(collateral);
        _path[1] = address(asset);

        uint256 _initialBorrowAmount = pair.assetsPerShare() * pair.userBorrowShares(users[1]);
        uint256 _initialCollateralAmount = pair.userCollateralBalance(users[1]);

        pair.repayAssetWithCollateral(UNIV2_ROUTER, _idealCollateral2, _amountAssetOutMin, _path);
        uint256 _finalBorrowAmount = pair.assetsPerShare() * pair.userBorrowShares(users[1]);
        uint256 _finalCollateralAmount = pair.userCollateralBalance(users[1]);

        assertGt(_initialBorrowAmount - _finalBorrowAmount, _amountAssetOutMin);
        assertEq(_initialCollateralAmount - _finalCollateralAmount, _idealCollateral2);
    }
}
