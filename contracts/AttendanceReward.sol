// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMinimalForwarder {
    function execute(
        address from,
        address to,
        uint256 value,
        bytes calldata data,
        bytes calldata signature
    ) external;
}

contract AttendanceReward {
    IERC20 public attendanceToken; // 출석용 토큰
    uint256 public attendanceFee = 10 * 10 ** 18; // 10 출석용 토큰
    uint256 public rewardAmount = 1 * 10 ** 18; // 출석 보상 (1 토큰)
    IMinimalForwarder public minimalForwarder; // Minimal Forwarder 계약 주소

    mapping(address => bool) public hasClaimedToday;
    uint256 public lastRewardTime; // 마지막 보상 지급 시간

    event AttendanceClaimed(address indexed participant);

    constructor(address _attendanceToken, address _minimalForwarder) {
        attendanceToken = IERC20(_attendanceToken);
        minimalForwarder = IMinimalForwarder(_minimalForwarder);
        lastRewardTime = block.timestamp;
    }

    // 출석 이벤트 참여 함수 (메타트랜잭션을 통한)
    function claimAttendanceRewardMeta(
        address _from,
        bytes calldata _signature
    ) external {
        require(
            block.timestamp >= lastRewardTime + 24 hours,
            "Claim only once every 24 hours"
        );
        require(
            attendanceToken.balanceOf(_from) >= attendanceFee,
            "Insufficient attendance tokens"
        );

        // MinimalForwarder를 통해 메타트랜잭션을 실행
        bytes memory data = abi.encodeWithSelector(
            this.claimAttendanceReward.selector,
            _from
        );

        // 출석 보상 지급
        minimalForwarder.execute(_from, address(this), 0, data, _signature);

        // 출석 보상 지급
        attendanceToken.transfer(_from, rewardAmount);

        // 오늘 출석을 완료했음을 기록
        hasClaimedToday[_from] = true;
        lastRewardTime = block.timestamp;

        emit AttendanceClaimed(_from);
    }

    // 실제 출석 보상을 지급하는 함수
    function claimAttendanceReward(address _from) public {
        require(
            attendanceToken.balanceOf(_from) >= attendanceFee,
            "Insufficient attendance tokens"
        );

        // 출석용 토큰을 소모
        attendanceToken.transferFrom(_from, address(this), attendanceFee);

        // 출석 보상 지급
        attendanceToken.transfer(_from, rewardAmount);

        // 오늘 출석을 완료했음을 기록
        hasClaimedToday[_from] = true;
        lastRewardTime = block.timestamp;

        emit AttendanceClaimed(_from);
    }
}
