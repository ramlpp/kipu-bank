// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "remix_tests.sol";
import "../src/KipuBankV3.sol";
import "./MockUniswapRouter.sol";
import "./MockWETH.sol";

contract KipuBankV3Test {
    KipuBankV3 bank;
    MockUniswapRouter mockRouter;
    MockWETH mockWETH;
    
    address usdc = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
    uint256 bankCap = 1000 * 10**6;
    
    function beforeAll() public {
        // Crear mocks primero
        mockWETH = new MockWETH();
        mockRouter = new MockUniswapRouter(address(mockWETH));
        
        // Ahora crear el banco con los mocks
        bank = new KipuBankV3(usdc, address(mockRouter), bankCap);
    }
    
    // TEST CORREGIDO: Verificar que el owner NO es zero address
    function testOwnerIsNotZero() public {
        Assert.notEqual(bank.owner(), address(0), "Owner should not be zero address");
    }
    
    function testUSDCAddress() public {
        Assert.equal(bank.USDC(), usdc, "USDC address should match");
    }
    
    function testBankCap() public {
        Assert.equal(bank.bankCapUsd(), bankCap, "Bank cap should match");
    }
    
    function testInitialBalanceZero() public {
        uint256 balance = bank.usdcBalanceOf(address(0x123));
        Assert.equal(balance, 0, "Initial balance should be zero");
    }
    
    // TEST EXTRA: Verificar que WETH se configuró
    function testWETHAddress() public {
        Assert.notEqual(bank.WETH(), address(0), "WETH should not be zero");
    }
    
    // TEST EXTRA: Verificar router address
    function testRouterAddress() public {
        Assert.equal(address(bank.router()), address(mockRouter), "Router should match mock");
    }
}