// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {
  PostSettlementSurplusAuctionHouseForTest,
  IPostSettlementSurplusAuctionHouse
} from '@contracts/for-test/PostSettlementSurplusAuctionHouseForTest.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IToken} from '@interfaces/external/IToken.sol';
import {IAuthorizable} from '@interfaces/IAuthorizable.sol';
import {WAD} from '@libraries/Math.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  struct Auction {
    uint256 id;
    uint256 bidAmount;
    uint256 amountToSell;
    address highBidder;
    uint48 bidExpiry;
    uint48 auctionDeadline;
  }

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  ISAFEEngine mockSafeEngine = ISAFEEngine(mockContract('SafeEngine'));
  IToken mockProtocolToken = IToken(mockContract('ProtocolToken'));

  PostSettlementSurplusAuctionHouseForTest postSettlementSurplusAuctionHouse;

  function setUp() public virtual {
    vm.startPrank(deployer);

    postSettlementSurplusAuctionHouse =
      new PostSettlementSurplusAuctionHouseForTest(address(mockSafeEngine), address(mockProtocolToken));
    label(address(postSettlementSurplusAuctionHouse), 'PostSettlementSurplusAuctionHouse');

    postSettlementSurplusAuctionHouse.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  modifier authorized() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function _mockAuction(Auction memory _auction) internal {
    // BUG: Accessing packed slots is not supported by Std Storage
    postSettlementSurplusAuctionHouse.addBid(
      _auction.id,
      _auction.bidAmount,
      _auction.amountToSell,
      _auction.highBidder,
      _auction.bidExpiry,
      _auction.auctionDeadline
    );
  }

  function _mockBidIncrease(uint256 _bidIncrease) internal {
    stdstore.target(address(postSettlementSurplusAuctionHouse)).sig(
      IPostSettlementSurplusAuctionHouse.bidIncrease.selector
    ).checked_write(_bidIncrease);
  }

  function _mockAuctionsStarted(uint256 _auctionsStarted) internal {
    stdstore.target(address(postSettlementSurplusAuctionHouse)).sig(
      IPostSettlementSurplusAuctionHouse.auctionsStarted.selector
    ).checked_write(_auctionsStarted);
  }
}

contract Unit_PostSettlementSurplusAuctionHouse_Constants is Base {
  function test_Set_AUCTION_HOUSE_TYPE() public {
    assertEq(postSettlementSurplusAuctionHouse.AUCTION_HOUSE_TYPE(), bytes32('SURPLUS'));
  }

  function test_Set_SURPLUS_AUCTION_TYPE() public {
    assertEq(postSettlementSurplusAuctionHouse.SURPLUS_AUCTION_TYPE(), bytes32('POST-SETTLEMENT'));
  }
}

contract Unit_PostSettlementSurplusAuctionHouse_Constructor is Base {
  event AddAuthorization(address _account);

  function setUp() public override {
    Base.setUp();

    vm.startPrank(user);
  }

  function test_Set_BidIncrease() public {
    assertEq(postSettlementSurplusAuctionHouse.bidIncrease(), 1.05e18);
  }

  function test_Set_BidDuration() public {
    assertEq(postSettlementSurplusAuctionHouse.bidDuration(), 3 hours);
  }

  function test_Set_TotalAuctionLength() public {
    assertEq(postSettlementSurplusAuctionHouse.totalAuctionLength(), 2 days);
  }

  function test_Emit_AddAuthorization() public {
    expectEmitNoIndex();
    emit AddAuthorization(user);

    postSettlementSurplusAuctionHouse =
      new PostSettlementSurplusAuctionHouseForTest(address(mockSafeEngine), address(mockProtocolToken));
  }

  function test_Set_SafeEngine(address _safeEngine) public {
    postSettlementSurplusAuctionHouse =
      new PostSettlementSurplusAuctionHouseForTest(_safeEngine, address(mockProtocolToken));

    assertEq(address(postSettlementSurplusAuctionHouse.safeEngine()), _safeEngine);
  }

  function test_Set_ProtocolToken(address _protocolToken) public {
    postSettlementSurplusAuctionHouse =
      new PostSettlementSurplusAuctionHouseForTest(address(mockSafeEngine), _protocolToken);

    assertEq(address(postSettlementSurplusAuctionHouse.protocolToken()), _protocolToken);
  }
}

