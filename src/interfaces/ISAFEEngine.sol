// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiablePerCollateral, GLOBAL_PARAM} from '@interfaces/utils/IModifiablePerCollateral.sol';

interface ISAFEEngine is IDisableable, IAuthorizable, IModifiablePerCollateral {
  // --- Events ---
  event ApproveSAFEModification(address _sender, address _account);
  event DenySAFEModification(address _sender, address _account);
  event InitializeCollateralType(bytes32 _collateralType);
  event ModifyCollateralBalance(bytes32 indexed _collateralType, address indexed _account, int256 _wad);
  event TransferCollateral(bytes32 indexed _collateralType, address indexed _src, address indexed _dst, uint256 _wad);
  event TransferInternalCoins(address indexed _src, address indexed _dst, uint256 _rad);
  event ModifySAFECollateralization(
    bytes32 indexed _collateralType,
    address indexed _safe,
    address _collateralSource,
    address _debtDestination,
    int256 _deltaCollateral,
    int256 _deltaDebt,
    uint256 _lockedCollateral,
    uint256 _generatedDebt,
    uint256 _globalDebt
  );
  event TransferSAFECollateralAndDebt(
    bytes32 indexed _collateralType,
    address indexed _src,
    address indexed _dst,
    int256 _deltaCollateral,
    int256 _deltaDebt,
    uint256 _srcLockedCollateral,
    uint256 _srcGeneratedDebt,
    uint256 _dstLockedCollateral,
    uint256 _dstGeneratedDebt
  );
  event ConfiscateSAFECollateralAndDebt(
    bytes32 indexed _collateralType,
    address indexed _safe,
    address _collateralCounterparty,
    address _debtCounterparty,
    int256 _deltaCollateral,
    int256 _deltaDebt,
    uint256 _globalUnbackedDebt
  );
  event SettleDebt(
    address indexed _account,
    uint256 _rad,
    uint256 _debtBalance,
    uint256 _coinBalance,
    uint256 _globalUnbackedDebt,
    uint256 _globalDebt
  );
  event CreateUnbackedDebt(
    address indexed _debtDestination,
    address indexed _coinDestination,
    uint256 _rad,
    uint256 _debtDstBalance,
    uint256 _coinDstBalance,
    uint256 _globalUnbackedDebt,
    uint256 _globalDebt
  );
  event UpdateAccumulatedRate(
    bytes32 indexed _collateralType,
    address _surplusDst,
    int256 _rateMultiplier,
    uint256 _dstCoinBalance,
    uint256 _globalDebt
  );

  // --- Errors ---
  error NotSAFEAllowed();

  // --- Structs ---
  struct SAFE {
    // Total amount of collateral locked in a SAFE
    uint256 lockedCollateral; // [wad]
    // Total amount of debt generated by a SAFE
    uint256 generatedDebt; // [wad]
  }

  struct SAFEEngineParams {
    // Total amount of debt that a single safe can generate
    uint256 safeDebtCeiling; // [wad]
    // Maximum amount of debt that can be issued
    uint256 globalDebtCeiling; // [rad]
  }

  struct SAFEEngineCollateralData {
    // Total amount of debt issued by a collateral type
    uint256 debtAmount; // [wad]
    // Accumulated rate of a collateral type
    uint256 accumulatedRate; // [ray]
  }

  struct SAFEEngineCollateralParams {
    // Floor price at which a SAFE is allowed to generate debt
    uint256 safetyPrice; // [ray]
    // Maximum amount of debt that can be generated with this collateral type
    uint256 debtCeiling; // [rad]
    // Minimum amount of debt that must be generated by a SAFE using this collateral
    uint256 debtFloor; // [rad]
    // Price at which a SAFE gets liquidated
    uint256 liquidationPrice; // [ray]
  }

  function coinBalance(address _coinAddress) external view returns (uint256 _balance);
  function debtBalance(address _coinAddress) external view returns (uint256 _debtBalance);
  function settleDebt(uint256 _rad) external;
  function transferInternalCoins(address _source, address _destination, uint256 _rad) external;
  function transferCollateral(bytes32 _collateralType, address _source, address _destination, uint256 _wad) external;
  function canModifySAFE(address _safe, address _account) external view returns (bool);
  function approveSAFEModification(address _account) external;
  function denySAFEModification(address _acount) external;
  function createUnbackedDebt(address _debtDestination, address _coinDestination, uint256 _rad) external;
  function params() external view returns (uint256 _globalDebtCeiling, uint256 _globalDebtFloor);
  function cData(bytes32 _collateralType)
    external
    view
    returns (uint256 /* wad */ _debtAmount, uint256 /* ray */ _accumulatedRate);
  function cParams(bytes32 _collateralType)
    external
    view
    returns (
      uint256 /* ray */ _safetyPrice,
      uint256 /* rad */ _debtCeiling,
      uint256 /* rad */ _debtFloor,
      uint256 /* ray */ _liquidationPrice
    );

  function safes(
    bytes32,
    address
  ) external view returns (uint256 /* wad */ _lockedCollateral, uint256 /* wad */ _generatedDebt);

  function globalDebt() external returns (uint256 _globalDebt);
  function confiscateSAFECollateralAndDebt(
    bytes32 _collateralType,
    address _safe,
    address _collateralSource,
    address _debtDestination,
    int256 _deltaCollateral,
    int256 _deltaDebt
  ) external;
  function updateAccumulatedRate(bytes32 _collateralType, address _surplusDst, int256 _rateMultiplier) external;

  function initializeCollateralType(bytes32 _collateralType) external;
  function modifyCollateralBalance(bytes32 _collateralType, address _account, int256 _wad) external;
  function modifySAFECollateralization(
    bytes32 _collateralType,
    address _safe,
    address _collateralSource,
    address _debtDestination,
    int256 /* wad */ _deltaCollateral,
    int256 /* wad */ _deltaDebt
  ) external;

  function transferSAFECollateralAndDebt(
    bytes32 _collateralType,
    address _src,
    address _dst,
    int256 /* wad */ _deltaCollateral,
    int256 /* wad */ _deltaDebt
  ) external;

  function tokenCollateral(bytes32 _collateralType, address _account) external view returns (uint256 _tokenCollateral);
  function globalUnbackedDebt() external view returns (uint256 _globalUnbackedDebt);
  function safeRights(address _account, address _safe) external view returns (uint256 _safeRights);
}
