// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "remix_tests.sol";
import "../src/KipuBankV3.sol";

contract KipuBankV3Test {
    KipuBankV3 bank;
    address owner;
    address user = address(0x123);
    
    // Direcciones de prueba
    address usdc = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
    address router = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2;
    uint256 bankCap = 1000 * 10**6; // 1000 USDC
    
    function beforeAll() public {
        owner = msg.sender; // El que despliega el test
        bank = new KipuBankV3(usdc, router, bankCap);
    }
    
    // TEST 1: Verificar que el owner es correcto
    function testOwnerIsDeployer() public {
        Assert.equal(bank.owner(), owner, "Owner should be deployer");
    }
    
    // TEST 2: Verificar que USDC address se configuró
    function testUSDCAddress() public {
        Assert.equal(bank.USDC(), usdc, "USDC address should match");
    }
    
    // TEST 3: Verificar bank cap
    function testBankCap() public {
        Assert.equal(bank.bankCapUsd(), bankCap, "Bank cap should match");
    }
    
    // TEST 4: Verificar WETH address
    function testWETHAddress() public {
        // WETH debería ser una dirección válida (no zero)
        Assert.notEqual(bank.WETH(), address(0), "WETH should not be zero address");
    }
    
    // TEST 5: Balance inicial es cero
    function testInitialBalanceZero() public {
        uint256 balance = bank.usdcBalanceOf(user);
        Assert.equal(balance, 0, "Initial balance should be zero");
    }
    
    // TEST 6: Router address configurado
    function testRouterAddress() public {
        Assert.equal(address(bank.router()), router, "Router address should match");
    }
}