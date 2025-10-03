//SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title KipuBank - Bóveda de depósito y retiro de ETH con límites
 * @author Dev ramlpp
 * @notice Permite a los usuarios depositar y retirar ETH bajo ciertos parametros
 * @dev Este contrato sigue buenas prácticas de seguridad y documentación en Solidity
 */
contract kipubank {

    // ──────── VARIABLES INMUTABLES ────────
    /// @notice Límite máximo de retiro por transacción
    /// @dev Se define en el constructor y no puede modificarse
    uint256 public immutable withdrawLimitPerTx;
    
    /// @notice Límite máximo de depósito por transacción
    /// @dev Se define en el constructor y no puede modificarse
    uint256 public immutable depositLimitPerTx;

    // ──────── VARIABLES DE ESTADO ────────
    /// @notice Mapa que almacena el saldo de ETH de cada dirección
    mapping(address => uint256) private _balances;

    /// @notice Total de ETH depositado en el contrato
    uint256 public totalDeposited;

    /// @notice Número total de depósitos realizados
    uint256 public depositCount;

    /// @notice Número total de retiros realizados
    uint256 public withdrawCount;

    
    // ──────── EVENTOS ────────
    /// @notice Evento emitido cuando un usuario deposita
    event Deposit(address indexed user, uint256 amount, uint256 balance, uint256 totalDeposited);

    /// @notice Evento emitido cuando un usuario retira
    event Withdraw(address indexed user, uint256 amount, uint256 balance, uint256 totalDeposited);

    // ──────── CONSTRUCTOR ────────

    // ──────── MODIFICADORES ────────

    // ──────── FUNCIONES PÚBLICAS / EXTERNAS ────────

    // ──────── FUNCIONES INTERNAS / PRIVADAS ────────

}
