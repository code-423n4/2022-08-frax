// SPDX-License-Identifier: ISC
pragma solidity ^0.8.15;

import "../../../lib/forge-std/src/Test.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorInterface.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../contracts/FraxlendPairConstants.sol";
import "../../contracts/FraxlendPairDeployer.sol";
import "../../contracts/VariableInterestRate.sol";
import "../../contracts/LinearInterestRate.sol";
import "../../contracts/FraxlendWhitelist.sol";

contract Scenarios {
    struct Scenario {
        string assetName;
        address assetAddress;
        string collateralName;
        address collateralAddress;
        address oracleTop;
        address oracleBottom;
        uint256 oracleNormalization;
    }
    address internal constant CHAINLINK_ETH_USD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address internal constant CHAINLINK_FXS_USD = 0x6Ebc52C8C1089be9eB3945C4350B68B8E4C2233f;
    address internal constant CHAINLINK_FIL_ETH = 0x0606Be69451B1C9861Ac6b3626b99093b713E801;
    address internal constant CHAINLINK_FIL_USD = 0x1A31D42149e82Eb99777f903C08A2E41A00085d3;
    address internal constant CHAINLINK_MKR_ETH = 0x24551a8Fb2A7211A25a17B1481f043A8a8adC7f2;
    address internal constant CHAINLINK_MKR_USD = 0xec1D1B3b0443256cc3860e24a46F108e699484Aa;
    address internal constant FIL_ERC20 = 0xB8B01cec5CEd05C457654Fc0fda0948f859883CA;
    address internal constant MKR_ERC20 = 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2;

    function getScenarios() public returns (Scenario[] memory _scenarios) {
        _scenarios = new Scenario[](5);
        _scenarios[0] = Scenario({
            assetName: "FRAX",
            assetAddress: 0x853d955aCEf822Db058eb8505911ED77F175b99e,
            collateralName: "WETH",
            collateralAddress: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            oracleTop: address(0),
            oracleBottom: CHAINLINK_ETH_USD, // ETH/USD Feed USD::ETH,
            oracleNormalization: 1e10
        });
        _scenarios[1] = Scenario({
            assetName: "FXS",
            assetAddress: 0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0,
            collateralName: "FRAX",
            collateralAddress: 0x853d955aCEf822Db058eb8505911ED77F175b99e,
            oracleTop: CHAINLINK_FXS_USD, // FXS/USD Feed USD::FXS
            oracleBottom: address(0),
            oracleNormalization: 1e26
        });
        _scenarios[2] = Scenario({
            assetName: "FXS",
            assetAddress: 0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0,
            collateralName: "MKR",
            collateralAddress: MKR_ERC20,
            oracleTop: CHAINLINK_MKR_USD, // MKR/USD Feed USD::MKR
            oracleBottom: CHAINLINK_FXS_USD, // FXS/USD Feed USD::FXS
            oracleNormalization: 1e18
        });
        _scenarios[3] = Scenario({
            assetName: "FIL",
            assetAddress: FIL_ERC20,
            collateralName: "MKR",
            collateralAddress: MKR_ERC20,
            oracleTop: CHAINLINK_MKR_ETH, // MKR/ETH Feed ETH::MKR
            oracleBottom: CHAINLINK_FIL_ETH, // FIL/ETH Feed ETH::FIL
            oracleNormalization: 1e18
        });
        _scenarios[4] = Scenario({
            assetName: "FRAX",
            assetAddress: 0xB8B01cec5CEd05C457654Fc0fda0948f859883CA,
            collateralName: "MKR",
            collateralAddress: MKR_ERC20,
            oracleTop: CHAINLINK_MKR_ETH, // MKR/ETH Feed ETH::MKR
            oracleBottom: CHAINLINK_MKR_USD, // MKR/USD Feed USD::MKR
            oracleNormalization: 1e28
        });
    }
}
