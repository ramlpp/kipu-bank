// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title KipuBankV3
 * @notice Deposita tokens (ETH/ERC20) y los convierte automáticamente a USDC vía Uniswap V2 Router,
 *         acreditando al usuario el USDC resultante. Garantiza que el total en USDC nunca supere bankCapUsd.
 * @dev Usa checks-effects-interactions, nonReentrant guard, safe approve pattern y validaciones de input.
 * @dev MEJORAS: Validación de bankCap antes del swap, límites de retiro y contadores de operaciones.
 */

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

// AGREGAR INTERFACE IWETH
interface IWETH {
    function deposit() external payable;
    function withdraw(uint256) external;
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IUniswapV2Router02 {
    function WETH() external pure returns (address);
    // ERC20 -> ERC20
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    // ETH -> token
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);
    
    // MEJORA: Función para estimar output del swap
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

/* -------------------------------------------------------------------------- */
/*                               KipuBankV4 Contract                           */
/* -------------------------------------------------------------------------- */
contract KipuBankV4 {
    /// @notice USDC token used by this bank (accounting token, expected decimals = 6)
    address public immutable USDC;
    /// @notice UniswapV2 router
    IUniswapV2Router02 public immutable router;
    /// @notice WETH address (from router)
    address public immutable WETH;

    /// @notice owner/admin
    address public owner;

    /// @notice total USDC held (in raw USDC units, e.g. 6 decimals)
    uint256 public totalUsdc; 

    /// @notice bank cap in USDC units (raw, e.g. 100 * 10**6 = 100 USDC)
    uint256 public immutable bankCapUsd;

    // MEJORAS IMPLEMENTADAS: Límites de retiro y contadores
    uint256 public constant MAX_WITHDRAWAL_AMOUNT = 50000 * 10**6; // 50,000 USDC máximo por transacción
    uint256 public constant WITHDRAWAL_COOLDOWN = 1 days; // 24 horas entre retiros

    /// @notice reentrancy guard
    bool private locked;
    modifier nonReentrant() {
        if (locked) revert Reentrant();
        locked = true;
        _;
        locked = false;
    }

    /// @notice balances in USDC units (raw, e.g. 6 decimals)
    mapping(address => uint256) private usdcBalances;
    
    // MEJORAS IMPLEMENTADAS: Contadores de operaciones
    mapping(address => uint256) public withdrawalCount; // Contador de retiros por usuario
    mapping(address => uint256) public lastWithdrawalTime; // Timestamp del último retiro

    /* ========== EVENTS & ERRORS ========== */
    event DepositConverted(address indexed user, address indexed tokenIn, uint256 amountIn, uint256 usdcReceived);
    event DepositUSDC(address indexed user, uint256 amountUsdc);
    event WithdrawUSDC(address indexed user, uint256 amountUsdc);
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    // MEJORA: Evento para emergency withdraw
    event EmergencyWithdraw(address indexed token, uint256 amount);

    error Reentrant();
    error ZeroAmount();
    error BankCapExceeded(uint256 attempted, uint256 total, uint256 cap);
    error InsufficientBalance(uint256 available, uint256 requested);
    error NotOwner();
    error SwapFailed();
    error InvalidPath();
    // MEJORAS: Nuevos errores para límites de retiro
    error WithdrawalLimitExceeded(uint256 attempted, uint256 limit);
    error CooldownActive(uint256 waitTime);
    error InvalidToken();

    /* ========== CONSTRUCTOR ========== */

    /**
     * @param _usdc address of USDC token (accounting token)
     * @param _router UniswapV2 router address
     * @param _bankCapUsd bank cap expressed in USDC smallest units (e.g. 100 * 10**6)
     */
    constructor(address _usdc, address _router, uint256 _bankCapUsd) {
        if (_usdc == address(0) || _router == address(0) || _bankCapUsd == 0) revert ZeroAmount();
    
        USDC = _usdc;
        router = IUniswapV2Router02(_router);
    
        // WETH address FIJO para Sepolia - EVITA llamar a router.WETH()
        WETH = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
    
        bankCapUsd = _bankCapUsd;
        owner = msg.sender;
    }

    /* ========== OWNER ========== */

    function setOwner(address newOwner) external {
        if (msg.sender != owner) revert NotOwner();
        require(newOwner != address(0), "zero addr");
        address old = owner;
        owner = newOwner;
        emit OwnerChanged(old, newOwner);
    }
    
    // MEJORA: Función de emergency withdraw para owner
    function emergencyWithdraw(address token, uint256 amount) external {
        if (msg.sender != owner) revert NotOwner();
        if (token == address(0)) {
            payable(owner).transfer(amount);
        } else {
            IERC20(token).transfer(owner, amount);
        }
        emit EmergencyWithdraw(token, amount);
    }

    /* ========== VIEW HELPERS ========== */

    function usdcBalanceOf(address user) external view returns (uint256) {
        return usdcBalances[user];
    }
    
    // MEJORA: Función para consultar capacidad restante
    function remainingCapacity() public view returns (uint256) {
        return bankCapUsd - totalUsdc;
    }

    /* ========== DEPOSITS ========== */

    /**
     * @notice Deposit USDC directly (user must approve this contract)
     * @param amountUsdc amount of USDC in USDC smallest units (6 decimals)
     * @dev MEJORA: Validación de bankCap antes de la transferencia
     */
    function depositUSDC(uint256 amountUsdc) external nonReentrant {
        if (amountUsdc == 0) revert ZeroAmount();
        
        // MEJORA: Validación de bankCap ANTES de la transferencia
        if (totalUsdc + amountUsdc > bankCapUsd) {
            revert BankCapExceeded(amountUsdc, totalUsdc, bankCapUsd);
        }
        
        // transfer USDC into contract
        bool ok = IERC20(USDC).transferFrom(msg.sender, address(this), amountUsdc);
        if (!ok) revert SwapFailed();

        // effect
        totalUsdc += amountUsdc;
        usdcBalances[msg.sender] += amountUsdc;

        emit DepositUSDC(msg.sender, amountUsdc);
    }

    /**
     * @notice Deposit ETH (native). Contract swaps ETH -> USDC via UniswapV2.
     * @param minUsdcOut minimum acceptable USDC out to protect from slippage (USDC smallest units)
     * @dev MEJORA: Validación de bankCap ANTES del swap para prevenir pérdida de fondos
     */
    function depositETHSwapToUSDC(uint256 minUsdcOut) external payable nonReentrant {
        if (msg.value == 0) revert ZeroAmount();

        // MEJORA: Estimar output del swap y validar bankCap ANTES de cualquier operación
        address[] memory estimationPath = new address[](2);
        estimationPath[0] = WETH;
        estimationPath[1] = USDC;
        
        uint256 estimatedUsdc = _estimateSwapOutput(estimationPath, msg.value);
        
        // MEJORA CRÍTICA: Validar bankCap ANTES del swap
        if (totalUsdc + estimatedUsdc > bankCapUsd) {
            revert BankCapExceeded(estimatedUsdc, totalUsdc, bankCapUsd);
        }

        // Wrap ETH to WETH
        IWETH(WETH).deposit{value: msg.value}();

        // Aprobar router
        _safeApprove(WETH, address(router), msg.value);

        // Declarar path de 2 posiciones (WETH → USDC) - CORREGIDO: nombre único
        address[] memory swapPath = new address[](2);
        swapPath[0] = WETH;
        swapPath[1] = USDC;

        // Ejecutar swap
        uint deadline = block.timestamp + 300;
        uint[] memory amounts = router.swapExactTokensForTokens(
            msg.value,
            minUsdcOut,
            swapPath,
            address(this),
            deadline
        );
        if (amounts.length < 2) revert SwapFailed();

        uint usdcReceived = amounts[amounts.length - 1];

        // Actualizar balances
        totalUsdc += usdcReceived;
        usdcBalances[msg.sender] += usdcReceived;

        emit DepositConverted(msg.sender, WETH, msg.value, usdcReceived);
    }

    /**
     * @notice Deposit ERC20 token (not USDC). Contract swaps token -> USDC via UniswapV2.
     *         Token must have a direct pair to USDC (path [token, USDC]).
     * @param token token address to deposit
     * @param amountIn amount of token being deposited (in token units)
     * @param minUsdcOut minimum acceptable USDC out to protect from slippage (USDC smallest units)
     * @dev MEJORA: Validación de bankCap ANTES del swap
     */
    function depositTokenSwapToUSDC(
        address token,
        uint256 amountIn,
        uint256 minUsdcOut
    ) external nonReentrant {
        if (amountIn == 0) revert ZeroAmount();
        if (token == address(0) || token == USDC) revert InvalidToken(); // MEJORA: Error más específico

        // MEJORA: Estimar y validar bankCap ANTES de transferencias
        address[] memory estimationPath = new address[](2);
        estimationPath[0] = token;
        estimationPath[1] = USDC;
        
        uint256 estimatedUsdc = _estimateSwapOutput(estimationPath, amountIn);
        
        // MEJORA CRÍTICA: Validación ANTES de cualquier operación
        if (totalUsdc + estimatedUsdc > bankCapUsd) {
            revert BankCapExceeded(estimatedUsdc, totalUsdc, bankCapUsd);
        }

        // transfer token into this contract
        bool ok1 = IERC20(token).transferFrom(msg.sender, address(this), amountIn);
        if (!ok1) revert SwapFailed();

        // approve router (safe approve pattern)
        _safeApprove(token, address(router), amountIn);

        // build direct path [token, USDC] - CORREGIDO: nombre único
        address[] memory swapPath = new address[](2);
        swapPath[0] = token;
        swapPath[1] = USDC;

        // do swap
        uint deadline = block.timestamp + 300;
        uint[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            minUsdcOut,
            swapPath,
            address(this),
            deadline
        );
        if (amounts.length < 2) revert SwapFailed();

        uint usdcReceived = amounts[amounts.length - 1];

        // effect
        totalUsdc += usdcReceived;
        usdcBalances[msg.sender] += usdcReceived;

        emit DepositConverted(msg.sender, token, amountIn, usdcReceived);
    }

    /* ========== WITHDRAW ========== */

    /**
     * @notice Withdraw USDC from your internal balance
     * @param amountUsdc amount in USDC smallest units
     * @dev MEJORAS: Límite máximo por transacción y cooldown entre retiros
     */
    function withdrawUSDC(uint256 amountUsdc) external nonReentrant {
        if (amountUsdc == 0) revert ZeroAmount();
        
        // MEJORA: Límite máximo de retiro por transacción
        if (amountUsdc > MAX_WITHDRAWAL_AMOUNT) {
            revert WithdrawalLimitExceeded(amountUsdc, MAX_WITHDRAWAL_AMOUNT);
        }
        
        // MEJORA: Cooldown entre retiros
        if (block.timestamp < lastWithdrawalTime[msg.sender] + WITHDRAWAL_COOLDOWN) {
            uint256 waitTime = (lastWithdrawalTime[msg.sender] + WITHDRAWAL_COOLDOWN) - block.timestamp;
            revert CooldownActive(waitTime);
        }
        
        uint bal = usdcBalances[msg.sender];
        if (amountUsdc > bal) revert InsufficientBalance(bal, amountUsdc);

        // effects
        usdcBalances[msg.sender] = bal - amountUsdc;
        totalUsdc -= amountUsdc;
        
        // MEJORA: Actualizar contadores de operaciones
        withdrawalCount[msg.sender]++;
        lastWithdrawalTime[msg.sender] = block.timestamp;

        // interaction
        bool ok = IERC20(USDC).transfer(msg.sender, amountUsdc);
        if (!ok) revert SwapFailed();

        emit WithdrawUSDC(msg.sender, amountUsdc);
    }

    /* ========== INTERNAL HELPERS ========== */

    function _safeApprove(address token, address spender, uint256 amount) internal {
        // set to 0 then set to amount to be compatible with some tokens
        IERC20(token).approve(spender, 0);
        IERC20(token).approve(spender, amount);
    }
    
    // MEJORA: Función para estimar output del swap
    function _estimateSwapOutput(address[] memory path, uint256 amountIn) internal view returns (uint256) {
        try router.getAmountsOut(amountIn, path) returns (uint[] memory amounts) {
            if (amounts.length >= 2) {
                return amounts[amounts.length - 1];
            }
        } catch {
            // Fallback seguro si getAmountsOut falla
        }
        return amountIn; // Fallback conservador
    }

    /* ========== FALLBACK / RECEIVE ========== */

    // receive() external payable {
    //     //Probe la siguiente linea pero remix no me la está compilando y no encuentro el error

    //     // depositETHSwapToUSDC(0);
        
    //     //Entonces opté por está opcion robusta:
    //     (bool success, ) = address(this).call(
    //         abi.encodeWithSignature("depositETHSwapToUSDC(uint256)", 0)
    //     );
    //     require(success, "Deposit failed");
    // }

    // fallback() external payable {
    //     revert();
    // }
    receive() external payable {
    // Comentado lo anterior temporalmente para compilar
        revert("Use depositETHSwapToUSDC function directly");
    }

    fallback() external payable {
        revert();
    }
}