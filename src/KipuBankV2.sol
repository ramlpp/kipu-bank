// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title KipuBankV2
 * @author Dev ramlpp
 * @notice Versión mejorada de KipuBank con soporte multi-token, oráculos Chainlink y control básico de acceso.
 * @dev Uso de checks-effects-interactions, reentrancy guard, errores personalizados y contabilidad multi-token.
 */

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    // optional but common
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
}

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);
  function description() external view returns (string memory);
  function version() external view returns (uint256);
  // getRoundData / latestRoundData
  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
}

/* -------------------------------------------------------------------------- */
/*                               KipuBankV2 Contract                           */
/* -------------------------------------------------------------------------- */
contract KipuBankV2{
    /* ========== CONSTANTS ========== */

    /// @notice número de decimales que adoptamos para la contabilidad interna (USDC style)
    uint8 public constant INTERNAL_DECIMALS = 6; // USDC = 6 decimals

    /* ========== IMMUTABLES ========== */

    /// @notice Límite global del banco en valor USD (con INTERNAL_DECIMALS)
    uint256 public immutable bankCapUsd;

    /// @notice Límite de retiro por transacción expresado en USD (con INTERNAL_DECIMALS)
    uint256 public immutable withdrawLimitUsd;

    /// @notice Oráculo por defecto (ej. ETH/USD) usado cuando token == address(0)
    AggregatorV3Interface public immutable defaultPriceFeed;

    /* ========== STATE ========== */

    /// @notice owner simple (control administrativo)
    address public owner;

    /// @notice mapping token => user => balance (en unidades naturales del token)
    mapping(address => mapping(address => uint256)) private balances;

    /// @notice mapping token => price feed aggregator (Chainlink)
    mapping(address => AggregatorV3Interface) public priceFeeds;

    /// @notice total depositado en USD (internal decimals) — aproximado en tiempo real según conversiones realizadas
    uint256 public totalDepositedUsd;

    /// @notice contadores
    uint256 public totalDepositCount;
    uint256 public totalWithdrawCount;

    /* ========== EVENTS ========== */

    event Deposit(address indexed user, address indexed token, uint256 amount, uint256 amountUsd);
    event Withdraw(address indexed user, address indexed token, uint256 amount, uint256 amountUsd);
    event PriceFeedSet(address indexed token, address indexed feed);
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    /* ========== ERRORS ========== */

    /// @notice Se lanza cuando el argumento amount es cero
    error ErrZeroAmount();

    /// @notice Se lanza cuando el intento de depósito excede el límite global (USD internal)
    error ErrBankCapExceeded(uint256 attemptedUsd, uint256 totalUsd, uint256 capUsd);

    /// @notice Se lanza cuando el usuario solicita más de lo que tiene
    error ErrInsufficientBalance(address token, uint256 available, uint256 requested);

    /// @notice Se lanza cuando el retiro (USD) excede el límite por transacción
    error ErrWithdrawLimitExceeded(uint256 requestedUsd, uint256 limitUsd);

    /// @notice Se lanza cuando una transferencia falla (ERC20 o ETH)
    error ErrTransferFailed(address to, address token, uint256 amount);

    /// @notice Se lanza cuando un caller no está autorizado
    error ErrUnauthorized();

    /// @notice Se lanza en caso de reentrancy detectado
    error ErrReentrantCall();

    /// @notice Parámetros inválidos del constructor
    error InvalidConstructorParams();

    /// @notice Se lanza cuando el oráculo devuelve datos inválidos
    error InvalidOracleResponse(uint80 roundId, uint256 updatedAt, uint80 answeredInRound);

    /* ========== REENTRANCY GUARD ========== */

    bool private locked;
    modifier nonReentrant() {
        if (locked) revert ErrReentrantCall();
        locked = true;
        _;
        locked = false;
    }

    /* ========== ACCESS CONTROL ========== */

    modifier onlyOwner() {
        if (msg.sender != owner) revert ErrUnauthorized();
        _;
    }

    /* ========== MODIFIERS ========== */

    /// @notice Revert when amount == 0
    /// @dev Usa ErrZeroAmount para ahorrar gas en comparación con require con string
    modifier nonZero(uint256 amount) {
        if (amount == 0) revert ErrZeroAmount();
        _;
    }

    /* ========== CONSTRUCTOR ========== */

    /**
     * @param _bankCapUsd límite global del banco (en unidades con INTERNAL_DECIMALS, p.ej 100 * 10**6 para 100 USD)
     * @param _withdrawLimitUsd límite de retiro por tx (en INTERNAL_DECIMALS)
     * @param _defaultPriceFeed dirección del agregador Chainlink para ETH/USD (usado cuando token == address(0))
     */
    constructor(uint256 _bankCapUsd, uint256 _withdrawLimitUsd, address _defaultPriceFeed) {
        if (_bankCapUsd == 0 || _withdrawLimitUsd == 0 || _defaultPriceFeed == address(0)) revert InvalidConstructorParams();
        owner = msg.sender;
        bankCapUsd = _bankCapUsd;
        withdrawLimitUsd = _withdrawLimitUsd;
        defaultPriceFeed = AggregatorV3Interface(_defaultPriceFeed);
    }

    /* ========== ADMIN FUNCTIONS ========== */

    /**
     * @notice Asignar/actualizar price feed para un token (token == address(0) para ETH no debería cambiarse)
     * @dev Solo puede ser llamado por el owner.
     * @param token Dirección del token ERC20 (usar address(0) para ETH si desea override)
     * @param feed Dirección del AggregatorV3Interface (Chainlink) correspondiente al token
     */
    function setPriceFeed(address token, address feed) external onlyOwner {
        priceFeeds[token] = AggregatorV3Interface(feed);
        emit PriceFeedSet(token, feed);
    }

    /**
     * @notice Cambiar owner
     * @dev Solo owner puede llamar. No permite owner = address(0).
     * @param newOwner Nueva dirección del owner
     */
    function setOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero owner");
        address old = owner;
        owner = newOwner;
        emit OwnerChanged(old, newOwner);
    }

    /* ========== PRIVATE HELPERS ========== */

    /**
     * @dev Actualiza el balance interno para `user` y `token`.
     * @param token Token address (address(0) para ETH)
     * @param user Cuenta del usuario
     * @param amount Cantidad en unidades del token
     * @param isDeposit true => sumar, false => restar
     */
    function _updateBalance(address token, address user, uint256 amount, bool isDeposit) private {
        if (isDeposit) {
            balances[token][user] += amount;
        } else {
            // asumimos que ya se validó balance >= amount antes de llamar
            balances[token][user] -= amount;
        }
    }

    /* ========== DEPOSIT FUNCTIONS ========== */

    /**
     * @notice Depositar ETH (usar address(0) para representar ETH internamente)
     */
    function depositETH() external payable nonReentrant nonZero(msg.value) {
        // convertir a USD internal decimals
        uint256 amountUsd = _convertToUsd(address(0), msg.value);
        if (totalDepositedUsd + amountUsd > bankCapUsd) revert ErrBankCapExceeded(amountUsd, totalDepositedUsd, bankCapUsd);

        // efectos (unificados via helper)
        _updateBalance(address(0), msg.sender, msg.value, true);
        totalDepositCount++;
        totalDepositedUsd += amountUsd;

        emit Deposit(msg.sender, address(0), msg.value, amountUsd);
    }

    /**
     * @notice Depositar ERC20. El usuario debe aprobar antes.
     * @param token dirección del token ERC20
     * @param amount cantidad de token (en unidades token)
     */
    function depositERC20(address token, uint256 amount) external nonReentrant nonZero(amount) {
        if (token == address(0)) revert ErrZeroAmount(); // evitar confusión, para ETH usar depositETH
        AggregatorV3Interface feed = priceFeeds[token];
        if (address(feed) == address(0)) revert ErrUnauthorized(); // policy: require price feed set

        // transferencia desde usuario
        bool ok = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!ok) revert ErrTransferFailed(msg.sender, token, amount);

        // conversión
        uint256 amountUsd = _convertToUsd(token, amount);
        if (totalDepositedUsd + amountUsd > bankCapUsd) {
            // revert and return tokens (best-effort)
            IERC20(token).transfer(msg.sender, amount);
            revert ErrBankCapExceeded(amountUsd, totalDepositedUsd, bankCapUsd);
        }

        // efectos (unificados via helper)
        _updateBalance(token, msg.sender, amount, true);
        totalDepositCount++;
        totalDepositedUsd += amountUsd;

        emit Deposit(msg.sender, token, amount, amountUsd);
    }

    /* ========== WITHDRAW FUNCTIONS ========== */

    /**
     * @notice Retirar ETH (address(0))
     * @param amount cantidad en wei
     */
    function withdrawETH(uint256 amount) external nonReentrant nonZero(amount) {
        uint256 bal = balances[address(0)][msg.sender];
        if (amount > bal) revert ErrInsufficientBalance(address(0), bal, amount);

        uint256 amountUsd = _convertToUsd(address(0), amount);
        if (amountUsd > withdrawLimitUsd) revert ErrWithdrawLimitExceeded(amountUsd, withdrawLimitUsd);

        // efectos (unificados via helper)
        _updateBalance(address(0), msg.sender, amount, false);
        totalWithdrawCount++;
        totalDepositedUsd = (amountUsd > totalDepositedUsd) ? 0 : (totalDepositedUsd - amountUsd);

        // interacción
        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        if (!sent) revert ErrTransferFailed(msg.sender, address(0), amount);

        emit Withdraw(msg.sender, address(0), amount, amountUsd);
    }

    /**
     * @notice Retirar ERC20 token
     * @param token dirección del token
     * @param amount cantidad en unidades token
     */
    function withdrawERC20(address token, uint256 amount) external nonReentrant nonZero(amount) {
        uint256 bal = balances[token][msg.sender];
        if (amount > bal) revert ErrInsufficientBalance(token, bal, amount);

        uint256 amountUsd = _convertToUsd(token, amount);
        if (amountUsd > withdrawLimitUsd) revert ErrWithdrawLimitExceeded(amountUsd, withdrawLimitUsd);

        // efectos (unificados via helper)
        _updateBalance(token, msg.sender, amount, false);
        totalWithdrawCount++;
        totalDepositedUsd = (amountUsd > totalDepositedUsd) ? 0 : (totalDepositedUsd - amountUsd);

        // interacción
        bool ok = IERC20(token).transfer(msg.sender, amount);
        if (!ok) revert ErrTransferFailed(msg.sender, token, amount);

        emit Withdraw(msg.sender, token, amount, amountUsd);
    }

    /* ========== VIEWS / HELPERS ========== */

    /// @notice Obtener saldo del usuario para un token
    function balanceOf(address token, address user) external view returns (uint256) {
        return balances[token][user];
    }

    /// @notice Obtener price feed para token (fallback a defaultPriceFeed si no existe)
    function _getFeed(address token) internal view returns (AggregatorV3Interface) {
        AggregatorV3Interface feed = priceFeeds[token];
        if (address(feed) == address(0)) {
            return defaultPriceFeed;
        }
        return feed;
    }

    /**
     * @notice Convierte una cantidad de `token` (en sus unidades) a USD con INTERNAL_DECIMALS.
     * @dev Para ETH usar token == address(0). Usa priceFeeds[token] o defaultPriceFeed.
     *      Valida la integridad de la respuesta del oráculo (updatedAt y answeredInRound).
     */
    function _convertToUsd(address token, uint256 amount) internal view returns (uint256) {
        AggregatorV3Interface feed = _getFeed(token);
        (uint80 roundId, int256 price, , uint256 updatedAt, uint80 answeredInRound) = feed.latestRoundData();
        uint8 feedDecimals = feed.decimals(); // p.ej. 8

        // validaciones de oráculo
        if (price <= 0) revert InvalidOracleResponse(roundId, updatedAt, answeredInRound);
        if (updatedAt == 0) revert InvalidOracleResponse(roundId, updatedAt, answeredInRound);
        if (answeredInRound < roundId) revert InvalidOracleResponse(roundId, updatedAt, answeredInRound);

        uint8 tokenDecimals = 18;
        if (token != address(0)) {
            // intento obtener decimals del token; si falla (no implementado) asumimos 18
            try IERC20(token).decimals() returns (uint8 d) {
                tokenDecimals = d;
            } catch {
                tokenDecimals = 18;
            }
        }

        /**
         * Calculación:
         * amount (token units) * price (USD with feedDecimals) -> intermediate with (tokenDecimals + feedDecimals)
         * queremos resultado con INTERNAL_DECIMALS -> divide por 10**(tokenDecimals + feedDecimals - INTERNAL_DECIMALS)
         */
        uint256 numerator = uint256(price) * amount;
        uint256 decimalsAdjustment;
        // avoid underflow/overflow in calc of power
        if (tokenDecimals + feedDecimals >= INTERNAL_DECIMALS) {
            decimalsAdjustment = tokenDecimals + feedDecimals - INTERNAL_DECIMALS;
            return numerator / (10 ** decimalsAdjustment);
        } else {
            // unlikely, but if INTERNAL_DECIMALS larger, multiply (careful with overflow)
            decimalsAdjustment = INTERNAL_DECIMALS - (tokenDecimals + feedDecimals);
            return numerator * (10 ** decimalsAdjustment);
        }
    }

    /* ========== RECEIVE / FALLBACK ========== */

    /// @notice Permite recibir ETH directo y lo redirige a depositETH
    receive() external payable {
        // depositETH es external, por eso hacemos llamada externa
        this.depositETH{value: msg.value}();
    }

    /// @notice Rechaza llamadas con calldata no válidos
    fallback() external payable {
        revert();
    }
}
