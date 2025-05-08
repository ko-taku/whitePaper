// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./MinimalForwarder.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract AuctionBetting is VRFConsumerBaseV2 {
    using EnumerableSet for EnumerableSet.AddressSet;

    // 출석 토큰과 경매 토큰
    IERC20 public attendanceToken;
    IERC20 public auctionToken;

    // 메타트랜잭션용 MinimalForwarder
    MinimalForwarder public forwarder;

    // 관리자 주소
    address public admin;

    // 배팅 정보 구조체
    struct BetInfo {
        uint256 amount; // 배팅한 출석 토큰 수
        uint256 predictedPrice; // 유저가 예측한 경매 낙찰가
        uint256 finalRandomScore; // VRF 랜덤 점수 중 최고값
    }

    // 유저별 배팅 정보
    mapping(address => BetInfo) public bets;

    // 배팅에 참여한 유저 목록
    EnumerableSet.AddressSet private bettors;

    // VRF 설정 관련 변수
    VRFCoordinatorV2Interface COORDINATOR;
    bytes32 public keyHash;
    uint64 public subscriptionId;
    uint32 public callbackGasLimit = 200000;

    // Chainlink VRF에서 requestId → 유저 주소
    mapping(uint256 => address) public requestIdToUser;

    // 이벤트 정의
    event BetPlaced(
        address indexed user,
        uint256 amount,
        uint256 predictedPrice
    );
    event RandomRequested(address indexed user, uint256 requestId);
    event RandomFulfilled(address indexed user, uint256 randomValue);
    event RewardDistributed(address indexed user, uint256 reward);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    constructor(
        address _attendanceToken,
        address _auctionToken,
        address _forwarder,
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint64 _subscriptionId
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        attendanceToken = IERC20(_attendanceToken);
        auctionToken = IERC20(_auctionToken);
        forwarder = MinimalForwarder(_forwarder);
        admin = msg.sender;

        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;
    }

    // 출석 토큰을 소모하여 경매 예상 낙찰가 배팅
    function placeBet(
        uint256 amount,
        uint256 predictedPrice,
        address user,
        bytes calldata signature
    ) external {
        require(
            amount >= 10 * 1e18 && amount <= 100 * 1e18,
            "Must bet between 10 and 100 tokens"
        );

        // 메타트랜잭션 검증
        require(
            forwarder.verify(user, address(this), 0, "", signature),
            "Invalid signature"
        );

        // 출석 토큰 전송
        require(
            attendanceToken.transferFrom(user, address(this), amount),
            "Transfer failed"
        );

        // 저장
        bets[user] = BetInfo({
            amount: amount,
            predictedPrice: predictedPrice,
            finalRandomScore: 0
        });

        bettors.add(user);
        emit BetPlaced(user, amount, predictedPrice);
    }

    // 유저당 배팅 수량에 따라 VRF 랜덤 요청 여러 번 수행 (최대 10회)
    function requestRandomsForUser(address user) external onlyAdmin {
        uint256 times = bets[user].amount / (10 * 1e18);
        require(times > 0, "No bets");

        for (uint256 i = 0; i < times; i++) {
            uint256 requestId = COORDINATOR.requestRandomWords(
                keyHash,
                subscriptionId,
                3, // 최소 확인 수
                callbackGasLimit,
                1 // 랜덤값 개수
            );
            requestIdToUser[requestId] = user;
            emit RandomRequested(user, requestId);
        }
    }

    // VRF 응답 처리
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        address user = requestIdToUser[requestId];
        uint256 score = (randomWords[0] % 100) + 1; // 1~100 점수

        // 최고 점수로 갱신
        if (score > bets[user].finalRandomScore) {
            bets[user].finalRandomScore = score;
        }

        emit RandomFulfilled(user, score);
    }

    // 관리자에 의해 유저에게 경매 토큰 보상 분배
    function distributeAuctionToken(
        address to,
        uint256 amount
    ) external onlyAdmin {
        require(auctionToken.transfer(to, amount), "Auction reward failed");
        emit RewardDistributed(to, amount);
    }

    // 배팅자 목록 가져오기
    function getAllBettors() external view returns (address[] memory) {
        return bettors.values();
    }

    // 특정 유저의 배팅 정보 확인
    function getBetInfo(address user) external view returns (BetInfo memory) {
        return bets[user];
    }
}
