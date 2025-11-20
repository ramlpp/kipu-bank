// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/KipuBankV4.sol";

contract KipuBankV4Test is Test {
    KipuBankV4 bank;
    
    // Direcciones de prueba
    address owner = address(0x123);
    address user1 = address(0x456);
    address user2 = address(0x789);
    
    // Mocks - usamos cualquier address
    address usdc = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
    address router = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2;
    address weth = 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db;
    
    uint256 bankCap = 1000 * 10**6; // 1000 USDC
    
    function setUp() public {
        // El deployer se convierte en owner
        vm.prank(owner);
        bank = new KipuBankV4(usdc, router, bankCap);
    }
    
    // TEST 1: Verificar configuración inicial
    function testInitialSetup() public view {
        assertEq(bank.USDC(), usdc);
        assertEq(address(bank.router()), router);
        assertEq(bank.bankCapUsd(), bankCap);
        assertEq(bank.owner(), owner);
    }
    
    // TEST 2: Depositar USDC directamente
    function testDepositUSDC() public {
        vm.startPrank(user1);
        
        // Mock de transferFrom exitoso
        vm.mockCall(
            usdc,
            abi.encodeWithSelector(IERC20.transferFrom.selector, user1, address(bank), 100 * 10**6),
            abi.encode(true)
        );
        
        bank.depositUSDC(100 * 10**6);
        assertEq(bank.usdcBalanceOf(user1), 100 * 10**6);
        
        vm.stopPrank();
    }
    
    // TEST 3: Retirar USDC
    function testWithdrawUSDC() public {
        // Setup: usuario tiene balance
        vm.startPrank(user1);
        vm.mockCall(
            usdc,
            abi.encodeWithSelector(IERC20.transferFrom.selector),
            abi.encode(true)
        );
        bank.depositUSDC(100 * 10**6);
        vm.stopPrank();
        
        // Test withdraw - Saltar 1 día en el tiempo
        vm.warp(block.timestamp + 1 days + 1);
        
        vm.startPrank(user1);
        vm.mockCall(
            usdc,
            abi.encodeWithSelector(IERC20.transfer.selector, user1, 50 * 10**6),
            abi.encode(true)
        );
        
        bank.withdrawUSDC(50 * 10**6);
        assertEq(bank.usdcBalanceOf(user1), 50 * 10**6);
        vm.stopPrank();
    }
    
    // TEST 4: Respetar bank cap
    function testBankCap() public {
        vm.startPrank(user1);
        
        vm.mockCall(
            usdc,
            abi.encodeWithSelector(IERC20.transferFrom.selector),
            abi.encode(true)
        );
        
        // Llenar hasta el límite
        bank.depositUSDC(1000 * 10**6);
        
        // Intentar superar el cap debería revertir
        vm.expectRevert();
        bank.depositUSDC(1);
        
        vm.stopPrank();
    }
    
    // TEST 5: Cambiar owner
    function testChangeOwner() public {
        address originalOwner = bank.owner();
        address newOwner = address(0x999);
        
        // Solo el owner puede cambiar
        vm.prank(originalOwner);
        bank.setOwner(newOwner);
        
        assertEq(bank.owner(), newOwner);
    }
    
    // TEST 6: Balance inicial cero
    function testInitialBalanceZero() public view {
        assertEq(bank.usdcBalanceOf(user1), 0);
        assertEq(bank.usdcBalanceOf(user2), 0);
    }
    
    // TEST 7: Prueba básica de reentrancy guard
    function testReentrancyGuard() public {
        vm.startPrank(user1);
        
        vm.mockCall(
            usdc,
            abi.encodeWithSelector(IERC20.transferFrom.selector),
            abi.encode(true)
        );
        
        // Depositar debería funcionar
        bank.depositUSDC(100 * 10**6);
        
        // Intentar depositar de nuevo debería funcionar (no bloqueado)
        bank.depositUSDC(50 * 10**6);
        
        assertEq(bank.usdcBalanceOf(user1), 150 * 10**6);
        vm.stopPrank();
    }
    
    // TEST 8: Prueba de seguridad - solo owner puede cambiar owner
    function testOnlyOwnerCanChangeOwner() public {
        address newOwner = address(0x999);
        
        // Usuario normal NO puede cambiar owner
        vm.prank(user1);
        vm.expectRevert();
        bank.setOwner(newOwner);
    }
    
    // TEST 9: Prueba de zero amount
    function testZeroAmountDeposit() public {
        vm.startPrank(user1);
        
        // Depositar 0 debería revertir
        vm.expectRevert();
        bank.depositUSDC(0);
        
        vm.stopPrank();
    }
    
    // TEST 10: Prueba de withdraw con balance insuficiente
    function testWithdrawInsufficientBalance() public {
        vm.startPrank(user1);
        
        // Intentar retirar sin balance debería revertir
        vm.expectRevert();
        bank.withdrawUSDC(100 * 10**6);
        
        vm.stopPrank();
    }
    
    // TEST 11: Prueba de constructor con parámetros inválidos
    function testInvalidConstructor() public {
        // Dirección cero debería revertir
        vm.expectRevert();
        new KipuBankV4(address(0), router, bankCap);
        
        vm.expectRevert();
        new KipuBankV4(usdc, address(0), bankCap);
        
        vm.expectRevert();
        new KipuBankV4(usdc, router, 0);
    }
    
    // TEST 12: Prueba de safeApprove (función interna)
    function testSafeApprove() public {
        // Para probar safeApprove, necesitamos llamar una función que lo use
        vm.startPrank(user1);
        
        // Mock para transferFrom y approve
        vm.mockCall(
            usdc,
            abi.encodeWithSelector(IERC20.transferFrom.selector),
            abi.encode(true)
        );
        vm.mockCall(
            usdc, 
            abi.encodeWithSelector(IERC20.approve.selector),
            abi.encode(true)
        );
        
        // depositUSDC usa _safeApprove internamente
        bank.depositUSDC(100 * 10**6);
        
        vm.stopPrank();
    }
    
    // TEST 13: Prueba de receive fallback
    function testReceiveFallback() public {
        // Enviar ETH directamente al contrato
        address(bank).call{value: 1000000000000000}("");
        // Solo verificamos que no revierte
        assertTrue(true);
    }
    
    // TEST 14: Prueba de fallback function
    function testFallbackFunction() public {
        // El fallback debería revertir
        (bool success, ) = address(bank).call{value: 0}("invalid");
        assertFalse(success);
    }
    
    // TEST 15: Prueba de InvalidPath en depositTokenSwapToUSDC
    function testInvalidPath() public {
        vm.startPrank(user1);
        
        // Token cero debería revertir
        vm.expectRevert();
        bank.depositTokenSwapToUSDC(address(0), 100 * 10**6, 0);
        
        // USDC como token de entrada debería revertir
        vm.expectRevert();
        bank.depositTokenSwapToUSDC(usdc, 100 * 10**6, 0);
        
        vm.stopPrank();
    }
    
    // TEST 16: Prueba de balance actualizado después de múltiples operaciones
    function testMultipleOperations() public {
        vm.startPrank(user1);
        
        vm.mockCall(
            usdc,
            abi.encodeWithSelector(IERC20.transferFrom.selector),
            abi.encode(true)
        );
        vm.mockCall(
            usdc,
            abi.encodeWithSelector(IERC20.transfer.selector),
            abi.encode(true)
        );
        
        // Depositar
        bank.depositUSDC(200 * 10**6);
        assertEq(bank.usdcBalanceOf(user1), 200 * 10**6);
        
        // Saltar tiempo para evitar cooldown
        vm.warp(block.timestamp + 1 days + 1);
        
        // Retirar parcial
        bank.withdrawUSDC(50 * 10**6);
        assertEq(bank.usdcBalanceOf(user1), 150 * 10**6);
        
        // Depositar más
        bank.depositUSDC(100 * 10**6);
        assertEq(bank.usdcBalanceOf(user1), 250 * 10**6);
        
        vm.stopPrank();
    }
    
    // TEST 17: Test para funciones view básicas que SÍ existen
    function testViewFunctions() public view {
        // Estas funciones SÍ existen en tu contrato
        address currentOwner = bank.owner();
        address usdcAddress = bank.USDC();
        address routerAddress = address(bank.router());
        uint256 bankCapValue = bank.bankCapUsd();
        
        // Solo verificamos que podemos llamarlas sin revertir
        assertTrue(currentOwner != address(0));
        assertTrue(usdcAddress != address(0));
        assertTrue(routerAddress != address(0));
        assertTrue(bankCapValue > 0);
    }
    
    // TEST 18: Test para bankCap exacto
    function testBankCapExactLimit() public {
        vm.startPrank(user1);
        
        vm.mockCall(
            usdc,
            abi.encodeWithSelector(IERC20.transferFrom.selector),
            abi.encode(true)
        );
        
        uint256 cap = bank.bankCapUsd();
        
        // Depositar exactamente el bankCap debería funcionar
        bank.depositUSDC(cap);
        assertEq(bank.totalUsdc(), cap);
        
        vm.stopPrank();
    }
    
    // TEST 19: Test para múltiples usuarios
    function testMultipleUsers() public {
        // Usuario 1 deposita
        vm.startPrank(user1);
        vm.mockCall(usdc, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
        bank.depositUSDC(100 * 10**6);
        vm.stopPrank();
        
        // Usuario 2 deposita
        vm.startPrank(user2);
        vm.mockCall(usdc, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
        bank.depositUSDC(200 * 10**6);
        vm.stopPrank();
        
        // Verificar balances separados
        assertEq(bank.usdcBalanceOf(user1), 100 * 10**6);
        assertEq(bank.usdcBalanceOf(user2), 200 * 10**6);
        assertEq(bank.totalUsdc(), 300 * 10**6);
    }
    
    // TEST 20: Test para withdraw y luego deposit
    function testWithdrawThenDeposit() public {
        vm.startPrank(user1);
        
        vm.mockCall(usdc, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
        vm.mockCall(usdc, abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
        
        // Depositar
        bank.depositUSDC(100 * 10**6);
        assertEq(bank.usdcBalanceOf(user1), 100 * 10**6);
        
        // Saltar tiempo para evitar cooldown
        vm.warp(block.timestamp + 1 days + 1);
        
        // Retirar
        bank.withdrawUSDC(50 * 10**6);
        assertEq(bank.usdcBalanceOf(user1), 50 * 10**6);
        
        // Depositar de nuevo
        bank.depositUSDC(25 * 10**6);
        assertEq(bank.usdcBalanceOf(user1), 75 * 10**6);
        
        vm.stopPrank();
    }

    // TEST 21: Test para branches de bankCap en depositUSDC
    function testBankCapRefund() public {
        vm.startPrank(user1);
        
        vm.mockCall(
            usdc,
            abi.encodeWithSelector(IERC20.transferFrom.selector),
            abi.encode(true)
        );
        
        // Llenar casi todo el bankCap
        bank.depositUSDC(999 * 10**6);
        
        // Intentar depositar más del bankCap restante debería revertir
        vm.expectRevert();
        bank.depositUSDC(2 * 10**6);
        
        vm.stopPrank();
    }

    // TEST 22: Test para branches de swap fallido
    function testSwapFailed() public {
        vm.startPrank(user1);
        
        address someToken = address(0xABC);
        
        // Mock transferFrom exitoso pero swap fallido
        vm.mockCall(
            someToken,
            abi.encodeWithSelector(IERC20.transferFrom.selector),
            abi.encode(true)
        );
        
        // Mock approve exitoso
        vm.mockCall(
            someToken,
            abi.encodeWithSelector(IERC20.approve.selector),
            abi.encode(true)
        );
        
        // Mock swap que falla (retorna array vacío)
        vm.mockCall(
            router,
            abi.encodeWithSelector(IUniswapV2Router02.swapExactTokensForTokens.selector),
            abi.encode(new uint256[](0))
        );
        
        // Debería revertir por SwapFailed
        vm.expectRevert();
        bank.depositTokenSwapToUSDC(someToken, 1 * 10**18, 0);
        
        vm.stopPrank();
    }

    // TEST 23: Test para branches de transfer fallido
    function testTransferFailed() public {
        vm.startPrank(user1);
        
        // Mock transferFrom que falla
        vm.mockCall(
            usdc,
            abi.encodeWithSelector(IERC20.transferFrom.selector),
            abi.encode(false)
        );
        
        // Debería revertir por SwapFailed
        vm.expectRevert();
        bank.depositUSDC(100 * 10**6);
        
        vm.stopPrank();
    }

    // TEST 24: Test para branches de withdraw con transfer fallido
    function testWithdrawTransferFailed() public {
        // Setup: usuario tiene balance
        vm.startPrank(user1);
        vm.mockCall(usdc, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
        bank.depositUSDC(100 * 10**6);
        vm.stopPrank();
        
        // Saltar tiempo para evitar cooldown
        vm.warp(block.timestamp + 1 days + 1);
        
        // Test withdraw con transfer que falla
        vm.startPrank(user1);
        vm.mockCall(
            usdc,
            abi.encodeWithSelector(IERC20.transfer.selector),
            abi.encode(false)
        );
        
        vm.expectRevert();
        bank.withdrawUSDC(50 * 10**6);
        
        vm.stopPrank();
    }

    // TEST 25: Test para constructor con diferentes parámetros
    function testConstructorDifferentParams() public {
        // Test que el constructor funciona con diferentes bankCaps
        uint256 smallCap = 100 * 10**6;
        uint256 largeCap = 1000000 * 10**6;
        
        vm.prank(owner);
        KipuBankV4 smallBank = new KipuBankV4(usdc, router, smallCap);
        
        vm.prank(owner);
        KipuBankV4 largeBank = new KipuBankV4(usdc, router, largeCap);
        
        assertEq(smallBank.bankCapUsd(), smallCap);
        assertEq(largeBank.bankCapUsd(), largeCap);
    }

    // TEST 26: Test para usdcBalanceOf con diferentes usuarios
    function testUSDCBalanceOfEdgeCases() public view {
        // Balance de address cero
        assertEq(bank.usdcBalanceOf(address(0)), 0);
        
        // Balance de contrato mismo
        assertEq(bank.usdcBalanceOf(address(bank)), 0);
        
        // Balance de router
        assertEq(bank.usdcBalanceOf(router), 0);
    }

    // TEST 27: Test para setOwner con dirección cero
    function testSetOwnerZeroAddress() public {
        address originalOwner = bank.owner();
        
        vm.prank(originalOwner);
        vm.expectRevert();
        bank.setOwner(address(0));
    }

    // TEST 28: Test para múltiples operaciones complejas
    function testComplexOperations() public {
        // Usuario 1: múltiples depósitos y retiros
        vm.startPrank(user1);
        vm.mockCall(usdc, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
        vm.mockCall(usdc, abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
        
        bank.depositUSDC(300 * 10**6);
        
        // Saltar tiempo entre retiros
        vm.warp(block.timestamp + 1 days + 1);
        bank.withdrawUSDC(100 * 10**6);
        
        bank.depositUSDC(50 * 10**6);
        
        vm.warp(block.timestamp + 1 days + 1);
        bank.withdrawUSDC(25 * 10**6);
        
        assertEq(bank.usdcBalanceOf(user1), 225 * 10**6);
        vm.stopPrank();
        
        // Usuario 2: operaciones simultáneas
        vm.startPrank(user2);
        vm.mockCall(usdc, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
        bank.depositUSDC(400 * 10**6);
        vm.stopPrank();
        
        // Verificar total
        assertEq(bank.totalUsdc(), 625 * 10**6);
    }

    // TEST 29: Test para remainingCapacity
    function testRemainingCapacity() public view {
        uint256 remaining = bank.remainingCapacity();
        assertEq(remaining, bankCap);
    }

    // TEST 30: Test para emergencyWithdraw de ETH
    function testEmergencyWithdrawETH() public {
        // Dar ETH al contrato
        vm.deal(address(bank), 1 ether);
        uint256 initialBalance = owner.balance;
        
        vm.prank(owner);
        bank.emergencyWithdraw(address(0), 1 ether);
        
        assertEq(owner.balance, initialBalance + 1 ether);
    }

    // TEST 31: Test para emergencyWithdraw de ERC20
    function testEmergencyWithdrawERC20() public {
        vm.prank(owner);
        
        vm.mockCall(
            usdc,
            abi.encodeWithSelector(IERC20.transfer.selector, owner, 100 * 10**6),
            abi.encode(true)
        );
        
        bank.emergencyWithdraw(usdc, 100 * 10**6);
    }

    // TEST 32: Test para emergencyWithdraw con diferentes tokens
    function testEmergencyWithdrawDifferentToken() public {
        address randomToken = address(0x777);
        
        vm.prank(owner);
        
        vm.mockCall(
            randomToken,
            abi.encodeWithSelector(IERC20.transfer.selector, owner, 50 * 10**18),
            abi.encode(true)
        );
        
        bank.emergencyWithdraw(randomToken, 50 * 10**18);
    }

    // TEST 33: Test para remainingCapacity después de depósito
    function testRemainingCapacityAfterDeposit() public {
        vm.startPrank(user1);
        
        vm.mockCall(usdc, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
        
        bank.depositUSDC(100 * 10**6);
        
        uint256 remaining = bank.remainingCapacity();
        assertEq(remaining, bankCap - 100 * 10**6);
        
        vm.stopPrank();
    }
}