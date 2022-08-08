// SPDX-License-Identifier: ISC
pragma solidity ^0.8.15;

// ====================================================================
// |     ______                   _______                             |
// |    / _____________ __  __   / ____(_____  ____ _____  ________   |
// |   / /_  / ___/ __ `| |/_/  / /_  / / __ \/ __ `/ __ \/ ___/ _ \  |
// |  / __/ / /  / /_/ _>  <   / __/ / / / / / /_/ / / / / /__/  __/  |
// | /_/   /_/   \__,_/_/|_|  /_/   /_/_/ /_/\__,_/_/ /_/\___/\___/   |
// |                                                                  |
// ====================================================================
// ========================== FraxlendPair ============================
// ====================================================================
// Frax Finance: https://github.com/FraxFinance

// Primary Author
// Drake Evans: https://github.com/DrakeEvans

// Reviewers
// Dennis: https://github.com/denett
// Sam Kazemian: https://github.com/samkazemian
// Travis Moore: https://github.com/FortisFortuna
// Jack Corddry: https://github.com/corddry
// Rich Gee: https://github.com/zer0blockchain

// ====================================================================

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./FraxlendPairConstants.sol";
import "./FraxlendPairCore.sol";
import "./libraries/VaultAccount.sol";
import "./libraries/SafeERC20.sol";
import "./interfaces/IERC4626.sol";
import "./interfaces/IFraxlendWhitelist.sol";
import "./interfaces/IRateCalculator.sol";
import "./interfaces/ISwapper.sol";

