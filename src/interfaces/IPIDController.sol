// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

interface IPIDController is IAuthorizable {
  // --- Events ---
  event UpdateDeviation(int256 _proportionalDeviation, int256 _integralDeviation, int256 _deltaIntegralDeviation);

  // --- Structs ---
  struct DeviationObservation {
    // The timestamp when this observation was stored
    uint256 timestamp;
    // The proportional term stored in this observation
    int256 proportional;
    // The integral term stored in this observation
    int256 integral;
  }

  struct ControllerGains {
    // This value is multiplied with the proportional term
    int256 Kp; // [WAD]
    // This value is multiplied with priceDeviationCumulative
    int256 Ki; // [WAD]
  }

  function getBoundedRedemptionRate(int256 _piOutput) external view returns (uint256 _redemptionRate);

  function computeRate(
    uint256 _marketPrice,
    uint256 _redemptionPrice,
    uint256 _accumulatedLeak
  ) external returns (uint256 _redemptionRate);

  function getGainAdjustedPIOutput(
    int256 _proportionalTerm,
    int256 _integralTerm
  ) external view returns (int256 _piOutput);

  function getGainAdjustedTerms(
    int256 _proportionalTerm,
    int256 _integralTerm
  ) external view returns (int256 _proportionalGain, int256 _integralGain);

  function getNextDeviationCumulative(
    int256 _proportionalTerm,
    uint256 accumulatedLeak
  ) external returns (int256 _priceDeviationCumulative, int256 _timeAdjustedDeviation);

  function breaksNoiseBarrier(uint256 _piSum, uint256 _redemptionPrice) external view returns (bool _breaksNb);

  function getNextRedemptionRate(
    uint256 _marketPrice,
    uint256 _redemptionPrice,
    uint256 _accumulatedLeak
  ) external view returns (uint256 _redemptionRate, int256 _proportionalTerm, int256 _integralTerm);

  function seedProposer() external view returns (address _seedProposer);

  function perSecondCumulativeLeak() external view returns (uint256 _perSecondCumulativeLeak);

  function timeSinceLastUpdate() external view returns (uint256 _timeSinceLastValue);

  function integralPeriodSize() external view returns (uint256 _integralPeriodSize);

  function feedbackOutputLowerBound() external view returns (int256 _feedbackOutputLowerBound);

  function feedbackOutputUpperBound() external view returns (uint256 _feedbackOutputUpperBound);

  function noiseBarrier() external view returns (uint256 _noiseBarrier);

  function controllerGains() external view returns (ControllerGains memory _cGains);

  function deviation() external view returns (DeviationObservation memory);
}