contract Unit_PostSettlementSurplusAuctionHouse_StartAuction is Base {
  event StartAuction(
    uint256 indexed _id, uint256 _auctionsStarted, uint256 _amountToSell, uint256 _initialBid, uint256 _auctionDeadline
  );

  function test_Revert_Unauthorized(uint256 _amountToSell, uint256 _initialBid) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    postSettlementSurplusAuctionHouse.startAuction(_amountToSell, _initialBid);
  }

  function test_Revert_Overflow(uint256 _amountToSell, uint256 _initialBid) public authorized {
    _mockAuctionsStarted(type(uint256).max);

    vm.expectRevert();

    postSettlementSurplusAuctionHouse.startAuction(_amountToSell, _initialBid);
  }

  function test_Set_AuctionsStarted(uint256 _amountToSell, uint256 _initialBid) public authorized {
    for (uint256 _i = 1; _i <= 3; ++_i) {
      postSettlementSurplusAuctionHouse.startAuction(_amountToSell, _initialBid);
      assertEq(postSettlementSurplusAuctionHouse.auctionsStarted(), _i);
    }
  }

  function test_Set_Bids(uint256 _amountToSellFuzzed, uint256 _initialBid) public authorized {
    postSettlementSurplusAuctionHouse.startAuction(_amountToSellFuzzed, _initialBid);

    (uint256 _bidAmount, uint256 _amountToSell, address _highBidder, uint48 _bidExpiry, uint48 _auctionDeadline) =
      postSettlementSurplusAuctionHouse.bids(1);

    assertEq(_bidAmount, _initialBid);
    assertEq(_amountToSell, _amountToSellFuzzed);
    assertEq(_highBidder, authorizedAccount);
    assertEq(_bidExpiry, 0);
    assertEq(_auctionDeadline, block.timestamp + postSettlementSurplusAuctionHouse.totalAuctionLength());
  }

  function test_Call_SafeEngine_TransferInternalCoins(uint256 _amountToSell, uint256 _initialBid) public authorized {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(
        mockSafeEngine.transferInternalCoins,
        (authorizedAccount, address(postSettlementSurplusAuctionHouse), _amountToSell)
      )
    );

    postSettlementSurplusAuctionHouse.startAuction(_amountToSell, _initialBid);
  }

  function test_Emit_StartAuction(uint256 _amountToSell, uint256 _initialBid) public authorized {
    expectEmitNoIndex();
    emit StartAuction(
      1, 1, _amountToSell, _initialBid, block.timestamp + postSettlementSurplusAuctionHouse.totalAuctionLength()
    );

    postSettlementSurplusAuctionHouse.startAuction(_amountToSell, _initialBid);
  }

  function test_Return_Id(uint256 _amountToSell, uint256 _initialBid) public authorized {
    uint256 _auctionsStarted = postSettlementSurplusAuctionHouse.auctionsStarted();

    assertEq(postSettlementSurplusAuctionHouse.startAuction(_amountToSell, _initialBid), _auctionsStarted + 1);
  }
}

contract Unit_PostSettlementSurplusAuctionHouse_RestartAuction is Base {
  event RestartAuction(uint256 _id, uint256 _auctionDeadline);

  modifier happyPath(Auction memory _auction) {
    _assumeHappyPath(_auction);
    _mockAuction(_auction);
    _;
  }

  function _assumeHappyPath(Auction memory _auction) internal {
    vm.assume(_auction.auctionDeadline < block.timestamp);
    vm.assume(_auction.bidExpiry == 0);
  }

  function test_Revert_NotFinished(Auction memory _auction) public {
    vm.assume(_auction.auctionDeadline >= block.timestamp);

    _mockAuction(_auction);

    vm.expectRevert('PostSettlementSurplusAuctionHouse/not-finished');

    postSettlementSurplusAuctionHouse.restartAuction(_auction.id);
  }

  function test_Revert_BidAlreadyPlaced(Auction memory _auction) public {
    vm.assume(_auction.auctionDeadline < block.timestamp);
    vm.assume(_auction.bidExpiry != 0);

    _mockAuction(_auction);

    vm.expectRevert('PostSettlementSurplusAuctionHouse/bid-already-placed');

    postSettlementSurplusAuctionHouse.restartAuction(_auction.id);
  }

  function test_Set_Bids_AuctionDeadline(Auction memory _auction) public happyPath(_auction) {
    postSettlementSurplusAuctionHouse.restartAuction(_auction.id);

    (,,,, uint48 _auctionDeadline) = postSettlementSurplusAuctionHouse.bids(_auction.id);

    assertEq(_auctionDeadline, block.timestamp + postSettlementSurplusAuctionHouse.totalAuctionLength());
  }

  function test_Emit_RestartAuction(Auction memory _auction) public happyPath(_auction) {
    expectEmitNoIndex();
    emit RestartAuction(_auction.id, block.timestamp + postSettlementSurplusAuctionHouse.totalAuctionLength());

    postSettlementSurplusAuctionHouse.restartAuction(_auction.id);
  }
}

