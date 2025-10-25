# 🏦 KipuBank V2

**KipuBank V2** es la versión evolucionada del contrato inteligente original **KipuBank**, desarrollado como parte del proyecto final del curso de Solidity.  
Este nuevo contrato incorpora técnicas avanzadas de desarrollo, seguridad y arquitectura de contratos inteligentes, orientadas a un entorno más cercano a producción.

---

## 📘 Descripción General

KipuBank V2 funciona como una **bóveda de depósito y retiro de activos**, soportando tanto **Ether (ETH)** como **tokens ERC-20**, con límites definidos, control de acceso y conversión de valores en USD a través de **Chainlink Oracles**.  
El objetivo del contrato es ofrecer una infraestructura simple y segura para manejar depósitos y retiros bajo reglas claras, siguiendo buenas prácticas de diseño y seguridad en Solidity.

---

## 🚀 Mejoras Implementadas en la Versión V2

| Área | Mejora | Descripción |
|------|---------|-------------|
| **Control de acceso** | `AccessControl` (OpenZeppelin) | Se añadió un rol administrativo `ADMIN_ROLE` con privilegios especiales (como actualizar límites o pausar el contrato). |
| **Soporte multi-token** | Depósitos y retiros en ETH y ERC-20 | Se agregó compatibilidad para diferentes tokens, gestionados mediante mappings anidados: `balances[token][user]`. |
| **Contabilidad interna** | Unificación de saldos | Se implementó un sistema centralizado de contabilidad interna que identifica ETH como `address(0)`. |
| **Oráculo Chainlink** | Conversión ETH/USD | Se agregó una integración con un **Data Feed** de Chainlink para convertir los valores de ETH en USD y así controlar el `bankCap` en base al valor actual del mercado. |
| **Seguridad** | `nonReentrant` + `checks-effects-interactions` | Se aplicó el patrón estándar de seguridad para prevenir ataques de reentrancy. |
| **Errores personalizados** | Mejor manejo de errores | Se definieron errores específicos (`InvalidParams`, `Unauthorized`, `TokenTransferFailed`, etc.) para reducir consumo de gas y mejorar la trazabilidad. |
| **Optimización de gas** | Uso de `immutable` y `constant` | Variables de configuración definidas como `immutable` y constantes globales en mayúsculas para claridad. |
| **Eventos adicionales** | Auditoría y trazabilidad | Nuevos eventos para depósitos, retiros y actualizaciones de configuración. |
| **Conversión de decimales** | Compatibilidad multi-token | Implementación de una función que ajusta valores a 6 decimales (como USDC) para uniformidad contable. |

---

## 🧱 Estructura del Proyecto

KipuBankV2/  
├── src/  
│   └── KipuBankV2.sol  
└── README.md  

- **src/KipuBankV2.sol** → Contrato principal con todas las mejoras.  
- **README.md** → Este archivo.  

---

## ⚙️ Tecnologías y Librerías Utilizadas

- Solidity ^0.8.30  
- OpenZeppelin Contracts  
  - AccessControl  
  - ReentrancyGuard  
  - IERC20  
- Chainlink Data Feeds  

---

## 🧩 Principales Variables y Componentes

mapping(address => mapping(address => uint256)) private _balances; // token => usuario => saldo
bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
AggregatorV3Interface public immutable priceFeed; // Oráculo Chainlink ETH/USD
uint256 public immutable withdrawLimitPerTx;
uint256 public immutable bankCapUSD;

🧠 Decisiones de Diseño y Trade-offs

Se optó por usar AccessControl en lugar de Ownable para permitir la expansión de roles y responsabilidades.

La contabilidad multi-token permite manejar tanto ETH como tokens ERC-20 de forma unificada.

El oráculo Chainlink fue elegido por su confiabilidad y descentralización, permitiendo límites dinámicos basados en precio USD.

Se prefirió mantener la lógica del depósito simple, pero con una capa de seguridad adicional (reentrancy guard).

Los eventos permiten auditorías más claras, emitiendo siempre antes de cualquier transferencia externa.

💡 Ejemplo de Uso

Depositar ETH:

kipuBank.deposit{value: 1 ether}(address(0));


Depositar un token ERC-20:

kipuBank.depositToken(USDC_ADDRESS, 100 * 1e6);


Consultar saldo:

kipuBank.balanceOf(address(0), msg.sender);


Retirar fondos:

kipuBank.withdraw(address(0), 0.5 ether);

🔒 Seguridad y Buenas Prácticas Aplicadas

Uso del patrón Checks-Effects-Interactions.

Reentrancy Guard en funciones críticas.

Validaciones estrictas de parámetros y errores personalizados.

No se usan llamadas transfer() ni send(), sino .call{value: amount}("") seguro.

Funciones administrativas restringidas a ADMIN_ROLE.

Pruebas con valores límites y validaciones contra depósitos o retiros nulos.

🌐 Despliegue en Testnet

Red: Sepolia Testnet

Explorador: Etherscan - Sepolia

Dirección del Contrato: 

Compilador: Solidity 0.8.30

Framework: Remix IDE + MetaMask

🧭 Instrucciones para Clonar y Ejecutar
# 1. Clonar el repositorio
git clone https://github.com/TuUSER/KipuBankV2.git

# 2. Abrir Remix IDE o VSCode con Solidity plugin

# 3. Compilar el contrato
pragma solidity ^0.8.30

# 4. Desplegar en testnet Sepolia
Seleccionar "Injected Provider - MetaMask" como entorno

📜 Licencia

Este proyecto está bajo la Licencia MIT.
Eres libre de usarlo, modificarlo y distribuirlo, siempre que se mantenga la atribución al autor original.

✍️ Autor

dev ramlpp
Desarrollador Solidity • Proyecto Final Curso Blockchain & Smart Contracts
GitHub: