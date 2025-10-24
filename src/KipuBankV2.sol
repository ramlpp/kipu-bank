// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title KipuBankV2
 * @author Dev ramlpp
 * @notice Versión mejorada de KipuBank con soporte multi-token, oráculos Chainlink y control básico de acceso.
 * @dev Uso de checks-effects-interactions, reentrancy guard, errores personalizados y contabilidad multi-token.
 */

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    // optional but common
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
}

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);
  function description() external view returns (string memory);
  function version() external view returns (uint256);
  // getRoundData / latestRoundData
  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
}
