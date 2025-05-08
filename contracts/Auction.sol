// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MinimalForwarder.sol";

contract Auction {
    IMinimalForwarder public minimalForwarder;
    IERC20 public auctionToken;

    address public admin; // 관리자 주소 추가
    address public highestBidder;
    uint public highestBid;

    mapping(address => uint) public bids;

    bool public auctionActive;

    uint public constant MIN_BID_AMOUNT = 1 * 10 ** 18; // 최소 입찰 금액 (1 토큰, decimals이 18인 토큰 기준)

    event NewBid(address indexed bidder, uint bidAmount);
    event AuctionEnded(address winner, uint winningBid);

    // 관리자 주소를 초기화하는 생성자
    constructor(
        address _minimalForwarder,
        address _auctionToken,
        address _admin
    ) {
        minimalForwarder = IMinimalForwarder(_minimalForwarder);
        auctionToken = IERC20(_auctionToken);
        admin = _admin; // 관리자 주소 설정
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier onlyAuctionActive() {
        require(auctionActive, "Auction is not active");
        _;
    }

    modifier onlyAuctionEnded() {
        require(!auctionActive, "Auction is still active");
        _;
    }

    // 경매 시작
    function startAuction() external onlyAdmin {
        require(!auctionActive, "Auction is already active");
        auctionActive = true;
    }

    // 경매 종료
    function endAuction() external onlyAdmin onlyAuctionActive {
        auctionActive = false;
        emit AuctionEnded(highestBidder, highestBid);

        // 경매가 끝난 후 최고 입찰자에게 상품 전달
        // 예시로 경매에서 상품을 전송하거나 기타 처리를 할 수 있음
    }

    // 입찰하기
    function placeBid(uint _amount) external onlyAuctionActive {
        require(_amount >= MIN_BID_AMOUNT, "Bid must be at least 1 token");
        uint currentBid = bids[msg.sender] + _amount;

        require(
            currentBid > highestBid,
            "Bid is not higher than the current highest bid"
        );

        bids[msg.sender] = currentBid;
        highestBid = currentBid;
        highestBidder = msg.sender;

        auctionToken.transferFrom(msg.sender, address(this), _amount);

        emit NewBid(msg.sender, _amount);
    }

    // 입찰 취소 (입찰금액을 반환)
    function cancelBid() external onlyAuctionActive {
        uint bidAmount = bids[msg.sender];
        require(bidAmount > 0, "No bid to cancel");

        bids[msg.sender] = 0;

        auctionToken.transfer(msg.sender, bidAmount);
    }

    // 메타트랜잭션을 통해 입찰하는 함수
    function placeBidMeta(
        uint _amount,
        address _from,
        bytes calldata _sig
    ) external onlyAuctionActive {
        require(
            minimalForwarder.verify(_from, address(this), _amount, "", _sig),
            "Invalid signature"
        );

        uint currentBid = bids[_from] + _amount;

        require(
            currentBid > highestBid,
            "Bid is not higher than the current highest bid"
        );
        require(_amount >= MIN_BID_AMOUNT, "Bid must be at least 1 token");

        bids[_from] = currentBid;
        highestBid = currentBid;
        highestBidder = _from;

        auctionToken.transferFrom(_from, address(this), _amount);

        emit NewBid(_from, _amount);
    }
}
