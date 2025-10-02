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
}
