// SPDX-License-Identifier: ISC
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./BasePairTest.sol";
import "../../contracts/VariableInterestRate.sol";

contract VariableRateTest is VariableInterestRate, BasePairTest {
    using Strings for uint256;

    // Actual Fuzzer
    function testFuzzyVariableRate(
        uint64 _currentRatePerSec,
        uint16 _deltaTime,
        uint32 _utilization
    ) public {
        _testFuzzyVariableRate(_currentRatePerSec, _deltaTime, _utilization);
    }

    // normalize the fuzzed variables
    function _testFuzzyVariableRate(
        uint64 _currentRatePerSec,
        uint16 _deltaTime,
        uint32 _utilization
    ) public {
        _utilization = (_utilization % 1e5) + 1;
        vm.assume(_deltaTime > 0);
        variableRateContract = new VariableInterestRate();
        (
            uint32 MIN_UTIL,
            uint32 MAX_UTIL,
            uint32 UTIL_PREC,
            uint64 MIN_INT,
            uint64 MAX_INT,
            uint256 INT_HALF_LIFE
        ) = abi.decode(variableRateContract.getConstants(), (uint32, uint32, uint32, uint64, uint64, uint256));
        _currentRatePerSec = uint64((uint256(_currentRatePerSec) + MIN_INT) % MAX_INT);
        _testVariableRate(_currentRatePerSec, _deltaTime, _utilization);
    }

    function testVariableRate() public {
        _testFuzzyVariableRate(0, 1, 0);
    }

    // testVariableRate
    function _testVariableRate(
        uint64 _currentRatePerSec,
        uint16 _deltaTime,
        uint32 _utilization
    ) public {
        uint256 _newRate = this.getNewRate(abi.encode(_currentRatePerSec, _deltaTime, _utilization, 0), abi.encode());

        string[] memory _inputs = new string[](5);
        _inputs[0] = "node";
        _inputs[1] = "src/test/utils/variableInterestRateCalculator.js";
        _inputs[2] = uint256(_currentRatePerSec).toString();
        _inputs[3] = uint256(_deltaTime).toString();
        _inputs[4] = uint256(_utilization).toString();
        bytes memory _ret = vm.ffi(_inputs);
        uint256 _base = 5000001;
        assertApproxEqRel(_base, 5000000, 1e18 / 5000000);
        assertApproxEqRel(abi.decode(_ret, (uint256)), uint256(_newRate), 1e18 / uint256(_newRate));
    }

    function testFailRelativeAssertionCheck() public {
        // this test proves the validity of 1e18 / minValue creating a 1 wei relative buffer
        uint256 _base = 5000002;
        assertApproxEqRel(_base, 5000000, 1e18 / 5000000);
    }
}
