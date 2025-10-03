# KipuBank 🏦

Smart contract que permite a los usuarios depositar y retirar ETH dentro de una bóveda personal con límites definidos. Proyecto desarrollado como parte del **TP2** del Módulo 2 (Solidity / Web3).

---

## ✨ Descripción

KipuBank es un contrato inteligente que simula un banco descentralizado simple con las siguientes características:

* Los usuarios pueden **depositar ETH** en su bóveda personal.
* Los usuarios pueden **retirar ETH**, pero solo hasta un **límite fijo por transacción** (`withdrawLimitPerTx`).
* Existe un **límite global de depósitos** (`bankCap`) definido en el despliegue.
* El contrato mantiene un registro de:

  * Total de ETH depositado.
  * Número de depósitos realizados.
  * Número de retiros realizados.
* Se emiten **eventos** en cada depósito y retiro.
* Se aplican **buenas prácticas de seguridad**, como:

  * Errores personalizados en lugar de `require` con strings.
  * Patrón **checks-effects-interactions**.
  * Validaciones con modificadores.

---

## 📂 Estructura del repositorio

```
kipu-bank/
│
├── contracts/
│   └── KipuBank.sol     # Contrato inteligente
│
├── README.md            # Documentación del proyecto
```

---

## ⚙️ Variables clave

* `bankCap`: límite global de depósitos en el contrato (immutable).
* `withdrawLimitPerTx`: límite máximo de retiro por transacción (immutable).
* `depositLimitPerTx`: declarada como ejemplo, pero no implementada en esta versión.
* `_balances`: mapping con el saldo de cada usuario.
* `totalDeposited`: total de ETH en la bóveda global.

---

## 🚀 Despliegue

1. Compilar el contrato en **Remix IDE** o **Hardhat/Foundry**.

2. Seleccionar una testnet (por ejemplo **Sepolia** o **Goerli**).

3. En el constructor, pasar los parámetros:

   * `_bankCap`: límite global de depósitos.
   * `_withdrawLimitPerTx`: límite máximo de retiro por transacción.

   Ejemplo (Sepolia testnet, Remix):

   ```
   _bankCap = 100 ether
   _withdrawLimitPerTx = 1 ether
   ```

4. Desplegar y verificar el contrato en **Etherscan** (block explorer).

---

## 🔎 Interacción

Funciones principales:

* **`deposit()`** (public, payable):
  Permite al usuario depositar ETH en su bóveda.

* **`withdraw(uint256 amount)`** (external):
  Retira ETH de la bóveda personal hasta el límite permitido.

* **`balanceOf(address user)`** (external view):
  Consulta el saldo de un usuario.

Eventos:

* **Deposit(address user, uint256 amount, uint256 balance, uint256 totalDeposited)**
* **Withdraw(address user, uint256 amount, uint256 balance, uint256 totalDeposited)**

---

## 📜 Ejemplo de uso

```solidity
// Depositar 0.5 ETH
kipuBank.deposit{value: 0.5 ether}();

// Retirar 0.2 ETH
kipuBank.withdraw(0.2 ether);

// Consultar saldo
kipuBank.balanceOf(0x1234...);
```

---

## 📍 Dirección del contrato desplegado

> 📝 Reemplazar con la dirección real en testnet cuando lo despliegues.

```
Sepolia Testnet: 0xXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

---

## 👨‍💻 Autor

* **Dev ramlpp**
  Proyecto realizado como parte del portafolio de desarrollador Web3.
