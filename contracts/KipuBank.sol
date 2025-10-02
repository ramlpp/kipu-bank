//SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title KipuBank - Bóveda de depósito y retiro de ETH con límites
 * @author Dev ramlpp
 * @notice Permite a los usuarios depositar y retirar ETH bajo ciertas restricciones
 * @dev Este contrato sigue buenas prácticas de seguridad y documentación en Solidity
 */
contract kipubank {

    /// @notice Límite máximo de retiro por transacción
    /// @dev Se define en el constructor y no puede modificarse
    uint256 public immutable withdrawLimitPerTx;
    
    /// @notice Límite máximo de depósito por transacción
    /// @dev Se define en el constructor y no puede modificarse
    uint256 public immutable depositLimitPerTx;

    /// @notice Mapa que almacena el saldo de ETH de cada dirección
    mapping(address => uint256) private _balances;

    /// @notice Total de ETH depositado en el contrato
    uint256 public totalDeposited;

    /// @notice Número total de depósitos realizados
    uint256 public depositCount;

    /// @notice Número total de retiros realizados
    uint256 public withdrawCount;

    
}
