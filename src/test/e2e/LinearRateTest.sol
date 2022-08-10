// SPDX-License-Identifier: ISC
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./BasePairTest.sol";
import "../../contracts/LinearInterestRate.sol";

contract LinearRateTest is VariableInterestRate, BasePairTest {
    using Strings for uint256;

    function testLinearRate() public {
        setExternalContracts();
        bytes memory _initData = defaultRateInitForLinear();
        _testLinearInitData(_initData);
    }

    function testZeroLinearRate() public {
        setExternalContracts();
        uint256 _minInterest = 0;
        uint256 _vertexInterest = 0;
        uint256 _maxInterest = 1e9;
        uint256 _vertexUtilization = 8000; // 80% w/ 1e5 precision

        bytes memory _initData = abi.encode(_minInterest, _vertexInterest, _maxInterest, _vertexUtilization);
        _testLinearInitData(_initData);
    }

    function testVertexEqualMaxLinearRate() public {
        setExternalContracts();
        uint256 _minInterest = 3000;
        uint256 _vertexInterest = 4000;
        uint256 _maxInterest = 4000;
        uint256 _vertexUtilization = 8000; // 80% w/ 1e5 precision

        bytes memory _initData = abi.encode(_minInterest, _vertexInterest, _maxInterest, _vertexUtilization);
        _testLinearInitData(_initData);
    }

    function _testLinearInitData(bytes memory _initData) public {
        (uint256 _minInterest, uint256 _vertexInterest, uint256 _maxInterest, uint256 _vertexUtilization) = abi.decode(
            _initData,
            (uint256, uint256, uint256, uint256)
        );

        // 0 utilization case, expects minInterest
        assertApproxEqRel(_getNewRate(0, _initData), _minInterest, 1e13);
        emit log("assertApproxEqRel(_getNewRate(0, _initData), _minInterest, 1e13)");

        // vertex Utilization expects vertex Interest
        assertApproxEqRel(_getNewRate(_vertexUtilization, _initData), _vertexInterest, 1e13);
        emit log("assertApproxEqRel(_getNewRate(_vertexUtilization, _initData), _vertexInterest, 1e13)");

        // maxUtilization Case, expects max interest
        assertApproxEqRel(_getNewRate(1e5, _initData), _maxInterest, 1e13);
        emit log("assertApproxEqRel(_getNewRate(1e5, _initData), _maxInterest, 1e13)");

        // halfway between vertex and 0 utilization, expects half of the rate between vertex and mininimum interest
        assertApproxEqRel(
            _getNewRate(_vertexUtilization / 2, _initData),
            _minInterest + ((_vertexInterest - _minInterest) / 2),
            1e13
        );
        emit log(
            "halfway between vertex and 0 utilization, expects half of the rate between vertex and mininimum interest"
        );

        // halfway between vertex and max utilization, expects half of the rate plus vertex interest
        assertApproxEqRel(
            _getNewRate(((1e5 - _vertexUtilization) / 2) + _vertexUtilization, _initData),
            _vertexInterest + ((_maxInterest - _vertexInterest) / 2),
            1e13
        );
        emit log("halfway between vertex and max utilization, expects half of the rate plus vertex interest");
    }

    function _getNewRate(uint256 _utilization, bytes memory _initData) public view returns (uint256 _newRate) {
        _newRate = linearRateContract.getNewRate(abi.encode(0, 0, _utilization, 0), _initData);
    }
}