contract Unit_PostSettlementSurplusAuctionHouse_IncreaseBidSize is Base {
  event IncreaseBidSize(uint256 _id, address _highBidder, uint256 _amountToBuy, uint256 _bid, uint256 _bidExpiry);

  function setUp() public override {
    Base.setUp();

    vm.startPrank(user);
  }

  modifier happyPath(Auction memory _auction, uint256 _bid) {
    _assumeHappyPath(_auction, _bid);
    _mockAuction(_auction);
    _;
  }

  function _assumeHappyPath(Auction memory _auction, uint256 _bid) internal {
    vm.assume(_auction.highBidder != address(0) && _auction.highBidder != user);
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline > block.timestamp);
    vm.assume(_bid > _auction.bidAmount);
    vm.assume(notOverflowMul(_bid, WAD));
    vm.assume(notOverflowMul(postSettlementSurplusAuctionHouse.bidIncrease(), _auction.bidAmount));
    vm.assume(_bid * WAD >= postSettlementSurplusAuctionHouse.bidIncrease() * _auction.bidAmount);
  }

  function test_Revert_HighBidderNotSet(Auction memory _auction, uint256 _amountToBuy, uint256 _bid) public {
    _auction.highBidder = address(0);

    _mockAuction(_auction);

    vm.expectRevert('PostSettlementSurplusAuctionHouse/high-bidder-not-set');

    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _amountToBuy, _bid);
  }

  function test_Revert_BidAlreadyExpired(Auction memory _auction, uint256 _amountToBuy, uint256 _bid) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry != 0 && _auction.bidExpiry <= block.timestamp);

    _mockAuction(_auction);

    vm.expectRevert('PostSettlementSurplusAuctionHouse/bid-already-expired');

    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _amountToBuy, _bid);
  }

  function test_Revert_AuctionAlreadyExpired(Auction memory _auction, uint256 _amountToBuy, uint256 _bid) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline <= block.timestamp);

    _mockAuction(_auction);

    vm.expectRevert('PostSettlementSurplusAuctionHouse/auction-already-expired');

    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _amountToBuy, _bid);
  }

  function test_Revert_AmountsNotMatching(Auction memory _auction, uint256 _amountToBuy, uint256 _bid) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline > block.timestamp);
    vm.assume(_auction.amountToSell != _amountToBuy);

    _mockAuction(_auction);

    vm.expectRevert('PostSettlementSurplusAuctionHouse/amounts-not-matching');

    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _amountToBuy, _bid);
  }

  function test_Revert_BidNotHigher(Auction memory _auction, uint256 _bid) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline > block.timestamp);
    vm.assume(_bid <= _auction.bidAmount);

    _mockAuction(_auction);

    vm.expectRevert('PostSettlementSurplusAuctionHouse/bid-not-higher');

    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);
  }

  function test_Revert_InsufficientIncrease(Auction memory _auction, uint256 _bid, uint256 _bidIncrease) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline > block.timestamp);
    vm.assume(_bid > _auction.bidAmount);
    vm.assume(notOverflowMul(_bid, WAD));
    vm.assume(notOverflowMul(_bidIncrease, _auction.bidAmount));
    vm.assume(_bid * WAD < _bidIncrease * _auction.bidAmount);

    _mockAuction(_auction);
    _mockBidIncrease(_bidIncrease);

    vm.expectRevert('PostSettlementSurplusAuctionHouse/insufficient-increase');

    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);
  }

  function test_Call_ProtocolToken_Move_0(Auction memory _auction, uint256 _bid) public happyPath(_auction, _bid) {
    vm.expectCall(
      address(mockProtocolToken),
      abi.encodeCall(
        mockProtocolToken.move,
        (_auction.highBidder, address(postSettlementSurplusAuctionHouse), _bid - _auction.bidAmount)
      )
    );

    changePrank(_auction.highBidder);
    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);
  }

  function testFail_Call_ProtocolToken_Move_0(Auction memory _auction, uint256 _bid) public happyPath(_auction, _bid) {
    vm.expectCall(
      address(mockProtocolToken),
      abi.encodeCall(mockProtocolToken.move, (_auction.highBidder, _auction.highBidder, _auction.bidAmount))
    );

    changePrank(_auction.highBidder);
    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);
  }

  function test_Call_ProtocolToken_Move_1(Auction memory _auction, uint256 _bid) public happyPath(_auction, _bid) {
    vm.expectCall(
      address(mockProtocolToken),
      abi.encodeCall(mockProtocolToken.move, (user, _auction.highBidder, _auction.bidAmount))
    );
    vm.expectCall(
      address(mockProtocolToken),
      abi.encodeCall(
        mockProtocolToken.move, (user, address(postSettlementSurplusAuctionHouse), _bid - _auction.bidAmount)
      )
    );

    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);
  }

  function test_Set_Bids_HighBidder_0(Auction memory _auction, uint256 _bid) public happyPath(_auction, _bid) {
    changePrank(_auction.highBidder);
    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);

    (,, address _highBidder,,) = postSettlementSurplusAuctionHouse.bids(_auction.id);

    assertEq(_highBidder, _auction.highBidder);
  }

  function test_Set_Bids_HighBidder_1(Auction memory _auction, uint256 _bid) public happyPath(_auction, _bid) {
    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);

    (,, address _highBidder,,) = postSettlementSurplusAuctionHouse.bids(_auction.id);

    assertEq(_highBidder, user);
  }

  function test_Set_Bids_BidAmount(Auction memory _auction, uint256 _bid) public happyPath(_auction, _bid) {
    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);

    (uint256 _bidAmount,,,,) = postSettlementSurplusAuctionHouse.bids(_auction.id);

    assertEq(_bidAmount, _bid);
  }

  function test_Set_Bids_BidExpiry(Auction memory _auction, uint256 _bid) public happyPath(_auction, _bid) {
    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);

    (,,, uint48 _bidExpiry,) = postSettlementSurplusAuctionHouse.bids(_auction.id);

    assertEq(_bidExpiry, block.timestamp + postSettlementSurplusAuctionHouse.bidDuration());
  }

  function test_Emit_IncreaseBidSize(Auction memory _auction, uint256 _bid) public happyPath(_auction, _bid) {
    expectEmitNoIndex();
    emit IncreaseBidSize(
      _auction.id, user, _auction.amountToSell, _bid, block.timestamp + postSettlementSurplusAuctionHouse.bidDuration()
    );

    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);
  }
}

