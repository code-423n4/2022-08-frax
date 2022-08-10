// SPDX-License-Identifier: ISC
pragma solidity ^0.8.15;

import "./BasePairTest.sol";

contract LendPairTest is BasePairTest {
    // test
    function testlendTokenViaDeposit() public {
        // Setup contracts
        defaultSetUp();

        // Test Starts
        uint256 _amountToLend = 2e21; // 2k
        faucetFunds(asset, _amountToLend);
        uint256 _balanceOfUser = lendTokenViaDeposit(_amountToLend, users[0]);

        // Check total
        (uint256 _amount, uint256 _shares) = pair.totalAsset();
        assertEq(_amount, _amountToLend);
        emit log("_amount == _amountToLend");

        //Check utilization
        uint256 _utilization = getUtilization();
        assertEq(_utilization, 0);
        emit log("_utilization == 0");

        // Check user totals
        assertEq(_balanceOfUser, _amount);
        emit log("_balanceOfUser == _amount");
    }

    function testlendTokenViaMint() public {
        // Setup contracts
        defaultSetUp();

        // Test Starts
        uint256 _amountToLend = 2e21; // 2k
        faucetFunds(asset, _amountToLend);
        uint256 _sharesToLend = pair.convertToShares(_amountToLend);
        uint256 _balanceOfUser = lendTokenViaMint(_sharesToLend, users[0]);

        // Check total
        (uint256 _amount, uint256 _shares) = pair.totalAsset();
        assertEq(_amount, 2e21);

        //Check utilization
        uint256 _utilization = getUtilization();
        assertEq(_utilization, 0);

        // Check user totals
        assertEq(_balanceOfUser, _amount);
    }

    function testCannotlendTokenViaDepositIfNotOnWhitelist() public {
        // Setup
        setExternalContracts();
        startHoax(COMPTROLLER_ADDRESS);
        setWhitelistTrue();
        vm.stopPrank();

        address[] memory approvedBorrowers = new address[](1);
        address[] memory approvedLenders = new address[](1);
        approvedBorrowers[0] = users[3];
        approvedLenders[0] = users[1];
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

        // Test
        uint256 _amountToLend = 2e21; // 2k
        faucetFunds(asset, _amountToLend);
        startHoax(users[3]);
        vm.expectRevert(FraxlendPairConstants.OnlyApprovedLenders.selector);
        pair.deposit(_amountToLend, users[0]);
        vm.stopPrank();
    }
}
