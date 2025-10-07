//SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title KipuBank - Bóveda de depósito y retiro de ETH con límites
 * @author Dev ramlpp
 * @notice Permite a los usuarios depositar y retirar ETH bajo ciertos parametros
 * @dev Este contrato sigue buenas prácticas de seguridad y documentación en Solidity
 */
contract KipuBank {


    /*////////////////////////////////////////
    //  ────── VARIABLES INMUTABLES ──────  //
    ////////////////////////////////////////*/
    /// @notice Límite máximo de retiro por transacción
    /// @dev Se define en el constructor y no puede modificarse
    uint256 public immutable withdrawLimitPerTx;
    
    /// @notice Límite global máximo de depósitos en el contrato
    uint256 public immutable bankCap;


    /*////////////////////////////////////////
    //  ────────VARIABLES DE ESTADO───────  //
    ////////////////////////////////////////*/
    /// @notice Mapa que almacena el saldo de ETH de cada dirección
    mapping(address => uint256) private _balances;

    /// @notice Total de ETH depositado en el contrato
    uint256 public totalDeposited;

    /// @notice Número total de depósitos realizados
    uint256 public depositCount;

    /// @notice Número total de retiros realizados
    uint256 public withdrawCount;

    

    /*////////////////////////////////////////
    //  ───────────── EVENTOS ────────────  //
    ////////////////////////////////////////*/
    /// @notice Evento emitido cuando un usuario deposita
    event Deposit(address indexed user, uint256 amount, uint256 balance, uint256 totalDeposited);

    /// @notice Evento emitido cuando un usuario retira
    event Withdraw(address indexed user, uint256 amount, uint256 balance, uint256 totalDeposited);


    /*////////////////////////////////////////
    //   ──────ERRORES PERSONALIZADOS─────  //
    ////////////////////////////////////////*/
    /// @notice Error cuando el monto es cero
    error ZeroAmount();

    /// @notice Error cuando el depósito excede el límite global del banco
    error BankCapExceeded(uint256 attempted, uint256 total, uint256 cap);

    /// @notice Error cuando el usuario intenta retirar más de su saldo
    error InsufficientBalance(uint256 requested, uint256 available);

    /// @notice Error cuando el retiro excede el límite por transacción
    error WithdrawLimitExceeded(uint256 requested, uint256 limit);

    /// @notice Error cuando la transferencia falla
    error TransferFailed();

    /// @notice Error si los parámetros del constructor son inválidos
    error InvalidConstructorParams();


    /*////////////////////////////////////////
    //  ─────────── CONSTRUCTOR ──────────  //
    ////////////////////////////////////////*/
    /**
     * @param _bankCap Límite global máximo de depósitos en el contrato
     * @param _withdrawLimitPerTx Límite máximo de retiro por transacción
     */
    constructor(uint256 _bankCap, uint256 _withdrawLimitPerTx) {
        if (_bankCap == 0 || _withdrawLimitPerTx == 0) revert InvalidConstructorParams();
        bankCap = _bankCap;
        withdrawLimitPerTx = _withdrawLimitPerTx;
    }


    /*////////////////////////////////////////
    // ─────────── MODIFICADORES ────────── //
    ////////////////////////////////////////*/
    /// @dev Verifica que el monto sea mayor que cero
    modifier nonZero(uint256 amount) {
        if (amount == 0) revert ZeroAmount();
        _;
    }


    /*////////////////////////////////////////
    // ──────── FUNCIONES EXTERNAS ──────── //
    ////////////////////////////////////////*/
    /**
 * @notice Deposita ETH en la bóveda personal
 */
function deposit() external payable nonZero(msg.value) {
    if (totalDeposited + msg.value > bankCap) {
        revert BankCapExceeded(msg.value, totalDeposited, bankCap);
    }

    _addBalance(msg.sender, msg.value);
    totalDeposited += msg.value;
    depositCount++;

    emit Deposit(msg.sender, msg.value, _balances[msg.sender], totalDeposited);
}

    /**
     * @notice Retira ETH de la bóveda personal hasta el límite permitido
     * @param amount Monto a retirar en wei
     */
    function withdraw(uint256 amount) external nonZero(amount) {
        uint256 balance = _balances[msg.sender];

        if (amount > balance) revert InsufficientBalance(amount, balance);
        if (amount > withdrawLimitPerTx) revert WithdrawLimitExceeded(amount, withdrawLimitPerTx);

        _balances[msg.sender] -= amount;
        totalDeposited -= amount;
        withdrawCount++;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit Withdraw(msg.sender, amount, _balances[msg.sender], totalDeposited);
    }

    /**
     * @notice Consulta el saldo en la bóveda de un usuario
     * @param user Dirección a consultar
     */
    function balanceOf(address user) external view returns (uint256) {
        return _balances[user];
    }


    /*////////////////////////////////////////
    // ──────── FUNCIONES PRIVADAS ──────── //
    ////////////////////////////////////////*/
    /// @dev Ejemplo de función privada auxiliar (podrías expandirla para contadores por usuario)
    function _addBalance(address user, uint256 amount) private {
        _balances[user] += amount;
    }

    
    /*////////////////////////////////////////
    // ──────── RECEIVE / FALLBACK ──────── //
    ////////////////////////////////////////*/
    receive() external payable {
        deposit();
    }
}
