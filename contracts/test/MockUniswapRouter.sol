// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Mock mínimo de Uniswap Router
contract MockUniswapRouter {
    address public WETH;
    
    constructor(address _weth) {
        WETH = _weth;
    }
    
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin, 
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        // Mock simple - retorna amounts falso
        amounts = new uint[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOutMin;
        return amounts;
    }
    
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path, 
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts) {
        amounts = new uint[](2);
        amounts[0] = msg.value;
        amounts[1] = amountOutMin;
        return amounts;
    }
}