contract Unit_PostSettlementSurplusAuctionHouse_SettleAuction is Base {
  event SettleAuction(uint256 indexed _id);

  modifier happyPath(Auction memory _auction) {
    _assumeHappyPath(_auction);
    _mockAuction(_auction);
    _;
  }

  function _assumeHappyPath(Auction memory _auction) internal {
    vm.assume(_auction.bidExpiry != 0);
    vm.assume(_auction.bidExpiry < block.timestamp);
  }

  function test_Revert_NotFinished_0(Auction memory _auction) public {
    vm.assume(_auction.bidExpiry == 0);

    _mockAuction(_auction);

    vm.expectRevert('PostSettlementSurplusAuctionHouse/not-finished');

    postSettlementSurplusAuctionHouse.settleAuction(_auction.id);
  }

  function test_Revert_NotFinished_1(Auction memory _auction) public {
    vm.assume(_auction.bidExpiry >= block.timestamp);
    vm.assume(_auction.auctionDeadline >= block.timestamp);

    _mockAuction(_auction);

    vm.expectRevert('PostSettlementSurplusAuctionHouse/not-finished');

    postSettlementSurplusAuctionHouse.settleAuction(_auction.id);
  }

  function test_Call_SafeEngine_TransferInternalCoins(Auction memory _auction) public {
    vm.assume(_auction.bidExpiry >= block.timestamp);
    vm.assume(_auction.auctionDeadline < block.timestamp);

    _mockAuction(_auction);

    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(
        mockSafeEngine.transferInternalCoins,
        (address(postSettlementSurplusAuctionHouse), _auction.highBidder, _auction.amountToSell)
      )
    );

    postSettlementSurplusAuctionHouse.settleAuction(_auction.id);
  }

  function test_Call_ProtocolToken_Burn(Auction memory _auction) public happyPath(_auction) {
    vm.expectCall(
      address(mockProtocolToken),
      abi.encodeCall(mockProtocolToken.burn, (address(postSettlementSurplusAuctionHouse), _auction.bidAmount))
    );

    postSettlementSurplusAuctionHouse.settleAuction(_auction.id);
  }

  function test_Set_Bids(Auction memory _auction) public happyPath(_auction) {
    postSettlementSurplusAuctionHouse.settleAuction(_auction.id);

    (uint256 _bidAmount, uint256 _amountToSell, address _highBidder, uint48 _bidExpiry, uint48 _auctionDeadline) =
      postSettlementSurplusAuctionHouse.bids(_auction.id);

    assertEq(_bidAmount, 0);
    assertEq(_amountToSell, 0);
    assertEq(_highBidder, address(0));
    assertEq(_bidExpiry, 0);
    assertEq(_auctionDeadline, 0);
  }

  function test_Emit_SettleAuction(Auction memory _auction) public happyPath(_auction) {
    expectEmitNoIndex();
    emit SettleAuction(_auction.id);

    postSettlementSurplusAuctionHouse.settleAuction(_auction.id);
  }
}