contract FraxlendPair is FraxlendPairCore {
    using VaultAccountingLibrary for VaultAccount;
    using SafeERC20 for IERC20;

    constructor(
        bytes memory _configData,
        bytes memory _immutables,
        uint256 _maxLTV,
        uint256 _liquidationFee,
        uint256 _maturityDate,
        uint256 _penaltyRate,
        bool _isBorrowerWhitelistActive,
        bool _isLenderWhitelistActive
    )
        FraxlendPairCore(
            _configData,
            _immutables,
            _maxLTV,
            _liquidationFee,
            _maturityDate,
            _penaltyRate,
            _isBorrowerWhitelistActive,
            _isLenderWhitelistActive
        )
        ERC20("", "")
        Ownable()
        Pausable()
    {}

    // ============================================================================================
    // ERC20 Metadata
    // ============================================================================================

    function name() public view override(ERC20, IERC20Metadata) returns (string memory) {
        return nameOfContract;
    }

    function symbol() public view override(ERC20, IERC20Metadata) returns (string memory) {
        // prettier-ignore
        // solhint-disable-next-line max-line-length
        return string(abi.encodePacked("FraxlendV1 - ", collateralContract.safeSymbol(), "/", assetContract.safeSymbol()));
    }

    function decimals() public pure override(ERC20, IERC20Metadata) returns (uint8) {
        return 18;
    }

    // totalSupply for fToken ERC20 compatibility
    function totalSupply() public view override(ERC20, IERC20) returns (uint256) {
        return totalAsset.shares;
    }

    // ============================================================================================
    // ERC4626 Views
    // ============================================================================================
    function asset() external view returns (address) {
        return address(assetContract);
    }

    function totalAssets() public view virtual returns (uint256) {
        return totalAsset.amount;
    }

    function assetsPerShare() external view returns (uint256 _assetsPerUnitShare) {
        _assetsPerUnitShare = totalAsset.toAmount(1e18, false);
    }

    function assetsOf(address _depositor) external view returns (uint256 _assets) {
        _assets = totalAsset.toAmount(balanceOf(_depositor), false);
    }

    function convertToShares(uint256 _amount) external view returns (uint256) {
        return totalAsset.toShares(_amount, false);
    }

    function convertToAssets(uint256 _shares) external view returns (uint256) {
        return totalAsset.toAmount(_shares, false);
    }

    function previewDeposit(uint256 _amount) external view returns (uint256) {
        return totalAsset.toShares(_amount, false);
    }

    function previewMint(uint256 _shares) external view returns (uint256) {
        return totalAsset.toAmount(_shares, true);
    }

    function previewWithdraw(uint256 _amount) external view returns (uint256) {
        return totalAsset.toShares(_amount, true);
    }

    function previewRedeem(uint256 _shares) external view returns (uint256) {
        return totalAsset.toAmount(_shares, false);
    }

    function maxDeposit(address) external pure returns (uint256) {
        return type(uint128).max;
    }

    function maxMint(address) external pure returns (uint256) {
        return type(uint128).max;
    }

    function maxWithdraw(address owner) external view returns (uint256) {
        return totalAsset.toAmount(balanceOf(owner), false);
    }

    function maxRedeem(address owner) external view returns (uint256) {
        return balanceOf(owner);
    }

    // ============================================================================================
    // Functions: Helpers
    // ============================================================================================

    function getConstants()
        external
        pure
        returns (
            uint256 _LTV_PRECISION,
            uint256 _LIQ_PRECISION,
            uint256 _UTIL_PREC,
            uint256 _FEE_PRECISION,
            uint256 _EXCHANGE_PRECISION,
            uint64 _DEFAULT_INT,
            uint16 _DEFAULT_PROTOCOL_FEE,
            uint256 _MAX_PROTOCOL_FEE
        )
    {
        _LTV_PRECISION = LTV_PRECISION;
        _LIQ_PRECISION = LIQ_PRECISION;
        _UTIL_PREC = UTIL_PREC;
        _FEE_PRECISION = FEE_PRECISION;
        _EXCHANGE_PRECISION = EXCHANGE_PRECISION;
        _DEFAULT_INT = DEFAULT_INT;
        _DEFAULT_PROTOCOL_FEE = DEFAULT_PROTOCOL_FEE;
        _MAX_PROTOCOL_FEE = MAX_PROTOCOL_FEE;
    }

    function toBorrowShares(uint256 _amount, bool _roundUp) external view returns (uint256) {
        return totalBorrow.toShares(_amount, _roundUp);
    }

    function toBorrowAmount(uint256 _shares, bool _roundUp) external view returns (uint256) {
        return totalBorrow.toAmount(_shares, _roundUp);
    }

    // ============================================================================================
    // Functions: Protocol Configuration (Fees & Swap Contracts)
    // ============================================================================================
    event SetTimeLock(address _newAddress);

    function setTimeLock(address _newAddress) external onlyOwner {
        TIME_LOCK_ADDRESS = _newAddress;
        emit SetTimeLock(_newAddress);
    }

    event ChangeFee(uint32 _newFee);

    function changeFee(uint32 _newFee) external whenNotPaused {
        if (msg.sender != TIME_LOCK_ADDRESS) revert OnlyTimeLock();
        if (_newFee > MAX_PROTOCOL_FEE) {
            revert BadProtocolFee();
        }
        currentRateInfo.feeToProtocolRate = _newFee;
        emit ChangeFee(_newFee);
    }

    event WithdrawFees(uint128 _shares, address _recipient, uint256 _amountToTransfer);

    function withdrawFees(uint128 _shares, address _recipient) external onlyOwner returns (uint256 _amountToTransfer) {
        // Grab some data from state to save gas
        VaultAccount memory _totalAsset = totalAsset;
        VaultAccount memory _totalBorrow = totalBorrow;

        // Take all available if 0 value passed
        if (_shares == 0) _shares = uint128(balanceOf(address(this)));

        // We must calculate this before we subtract from _totalAsset or invoke _burn
        _amountToTransfer = _totalAsset.toAmount(_shares, true);

        // Check for sufficient withdraw liquidity
        uint256 _assetsAvailable = _totalAssetAvailable(_totalAsset, _totalBorrow);
        if (_assetsAvailable < _amountToTransfer) {
            revert InsufficientAssetsInContract(_assetsAvailable, _amountToTransfer);
        }

        // Effects: bookkeeping
        _totalAsset.amount -= uint128(_amountToTransfer);
        _totalAsset.shares -= _shares;

        // Effects: write to states
        // NOTE: will revert if _shares > balanceOf(address(this))
        _burn(address(this), _shares);
        totalAsset = _totalAsset;

        // Interactions
        assetContract.safeTransfer(_recipient, _amountToTransfer);
        emit WithdrawFees(_shares, _recipient, _amountToTransfer);
    }

    event SetSwapper(address _swapper, bool _approval);

    function setSwapper(address _swapper, bool _approval) external onlyOwner {
        swappers[_swapper] = _approval;
        emit SetSwapper(_swapper, _approval);
    }

    event SetApprovedLender(address indexed _address, bool _approval);

    function setApprovedLenders(address[] calldata _lenders, bool _approval) external approvedLender(msg.sender) {
        for (uint256 i = 0; i < _lenders.length; i++) {
            // Do not set when _approval == false and _lender == msg.sender
            if (_approval || _lenders[i] != msg.sender) {
                approvedLenders[_lenders[i]] = _approval;
                emit SetApprovedLender(_lenders[i], _approval);
            }
        }
    }

    event SetApprovedBorrower(address indexed _address, bool _approval);

    function setApprovedBorrowers(address[] calldata _borrowers, bool _approval) external approvedBorrower {
        for (uint256 i = 0; i < _borrowers.length; i++) {
            // Do not set when _approval == false and _borrower == msg.sender
            if (_approval || _borrowers[i] != msg.sender) {
                approvedBorrowers[_borrowers[i]] = _approval;
                emit SetApprovedBorrower(_borrowers[i], _approval);
            }
        }
    }

    function pause() external {
        if (
            msg.sender != CIRCUIT_BREAKER_ADDRESS &&
            msg.sender != COMPTROLLER_ADDRESS &&
            msg.sender != owner() &&
            msg.sender != DEPLOYER_ADDRESS
        ) {
            revert ProtocolOrOwnerOnly();
        }
        _addInterest(); // accrue any interest prior to pausing as it won't accrue during pause
        _pause();
    }

    function unpause() external {
        if (msg.sender != COMPTROLLER_ADDRESS && msg.sender != owner()) {
            revert ProtocolOrOwnerOnly();
        }
        // Resets the lastTimestamp which has the effect of no interest accruing over the pause period
        _addInterest();
        _unpause();
    }
}
