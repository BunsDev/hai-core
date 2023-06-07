// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

interface ICollateralAuctionHouse is IAuthorizable {
  function bidAmount(uint256 _id) external view returns (uint256 _rad);
  function raisedAmount(uint256 _id) external view returns (uint256 _rad);
  function remainingAmountToSell(uint256 _id) external view returns (uint256 _wad);
  function forgoneCollateralReceiver(uint256 _id) external view returns (address _receiver);
  function amountToRaise(uint256 _id) external view returns (uint256 _rad);
  function terminateAuctionPrematurely(uint256 _auctionId) external;
  function startAuction(
    address _forgoneCollateralReceiver,
    address _initialBidder,
    uint256 /* RAD */ _amountToRaise,
    uint256 /* WAD */ _collateralToSell,
    uint256 /* RAD */ _initialBid
  ) external returns (uint256 _id);
  function settleAuction(uint256 _id) external;
}
