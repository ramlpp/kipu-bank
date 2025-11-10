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
    
    address owner;
    address user = address(0x123);
    
    address usdc = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
    uint256 bankCap = 1000 * 10**6;
    
    function beforeAll() public {
        owner = msg.sender;
        
        // Crear mocks primero
        mockWETH = new MockWETH();
        mockRouter = new MockUniswapRouter(address(mockWETH));
        
        // Ahora crear el banco con los mocks
        bank = new KipuBankV3(usdc, address(mockRouter), bankCap);
    }
    
    function testOwnerIsDeployer() public {
        Assert.equal(bank.owner(), owner, "Owner should be deployer");
    }
    
    function testUSDCAddress() public {
        Assert.equal(bank.USDC(), usdc, "USDC address should match");
    }
    
    function testBankCap() public {
        Assert.equal(bank.bankCapUsd(), bankCap, "Bank cap should match");
    }
    
    function testInitialBalanceZero() public {
        uint256 balance = bank.usdcBalanceOf(user);
        Assert.equal(balance, 0, "Initial balance should be zero");
    }
}