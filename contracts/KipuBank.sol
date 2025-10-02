//SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title KipuBank - Bóveda de depósito y retiro de ETH con límites
 * @author Dev ramlpp
 * @notice Permite a los usuarios depositar y retirar ETH bajo ciertas restricciones
 * @dev Este contrato sigue buenas prácticas de seguridad y documentación en Solidity
 */
contract kipubank {

    uint256 number;

    /**
     * @dev Store value in variable
     * @param num value to store
     */
    function store(uint256 num) public {
        number = num;
    }

    /**
     * @dev Return value 
     * @return value of 'number'
     */
    function retrieve() public view returns (uint256){
        return number;
    }
}
