// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AttendanceToken is ERC20 {
    constructor() ERC20("Attendance Token", "ATT") {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }
}
