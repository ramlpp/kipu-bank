// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract MockWETH {
    function deposit() external payable {}
    function withdraw(uint) external {}
    function transfer(address, uint) external returns (bool) { return true; }
    function approve(address, uint) external returns (bool) { return true; }
}