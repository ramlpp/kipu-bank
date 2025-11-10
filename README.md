# 🏦 KipuBank V3

**KipuBank V3** es la evolución del contrato inteligente **KipuBank V2**, desarrollado como parte del proyecto final del curso de Solidity.  
Esta nueva versión introduce un modelo más moderno de conversión automática de activos mediante Uniswap, eliminando dependencias de oráculos y optimizando la experiencia de depósito y retiro en USDC.

---

## 📘 Descripción General

KipuBank V3 actúa como una **bóveda inteligente de depósitos y retiros**, donde los usuarios pueden enviar **ETH o tokens ERC-20** y el contrato automáticamente los convierte a **USDC** a través de **Uniswap V2 Router**.  
El objetivo es simplificar la interacción del usuario: todo se contabiliza en USDC, con un **tope máximo de capacidad (`bankCapUsd`)**, protección ante reentrancy y validaciones de seguridad.

---

## 🚀 Mejoras Implementadas en la Versión V3

| Área | Mejora | Descripción |
|------|---------|-------------|
| **Conversión automática** | Swaps Uniswap V2 | Los depósitos de ETH o tokens se convierten automáticamente a USDC mediante Uniswap V2 Router. |
| **Eliminación de oráculos externos** | Simplificación | Se eliminó la dependencia de Chainlink Data Feeds; ahora las conversiones se realizan on-chain a precios de mercado. |
| **Optimización de arquitectura** | Código más compacto | Eliminación de AccessControl y uso de una lógica interna de `owner` más ligera. |
| **Seguridad mejorada** | `nonReentrant` + validaciones | Protección ante reentrancy, revertencias seguras y verificación de límites del banco. |
| **Gestión de WETH** | Conversión ETH→WETH→USDC | Se agregó soporte completo para el flujo nativo de ETH, incluyendo envoltura (wrap) y aprobación. |
| **Errores personalizados** | Gas optimizado | Se mantienen revert messages compactas y errores personalizados (`SwapFailed`, `BankCapExceeded`, etc.). |
| **Eventos uniformes** | Auditoría clara | Se estandarizaron los eventos de depósito y retiro para una trazabilidad uniforme. |

---

## 🧱 Estructura del Proyecto

KipuBankV3/  
├── src/  
│   └── KipuBankV3.sol  
└── README.md  

- **src/KipuBankV3.sol** → Contrato principal con las funcionalidades de swap y contabilidad en USDC.  
- **README.md** → Documentación del proyecto.  

---

## ⚙️ Tecnologías y Librerías Utilizadas

- Solidity ^0.8.30  
- Interfaz Uniswap V2 Router 02  
- Interfaz IERC20  
- Interfaz IWETH  
- Remix IDE + MetaMask para despliegue  

---

## 🧩 Principales Variables y Componentes

address public immutable USDC;
IUniswapV2Router02 public immutable router;
address public immutable WETH;
uint256 public immutable bankCapUsd;
uint256 public totalUsdc;
mapping(address => uint256) private usdcBalances;
🔹 Funciones clave
depositUSDC(uint256 amountUsdc) — Deposita directamente USDC.

depositETHSwapToUSDC(uint256 minUsdcOut) — Envía ETH y lo convierte automáticamente a USDC.

depositTokenSwapToUSDC(address token, uint256 amountIn, uint256 minUsdcOut) — Deposita cualquier token ERC-20 convertible a USDC.

withdrawUSDC(uint256 amountUsdc) — Retira tu saldo en USDC.

usdcBalanceOf(address user) — Consulta tu saldo interno.

💡 Ejemplos de Uso
Depositar ETH y convertirlo a USDC
kipuBank.depositETHSwapToUSDC{value: 0.01 ether}(0);

Depositar tokens ERC-20 y convertirlos a USDC
kipuBank.depositTokenSwapToUSDC(DAI_ADDRESS, 100 * 1e18, 0);

Consultar saldo
kipuBank.usdcBalanceOf(msg.sender);

Retirar fondos
kipuBank.withdrawUSDC(50 * 1e6);

🔒 Seguridad y Buenas Prácticas Aplicadas
Uso del patrón Checks-Effects-Interactions.

Protección contra reentrancy.

Validaciones estrictas de parámetros.

Safe approve pattern para tokens ERC-20.

Reversiones seguras con errores personalizados.

Eventos emitidos antes de cualquier interacción externa.

🌐 Despliegue en Testnet
Red: Base Sepolia Testnet

Explorador: RouteScan

Contrato verificado:
Ver en RouteScan

Compilador: Solidity 0.8.30

Entorno: Remix IDE + MetaMask

🧭 Instrucciones para Clonar y Ejecutar
# 1. Clonar el repositorio
git clone https://github.com/ramlupp/KipuBankV3.git

# 2. Abrir Remix IDE o VSCode con extensión Solidity

# 3. Compilar el contrato
pragma solidity ^0.8.30

# 4. Desplegar en testnet (Base Sepolia)
Seleccionar "Injected Provider – MetaMask" como entorno
📜 Licencia
Este proyecto está bajo la Licencia MIT.
Eres libre de usarlo, modificarlo y distribuirlo, manteniendo la atribución al autor original.

✍️ Autor
dev ramlpp
Desarrollador Solidity • Proyecto Final Curso Blockchain & Smart Contracts
GitHub: https://github.com/ramlupp

URL al contrato verificado en routescan
https://testnet.routescan.io/address/0x23661ce9aeC612e747BbDa48464D0c0b34EAF7Bd/contract/11155111/code