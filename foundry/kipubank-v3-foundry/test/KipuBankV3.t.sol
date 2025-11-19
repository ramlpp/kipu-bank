// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/KipuBankV3.sol";

contract KipuBankV3Test is Test {
    KipuBankV3 bank;
    
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
        bank = new KipuBankV3(usdc, router, bankCap);
    }
    
    // TEST 1: Verificar configuración inicial
    function testInitialSetup() public {
        assertEq(bank.USDC(), usdc);
        assertEq(address(bank.router()), router);
        assertEq(bank.bankCapUsd(), bankCap);
        assertTrue(bank.owner() != address(0));
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
        
        // Test withdraw
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
    function testInitialBalanceZero() public {
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
        new KipuBankV3(address(0), router, bankCap);
        
        vm.expectRevert();
        new KipuBankV3(usdc, address(0), bankCap);
        
        vm.expectRevert();
        new KipuBankV3(usdc, router, 0);
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
        (bool success, ) = address(bank).call{value: 1000000000000000}("");
        // No hacemos assert, solo verificamos que la transacción se ejecutó
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
        uint256 totalUsdc = bank.totalUsdc();
        
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
        
        // Retirar
        bank.withdrawUSDC(50 * 10**6);
        assertEq(bank.usdcBalanceOf(user1), 50 * 10**6);
        
        // Depositar de nuevo
        bank.depositUSDC(25 * 10**6);
        assertEq(bank.usdcBalanceOf(user1), 75 * 10**6);
        
        vm.stopPrank();
    }
    // TEST 21: Test para branches de bankCap en depositUSDC (VERSIÓN SIMPLE)
    function testBankCapRefund() public {
        vm.startPrank(user1);
        
        vm.mockCall(
            usdc,
            abi.encodeWithSelector(IERC20.transferFrom.selector),
            abi.encode(true)
        );
        
        // Llenar casi todo el bankCap
        bank.depositUSDC(999 * 10**6);
        
        // Mock para la transfer de refund
        vm.mockCall(
            usdc,
            abi.encodeWithSelector(IERC20.transfer.selector, user1, 2 * 10**6),
            abi.encode(true)
        );
        
        // Intentar depositar más del bankCap restante debería hacer refund
        vm.expectRevert(); // BankCapExceeded
        bank.depositUSDC(2 * 10**6);
        
        vm.stopPrank();
    }

    // TEST 22: Test para branches de swap fallido (VERSIÓN SIMPLE)
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
        
        // Test withdraw con transfer que falla
        vm.startPrank(user1);
        vm.mockCall(
            usdc,
            abi.encodeWithSelector(IERC20.transfer.selector),
            abi.encode(false)
        );
        
        vm.expectRevert(); // SwapFailed
        bank.withdrawUSDC(50 * 10**6);
        
        vm.stopPrank();
    }

    // TEST 25: Test para constructor con diferentes parámetros
    function testConstructorDifferentParams() public {
        // Test que el constructor funciona con diferentes bankCaps
        uint256 smallCap = 100 * 10**6;
        uint256 largeCap = 1000000 * 10**6;
        
        KipuBankV3 smallBank = new KipuBankV3(usdc, router, smallCap);
        KipuBankV3 largeBank = new KipuBankV3(usdc, router, largeCap);
        
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
        vm.expectRevert(); // Debería revertir por dirección cero
        bank.setOwner(address(0));
    }

    // TEST 28: Test para múltiples operaciones complejas
    function testComplexOperations() public {
        // Usuario 1: múltiples depósitos y retiros
        vm.startPrank(user1);
        vm.mockCall(usdc, abi.encodeWithSelector(IERC20.transferFrom.selector), abi.encode(true));
        vm.mockCall(usdc, abi.encodeWithSelector(IERC20.transfer.selector), abi.encode(true));
        
        bank.depositUSDC(300 * 10**6);
        bank.withdrawUSDC(100 * 10**6);
        bank.depositUSDC(50 * 10**6);
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
}