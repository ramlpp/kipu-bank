// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title KipuBankV3
 * @notice Deposita tokens (ETH/ERC20) y los convierte automáticamente a USDC vía Uniswap V2 Router,
 *         acreditando al usuario el USDC resultante. Garantiza que el total en USDC nunca supere bankCapUsd.
 * @dev Usa checks-effects-interactions, nonReentrant guard, safe approve pattern y validaciones de input.
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
}

/* -------------------------------------------------------------------------- */
/*                               KipuBankV3 Contract                           */
/* -------------------------------------------------------------------------- */
contract KipuBankV3 {
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

    /* ========== EVENTS & ERRORS ========== */
    event DepositConverted(address indexed user, address indexed tokenIn, uint256 amountIn, uint256 usdcReceived);
    event DepositUSDC(address indexed user, uint256 amountUsdc);
    event WithdrawUSDC(address indexed user, uint256 amountUsdc);
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    error Reentrant();
    error ZeroAmount();
    error BankCapExceeded(uint256 attempted, uint256 total, uint256 cap);
    error InsufficientBalance(uint256 available, uint256 requested);
    error NotOwner();
    error SwapFailed();
    error InvalidPath();

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
        WETH = router.WETH();
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

    /* ========== VIEW HELPERS ========== */

    function usdcBalanceOf(address user) external view returns (uint256) {
        return usdcBalances[user];
    }

    /* ========== DEPOSITS ========== */

    /**
     * @notice Deposit USDC directly (user must approve this contract)
     * @param amountUsdc amount of USDC in USDC smallest units (6 decimals)
     */
    function depositUSDC(uint256 amountUsdc) external nonReentrant {
        if (amountUsdc == 0) revert ZeroAmount();
        // transfer USDC into contract
        bool ok = IERC20(USDC).transferFrom(msg.sender, address(this), amountUsdc);
        if (!ok) revert SwapFailed();

        // check bank cap
        if (totalUsdc + amountUsdc > bankCapUsd) {
            // refund
            IERC20(USDC).transfer(msg.sender, amountUsdc);
            revert BankCapExceeded(amountUsdc, totalUsdc, bankCapUsd);
        }

        // effect
        totalUsdc += amountUsdc;
        usdcBalances[msg.sender] += amountUsdc;

        emit DepositUSDC(msg.sender, amountUsdc);
    }

    /**
     * @notice Deposit ETH (native). Contract swaps ETH -> USDC via UniswapV2.
     * @param minUsdcOut minimum acceptable USDC out to protect from slippage (USDC smallest units)
     */
    function depositETHSwapToUSDC(uint256 minUsdcOut) external payable nonReentrant {
        if (msg.value == 0) revert ZeroAmount();

        // Wrap ETH to WETH
        IWETH(WETH).deposit{value: msg.value}();

        // Aprobar router
        _safeApprove(WETH, address(router), msg.value);

        // Declarar path de 2 posiciones (WETH → USDC)
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = USDC;

        // Ejecutar swap
        uint deadline = block.timestamp + 300;
        uint[] memory amounts = router.swapExactTokensForTokens(
            msg.value,
            minUsdcOut,
            path,
            address(this),
            deadline
        );
        if (amounts.length < 2) revert SwapFailed();

        uint usdcReceived = amounts[amounts.length - 1];

        // Validar bank cap antes de acreditar
        if (totalUsdc + usdcReceived > bankCapUsd) {
            IERC20(USDC).transfer(msg.sender, usdcReceived);
            revert BankCapExceeded(usdcReceived, totalUsdc, bankCapUsd);
        }

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
     */
    function depositTokenSwapToUSDC(
        address token,
        uint256 amountIn,
        uint256 minUsdcOut
    ) external nonReentrant {
        if (amountIn == 0) revert ZeroAmount();
        if (token == address(0) || token == USDC) revert InvalidPath();

        // transfer token into this contract
        bool ok1 = IERC20(token).transferFrom(msg.sender, address(this), amountIn);
        if (!ok1) revert SwapFailed();

        // approve router (safe approve pattern)
        _safeApprove(token, address(router), amountIn);

        // build direct path [token, USDC]
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = USDC;

        // do swap
        uint deadline = block.timestamp + 300;
        uint[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            minUsdcOut,
            path,
            address(this),
            deadline
        );
        if (amounts.length < 2) revert SwapFailed();

        uint usdcReceived = amounts[amounts.length - 1];

        // check bank cap before crediting
        if (totalUsdc + usdcReceived > bankCapUsd) {
            // revert swap state: attempt refund of input token (best-effort)
            IERC20(USDC).transfer(msg.sender, usdcReceived);
            revert BankCapExceeded(usdcReceived, totalUsdc, bankCapUsd);
        }

        // effect
        totalUsdc += usdcReceived;
        usdcBalances[msg.sender] += usdcReceived;

        emit DepositConverted(msg.sender, token, amountIn, usdcReceived);
    }

    /* ========== WITHDRAW ========== */

    /**
     * @notice Withdraw USDC from your internal balance
     * @param amountUsdc amount in USDC smallest units
     */
    function withdrawUSDC(uint256 amountUsdc) external nonReentrant {
        if (amountUsdc == 0) revert ZeroAmount();
        uint bal = usdcBalances[msg.sender];
        if (amountUsdc > bal) revert InsufficientBalance(bal, amountUsdc);

        // effects
        usdcBalances[msg.sender] = bal - amountUsdc;
        totalUsdc -= amountUsdc;

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

    /* ========== FALLBACK / RECEIVE ========== */

    receive() external payable {
        //Probe la siguiente linea pero remix no me la está compilando y no encuentro el error

        // depositETHSwapToUSDC(0);
        
        //Entonces opté por está opcion robusta:
        (bool success, ) = address(this).call(
            abi.encodeWithSignature("depositETHSwapToUSDC(uint256)", 0)
        );
        require(success, "Deposit failed");
    }

    fallback() external payable {
        revert();
    }
}