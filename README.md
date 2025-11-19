# 🏦 KipuBank V4

**KipuBank V4** es la evolución del contrato inteligente KipuBank, desarrollado como proyecto final. Esta versión introduce conversión automática de activos mediante Uniswap V2, eliminando dependencias de oráculos y optimizando la experiencia DeFi.

## 📘 Descripción General

KipuBank V4 actúa como una **bóveda inteligente** donde los usuarios pueden depositar **ETH o tokens ERC-20** que se convierten automáticamente a **USDC** via Uniswap V2. Todo se contabiliza en USDC, con un **tope máximo de capacidad (`bankCapUsd`)**, protección ante reentrancy y validaciones de seguridad.

## 🚀 Mejoras Implementadas

- **Conversión automática**: Depósitos de ETH/tokens se convierten automáticamente a USDC via Uniswap V2
- **Arquitectura optimizada**: Eliminación de dependencias complejas, lógica más eficiente
- **Seguridad robusta**: Protección completa contra reentrancy y validaciones estrictas
- **Soporte multi-token**: ETH + cualquier ERC-20 con par USDC en Uniswap

## 🧱 Estructura del Proyecto

KipuBankV4/  
├── src/  
│   └── KipuBankV4.sol
├── foundry/  
├── sreenshots/
└── README.md  

- **src/KipuBankV4.sol** → Contrato principal con las funcionalidades de swap y contabilidad en USDC.  
- **README.md** → Documentación del proyecto.
- **screenshots/** → Capturas de pantalla de coverage-50%, test-passing y transactions-contract-etherscan.  
- **foundry/** → Carpeta de foundry con sus test.  

---

## ⚙️ Tecnologías Utilizadas

- **Solidity ^0.8.30**
- **Foundry** - Framework de testing y deployment
- **Uniswap V2 Router** - Para swaps automáticos
- **OpenZeppelin Interfaces** - IERC20, IWETH

## 🧩 Componentes Principales

**Variables Inmutables:**
- `USDC` - Dirección del token USDC
- `router` - Router de Uniswap V2
- `WETH` - Dirección de WETH
- `bankCapUsd` - Límite máximo del banco en USDC

**Funciones Clave:**
- `depositUSDC(uint256 amountUsdc)` - Depósito directo de USDC
- `depositETHSwapToUSDC(uint256 minUsdcOut)` - ETH → USDC automático
- `depositTokenSwapToUSDC(address token, uint256 amountIn, uint256 minUsdcOut)` - Token → USDC
- `withdrawUSDC(uint256 amountUsdc)` - Retiro de USDC
- `usdcBalanceOf(address user)` - Consulta de saldo

## 💡 Ejemplos de Uso

// Depositar ETH
kipuBank.depositETHSwapToUSDC{value: 0.01 ether}(500000); // min 0.5 USDC

// Depositar Token ERC-20
kipuBank.depositTokenSwapToUSDC(DAI_ADDRESS, 100 * 1e18, 95000000); // min 95 USDC

// Consultar y Retirar
uint256 balance = kipuBank.usdcBalanceOf(msg.sender);
kipuBank.withdrawUSDC(50 * 1e6);

🔒 Seguridad y Buenas Prácticas Aplicadas
Uso del patrón Checks-Effects-Interactions.

Protección contra reentrancy.

Validaciones estrictas de parámetros.

Safe approve pattern para tokens ERC-20.

Reversiones seguras con errores personalizados.

Eventos emitidos antes de cualquier interacción externa.

📊 Cobertura de Pruebas
El proyecto incluye 28 tests en Foundry alcanzando:

Líneas: 67.90% ✅ CUMPLE (>50% requerido)

Statements: 63.35% ✅ CUMPLE (>50% requerido)

Branches: 57.89% ✅ CUMPLE (>50% requerido)

Funciones: 90.91% ✅ CUMPLE (>50% requerido)

🌐 Despliegue en Testnet
Red: Base Sepolia Testnet

Explorador: RouteScan

Contrato verificado:
Ver en RouteScan

Compilador: Solidity 0.8.30

Entorno: Remix IDE + MetaMask

Interacciones Verificadas:

✅ depositUSDC - Transacción

✅ withdrawUSDC - Transacción

✅ setOwner - Funciones administrativas operativas

🧪 Testing con Foundry:

-- Ejecutar tests
forge test

-- Generar reporte de cobertura
forge coverage --report summary

-- Ver tests detallados
forge test -vv

🔍 Análisis de Amenazas
Vulnerabilidades Identificadas:

1- Front-running en swaps - Mineros pueden ver transacciones pendientes

2- Slippage en Uniswap - Precios pueden cambiar entre tx y confirmación

3- Approval attacks - Usuarios deben confiar en el contrato con approvals

Medidas de Mitigación:

✅ Límites de slippage (minUsdcOut)

✅ Validaciones de bankCap antes de swaps

✅ Reentrancy guards

✅ Safe approve pattern

🧭 Instrucciones para Clonar y Ejecutar:

-- 1. Clonar el repositorio
git clone https://github.com/ramlupp/KipuBankV4.git

-- 2. Abrir Remix IDE o VSCode con extensión Solidity

-- 3. Compilar el contrato
pragma solidity ^0.8.30

-- 4. Desplegar en testnet (Base Sepolia)
Seleccionar "Injected Provider – MetaMask" como entorno

📜 Licencia
Este proyecto está bajo la Licencia MIT.
Eres libre de usarlo, modificarlo y distribuirlo, manteniendo la atribución al autor original.

✍️ Autor
dev ramlpp
Desarrollador Solidity • Proyecto Final Curso Blockchain & Smart Contracts
GitHub: https://github.com/ramlupp

URL al contrato verificado en routescan
https://testnet.routescan.io/address/0x9Ab7AE5279A2446DE4Be3b15DcBb4bd79272Bd69