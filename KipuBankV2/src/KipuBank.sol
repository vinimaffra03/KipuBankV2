// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @author Vinicius Maffra
 * @title KipuBankV2
 * @dev A multi-token bank contract supporting ETH and USD deposits/withdrawals with Chainlink price feeds and role-based access control.
 * @notice This contract demonstrates advanced Solidity patterns including multi-token accounting, decimal conversion, and oracle integration.
 */
contract KipuBank is ReentrancyGuard, AccessControl {
    /* ===========================================
     *          Custom Type Declarations
     * =========================================== */
    
    /// @notice Type alias for USD values with 6 ecimals for type safety
    /// @dev Improves code readability and prevents mixing different decimal representations
    type USDValue is uint256;
    
    /// @notice Type alias for ETH amounts in wei (18 decimals)
    /// @dev Provides semantic meaning to raw uint256 values representing ETH
    type ETHAmount is uint256;
    
    /// @notice Enumeration representing the operational status of the bank
    /// @dev Provides clear state management and prevents invalid state transitions
    enum BankStatus {
        Active,      // Bank is operational and accepting deposits/withdrawals
        Paused,      // Bank deposits are paused (withdrawals may still work)
        Maintenance  // Bank is under maintenance (future use)
    }
    
    /// @notice Struct to represent a deposit transaction record
    /// @dev Stores comprehensive information about each deposit for auditing and tracking
    struct DepositRecord {
        address token;           // Token address (address(0) for ETH)
        uint256 originalAmount; // Original amount deposited in token's native decimals
        uint256 usdValue;        // USD equivalent value with 6 decimals
        uint256 timestamp;       // Block timestamp when deposit was made
        address depositor;       // Address that made the deposit
    }
    
    /// @notice Struct to track token-specific accounting information
    /// @dev Consolidates token-related data for better organization and extensibility
    struct TokenInfo {
        address tokenAddress;        // Address of the token contract
        string symbol;               // Token symbol ("ETH", "USDC", etc.)
        uint8 decimals;              // Number of decimals for the token
        uint256 totalDepositsUSD;    // Total deposits in USD (6 decimals)
        bool isSupported;            // Whether this token is currently supported
    }

    /* ===========================================
     *                  Constants
     * =========================================== */
    
    /// @notice Version of the KipuBank contract
    string public constant VERSION = "2.3.0";
    
    /// @notice Role for administrators who can manage the bank
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    /// @notice Role for operators who can perform restricted operations
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    
    /// @notice Standard number of decimals for internal USD accounting (6 decimals like USDC)
    uint8 public constant USD_DECIMALS = 6;
    
    /// @notice ETH has 18 decimals
    uint8 public constant ETH_DECIMALS = 18;
    
    /// @notice Chainlink price feeds have 8 decimals
    uint8 public constant CHAINLINK_DECIMALS = 8;
    
    /// @notice Conversion factor for ETH to USD accounting
    /// @dev ETH_DECIMALS (18) + CHAINLINK_DECIMALS (8) - USD_DECIMALS (6) = 20
    uint256 private constant ETH_TO_USD_CONVERSION_FACTOR = 10 ** (ETH_DECIMALS + CHAINLINK_DECIMALS - USD_DECIMALS);
    
    /// @notice Conversion factor for USD to ETH accounting  
    /// @dev Same as ETH_TO_USD_CONVERSION_FACTOR but named for clarity
    uint256 private constant USD_TO_ETH_CONVERSION_FACTOR = 10 ** (ETH_DECIMALS + CHAINLINK_DECIMALS - USD_DECIMALS);

    /* ===========================================
     *               State variables
     * =========================================== */

    /// @notice Chainlink Data Feed for ETH/USD price
    AggregatorV3Interface private dataFeed;

    /// @notice USDC token contract address
    IERC20 private usdcToken;

    /// @notice Total number of deposit operations performed
    uint256 private depositsCount;
    
    /// @notice Total number of withdrawal operations performed
    uint256 private withdrawalsCount;
    
    /// @notice Maximum amount that can be withdrawn in a single transaction (in USD with 6 decimals)
    uint256 private immutable withdrawalLimitUSD;
    
    /// @notice Total limit of value that can be deposited in the bank (in USD with 6 decimals)
    uint256 private immutable bankCapUSD;
    
    /// @notice Mapping of user addresses to token addresses to their balances (in USD with 6 decimals)
    /// @dev address(0) represents ETH, other addresses represent ERC-20 tokens
    mapping(address => mapping(address => uint256)) public balances;
    
    /// @notice Mapping to track total deposits per token (in USD with 6 decimals)
    mapping(address => uint256) public totalTokenDeposits;
    
    /// @notice Bank operational status using enum for type safety
    BankStatus private bankStatus;
    
    /// @notice Mapping to store deposit records for historical tracking
    /// @dev Indexed by deposit count for sequential access
    mapping(uint256 => DepositRecord) private depositHistory;
    
    /// @notice Mapping to store token information for supported tokens
    /// @dev Allows easy lookup of token metadata and accounting
    mapping(address => TokenInfo) private tokenRegistry;

    /* ===========================================
     *                  Events
     * =========================================== */
    /// @notice Emitted when a user makes a deposit
    /// @param account Address of the user making the deposit
    /// @param token Address of the token (address(0) for ETH)
    /// @param tokenSymbol Symbol of the token ("ETH" for native ETH, "USDC" for USD)
    /// @param originalAmount Original amount deposited in token's native decimals
    /// @param usdValue USD value stored internally (with 6 decimals)
    event Deposit(address indexed account, address indexed token, string tokenSymbol, uint256 originalAmount, uint256 usdValue);
    
    /// @notice Emitted when a user makes a withdrawal
    /// @param account Address of the user making the withdrawal
    /// @param token Address of the token (address(0) for ETH)
    /// @param tokenSymbol Symbol of the token ("ETH" for native ETH, "USDC" for USD)
    /// @param originalAmount Original amount withdrawn in token's native decimals
    /// @param usdValue USD value withdrawn from internal accounting (with 6 decimals)
    event Withdraw(address indexed account, address indexed token, string tokenSymbol, uint256 originalAmount, uint256 usdValue);

    /// @notice Emitted when bank is paused by admin
    event BankPaused(address indexed admin);
    
    /// @notice Emitted when bank is unpaused by admin
    event BankUnpaused(address indexed admin);
    
    /// @notice Emitted when data feed is updated by operator
    event DataFeedUpdated(address indexed operator, address oldDataFeed, address newDataFeed);

    /// @notice Emitted when the USDC address is updated by operator
    event USDCAddressUpdated(address indexed operator, address oldUSDC, address newUSDC);
    
    /// @notice Emitted when a role is granted to a user
    event RoleGrantedByAdmin(address indexed admin, address indexed account, bytes32 indexed role);

    /* ===========================================
     *                  Errors
     * =========================================== */
    /// @notice Error thrown when a deposit exceeds the bank's USD capacity
    /// @param attemptedUSD USD value attempted to deposit
    /// @param availableUSD Available USD capacity in the bank
    error ExceedsBankCapUSD(uint256 attemptedUSD, uint256 availableUSD);
    
    /// @notice Error thrown when a withdrawal exceeds the per-transaction limit
    /// @param attemptedUSD USD value attempted to withdraw
    /// @param limitUSD Maximum withdrawal limit in USD
    error ExceedsWithdrawLimitUSD(uint256 attemptedUSD, uint256 limitUSD);
    
    /// @notice Error thrown when a user tries to withdraw more than their balance
    /// @param availableUSD User's available balance in USD
    /// @param requiredUSD Amount requested for withdrawal in USD
    error InsufficientBalanceUSD(uint256 availableUSD, uint256 requiredUSD);
    
    /// @notice Error thrown when an ETH transfer fails
    error TransferFailed();
    
    /// @notice Error thrown when the withdrawal limit in constructor is invalid
    error InvalidWithdrawLimit();
    
    /// @notice Error thrown when the bank capacity in constructor is invalid
    error InvalidBankCap();

    /// @notice Error thrown when the provided contract address is invalid
    error InvalidContract();
    
    /// @notice Error thrown when trying to deposit 0 amount
    error ZeroAmount();
    
    /// @notice Error thrown when Chainlink price feed returns invalid data
    error InvalidPriceData();
    
    /// @notice Error thrown when token transfer fails
    error TokenTransferFailed();

    /// @notice Error thrown when bank is paused due to maintenance
    error BankPausedError();

    /**
     * @dev Constructor that sets the limits and configures access control.
     * @param _withdrawalLimitUSD Withdrawal limit per transaction in USD (with 6 decimals).
     * @param _bankCapUSD Global deposit limit in USD (with 6 decimals).
     * @param _dataFeed Address of the Chainlink ETH/USD price feed.
     * @param _usdcToken Address of the USDC token contract.
     */
    constructor(
        uint256 _withdrawalLimitUSD, 
        uint256 _bankCapUSD, 
        address _dataFeed, 
        address _usdcToken
    ) {
        if (_withdrawalLimitUSD == 0) {
            revert InvalidWithdrawLimit();
        }
        if (_bankCapUSD == 0) {
            revert InvalidBankCap();
        }
        if(_dataFeed == address(0)) {
            revert InvalidContract();
        }
        if(_usdcToken == address(0)) {
            revert InvalidContract();
        }
        
        withdrawalLimitUSD = _withdrawalLimitUSD;
        bankCapUSD = _bankCapUSD;
        dataFeed = AggregatorV3Interface(_dataFeed);
        usdcToken = IERC20(_usdcToken);
        bankStatus = BankStatus.Active;
        
        // Initialize token registry for supported tokens
        tokenRegistry[address(0)] = TokenInfo({
            tokenAddress: address(0),
            symbol: "ETH",
            decimals: ETH_DECIMALS,
            totalDepositsUSD: 0,
            isSupported: true
        });
        
        tokenRegistry[address(usdcToken)] = TokenInfo({
            tokenAddress: address(usdcToken),
            symbol: "USDC",
            decimals: USD_DECIMALS,
            totalDepositsUSD: 0,
            isSupported: true
        });
        
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
    }

    /**
     * @dev Modifier to check if bank is not paused
     * @notice Uses BankStatus enum for type-safe state checking
     */
    modifier whenNotPaused() {
        if (bankStatus == BankStatus.Paused || bankStatus == BankStatus.Maintenance) {
            revert BankPausedError();
        }
        _;
    }

    /**
     * @dev Allows users to deposit ETH into their personal vault.
     * @notice Requires that the deposit does not exceed the global bank USD limit and bank is not paused.
     */
    function deposit() external payable nonReentrant whenNotPaused {
        if (msg.value == 0) {
            revert ZeroAmount();
        }
        
        // Get current ETH price and convert to USD with 6 decimals
        uint256 usdValue = _convertETHToUSD(msg.value);
        
        // Check bank capacity in USD
        uint256 currentTotalUSD = _getTotalBankValueUSD();
        if (currentTotalUSD + usdValue > bankCapUSD) {
            revert ExceedsBankCapUSD(usdValue, bankCapUSD - currentTotalUSD);
        }
        
        // Effects - store balance in USD for internal accounting
        balances[msg.sender][address(0)] += usdValue;
        totalTokenDeposits[address(0)] += usdValue;
        
        // Store deposit record using custom types
        depositHistory[depositsCount] = DepositRecord({
            token: address(0),
            originalAmount: msg.value,
            usdValue: usdValue,
            timestamp: block.timestamp,
            depositor: msg.sender
        });
        
        // Update token registry
        tokenRegistry[address(0)].totalDepositsUSD += usdValue;
        
        ++depositsCount;
        
        // Event emission
        emit Deposit(msg.sender, address(0), "ETH", msg.value, usdValue);
    }

    /**
     * @dev Allows users to deposit USDC into their personal vault.
     * @notice Requires prior approval of the USDC transfer and bank is not paused.
     * @param amount Amount of USDC to deposit (with 6 decimals).
     */
    function depositUSD(uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) {
            revert ZeroAmount();
        }
        
        // Check bank capacity in USD
        uint256 currentTotalUSD = _getTotalBankValueUSD();
        if (currentTotalUSD + amount > bankCapUSD) {
            revert ExceedsBankCapUSD(amount, bankCapUSD - currentTotalUSD);
        }
        
        // Transfer USDC from user to contract (standard ERC20 method)
        bool success = usdcToken.transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert TokenTransferFailed();
        }
        
        // Effects - USDC already has 6 decimals, store directly
        balances[msg.sender][address(usdcToken)] += amount;
        totalTokenDeposits[address(usdcToken)] += amount;
        
        // Store deposit record using custom types
        depositHistory[depositsCount] = DepositRecord({
            token: address(usdcToken),
            originalAmount: amount,
            usdValue: amount,
            timestamp: block.timestamp,
            depositor: msg.sender
        });
        
        // Update token registry
        tokenRegistry[address(usdcToken)].totalDepositsUSD += amount;
        
        ++depositsCount;
        
        // Event emission
        emit Deposit(msg.sender, address(usdcToken), "USDC", amount, amount);
    }

    /**
     * @dev Allows users to withdraw ETH from their personal vault.
     * @param amount Amount of ETH to withdraw in wei.
     */
    function withdraw(uint256 amount) external nonReentrant {
        if (amount == 0) {
            revert ZeroAmount();
        }
        
        // Convert ETH amount to USD for limit checking
        uint256 usdValue = _convertETHToUSD(amount);
        
        // Checks - use immutable limit
        if (usdValue > withdrawalLimitUSD) {
            revert ExceedsWithdrawLimitUSD(usdValue, withdrawalLimitUSD);
        }
        
        uint256 userBalanceUSD = balances[msg.sender][address(0)];
        if (userBalanceUSD < usdValue) {
            revert InsufficientBalanceUSD(userBalanceUSD, usdValue);
        }
        
        // Effects
        balances[msg.sender][address(0)] -= usdValue;
        totalTokenDeposits[address(0)] -= usdValue;
        
        // Update token registry
        tokenRegistry[address(0)].totalDepositsUSD -= usdValue;
        
        ++withdrawalsCount;
        emit Withdraw(msg.sender, address(0), "ETH", amount, usdValue);
        
        // Interactions
        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) {
            revert TransferFailed();
        }
    }

    /**
     * @dev Allows users to withdraw USDC from their personal vault.
     * @param amount Amount of USDC to withdraw (with 6 decimals).
     */
    function withdrawUSD(uint256 amount) external nonReentrant {
        if (amount == 0) {
            revert ZeroAmount();
        }
        
        // Checks - use immutable limit
        if (amount > withdrawalLimitUSD) {
            revert ExceedsWithdrawLimitUSD(amount, withdrawalLimitUSD);
        }
        
        uint256 userBalanceUSD = balances[msg.sender][address(usdcToken)];
        if (userBalanceUSD < amount) {
            revert InsufficientBalanceUSD(userBalanceUSD, amount);
        }
        
        // Effects
        balances[msg.sender][address(usdcToken)] -= amount;
        totalTokenDeposits[address(usdcToken)] -= amount;
        
        // Update token registry
        tokenRegistry[address(usdcToken)].totalDepositsUSD -= amount;
        
        ++withdrawalsCount;
        emit Withdraw(msg.sender, address(usdcToken), "USDC", amount, amount);
        
        // Interactions - standard ERC20 transfer
        bool success = usdcToken.transfer(msg.sender, amount);
        if (!success) {
            revert TokenTransferFailed();
        }
    }

    /**
     * @dev Gets the current ETH price in USD from Chainlink.
     * @return The current ETH price in USD with 8 decimals.
     * @notice This function gets the latest price from the data feed.
     */
    function _getETHPriceUSD() private view returns (uint256) {
        (
            /* uint80 roundId */,
            int256 price,
            /*uint256 startedAt */,
            uint256 updatedAt,
            /* uint80 answeredInRound */
        ) = dataFeed.latestRoundData();
        
        // Check if price is positive and recent (within 1 hour)
        if (price <= 0) {
            revert InvalidPriceData();
        }
        if (updatedAt < block.timestamp - 3600) {
            revert InvalidPriceData();
        }
        
        return uint256(price);
    }

    /**
     * @dev Converts ETH amount to USD with 6 decimals for internal accounting.
     * @param ethAmount Amount of ETH in wei (18 decimals).
     * @return USD value with 6 decimals.
     */
    function _convertETHToUSD(uint256 ethAmount) private view returns (uint256) {
        uint256 ethPriceUSD8 = _getETHPriceUSD(); // 8 decimals
        // Convert: (ethAmount * price) / CONVERSION_FACTOR
        // Where CONVERSION_FACTOR = 10^(18 + 8 - 6) = 10^20
        return (ethAmount * ethPriceUSD8) / ETH_TO_USD_CONVERSION_FACTOR;
    }

    /**
     * @dev Converts USD (6 decimals) back to ETH amount.
     * @param usdAmount USD amount with 6 decimals.
     * @return ETH amount in wei (18 decimals).
     */
    function _convertUSDToETH(uint256 usdAmount) private view returns (uint256) {
        uint256 ethPriceUSD8 = _getETHPriceUSD(); // 8 decimals
        // Convert: (usdAmount * CONVERSION_FACTOR) / price
        // Where CONVERSION_FACTOR = 10^(18 + 8 - 6) = 10^20
        return (usdAmount * USD_TO_ETH_CONVERSION_FACTOR) / ethPriceUSD8;
    }

    /**
     * @dev Gets the total bank value in USD (6 decimals).
     * @return Total USD value of all deposits.
     */
    function _getTotalBankValueUSD() private view returns (uint256) {
        return totalTokenDeposits[address(0)] + totalTokenDeposits[address(usdcToken)];
    }

    /**
     * @dev Public view function to get the current ETH price in USD.
     * @return The current ETH price in USD with 8 decimals.
     * @notice This function can be called by any user without gas cost.
     */
    function getETHPriceUSD() external view returns (uint256) {
        return _getETHPriceUSD();
    }

    /**
     * @dev Public view function to get the current data feed address.
     * @return The address of the current Chainlink data feed.
     * @notice This function can be called by any user without gas cost.
     */
    function getDataFeed() external view returns (address) {
        return address(dataFeed);
    }

    /**
     * @dev Public view function to get the current USDC token address.
     * @return The address of the USDC token contract.
     * @notice This function can be called by any user without gas cost.
     */
    function getUSDCAddress() external view returns (address) {
        return address(usdcToken);
    }

    /**
     * @dev Public view function to get the current total bank value in USD.
     * @return The total USD value currently deposited in the bank (6 decimals).
     * @notice This function can be called by any user without gas cost.
     */
    function getBankValueUSD() external view returns (uint256) {
        return _getTotalBankValueUSD();
    }

    /**
     * @dev Public view function to get the USD capacity limit.
     * @return The maximum USD value that can be deposited in the bank (6 decimals).
     * @notice This function can be called by any user without gas cost.
     */
    function getBankCapUSD() external view returns (uint256) {
        return bankCapUSD;
    }

    /**
     * @dev Public view function to get the withdrawal limit in USD.
     * @return The maximum USD value that can be withdrawn per transaction (6 decimals).
     * @notice This function can be called by any user without gas cost.
     */
    function getWithdrawalLimitUSD() external view returns (uint256) {
        return withdrawalLimitUSD;
    }

    /**
     * @dev Public view function to query the total number of deposits made.
     * @return The total number of completed deposit operations.
     * @notice This function can be called by any user without gas cost.
     */
    function getDepositsCount() external view returns (uint256) {
        return depositsCount;
    }

    /**
     * @dev Public view function to query the total number of withdrawals made.
     * @return The total number of completed withdrawal operations.
     * @notice This function can be called by any user without gas cost.
     */
    function getWithdrawalsCount() external view returns (uint256) {
        return withdrawalsCount;
    }

    /**
     * @dev Public view function to query the bank's total ETH balance.
     * @return The total balance of ETH currently held by the bank.
     * @notice This function can be called by any user without gas cost.
     */
    function getBankETHBalance() external view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Public view function to query the bank's total USDC balance.
     * @return The total balance of USDC currently held by the bank.
     * @notice This function can be called by any user without gas cost.
     */
    function getBankUSDCBalance() external view returns (uint256) {
        return usdcToken.balanceOf(address(this));
    }

    /**
     * @dev Public view function to query a user's balance for a specific token in USD.
     * @param account Address of the user to query.
     * @param token Address of the token (address(0) for ETH).
     * @return The user's current balance in USD (6 decimals).
     * @notice This function can be called by any user without gas cost.
     */
    function getUserBalanceUSD(address account, address token) external view returns (uint256) {
        return balances[account][token];
    }

    /**
     * @dev Public view function to query a user's total balance across all tokens in USD.
     * @param account Address of the user to query.
     * @return The user's total balance in USD (6 decimals).
     * @notice This function can be called by any user without gas cost.
     */
    function getUserTotalBalanceUSD(address account) external view returns (uint256) {
        return balances[account][address(0)] + balances[account][address(usdcToken)];
    }

    /**
     * @dev Public view function to query a user's ETH balance in native units.
     * @param account Address of the user to query.
     * @return The user's ETH balance in wei.
     * @notice This function can be called by any user without gas cost.
     */
    function getUserETHBalance(address account) external view returns (uint256) {
        uint256 usdBalance = balances[account][address(0)];
        if (usdBalance == 0) return 0;
        return _convertUSDToETH(usdBalance);
    }

    /**
     * @dev Public view function to check if bank is paused.
     * @return True if bank deposits are paused, false otherwise.
     */
    function isBankPaused() external view returns (bool) {
        return bankStatus == BankStatus.Paused || bankStatus == BankStatus.Maintenance;
    }
    
    /**
     * @dev Public view function to get the current bank status.
     * @return Current BankStatus enum value (Active, Paused, or Maintenance).
     */
    function getBankStatus() external view returns (BankStatus) {
        return bankStatus;
    }
    
    /**
     * @dev Public view function to retrieve a deposit record by index.
     * @param depositIndex Index of the deposit record to retrieve.
     * @return Deposit record containing token, amounts, timestamp, and depositor.
     */
    function getDepositRecord(uint256 depositIndex) external view returns (DepositRecord memory) {
        return depositHistory[depositIndex];
    }
    
    /**
     * @dev Public view function to get token information from the registry.
     * @param token Address of the token (address(0) for ETH).
     * @return TokenInfo struct containing token metadata and accounting data.
     */
    function getTokenInfo(address token) external view returns (TokenInfo memory) {
        return tokenRegistry[token];
    }

    /* ===========================================
     *        Admin functions (ADMIN_ROLE)
     * =========================================== */
    /**
     * @dev Emergency function to pause the bank (deposits only).
     * @notice Only admins can call this function. Withdrawals remain active.
     * @notice Uses BankStatus enum for type-safe state management.
     */
    function pauseBank() external onlyRole(ADMIN_ROLE) {
        bankStatus = BankStatus.Paused;
        emit BankPaused(msg.sender);
    }

    /**
     * @dev Function to unpause the bank.
     * @notice Only admins can call this function.
     * @notice Restores bank to Active status using enum for type safety.
     */
    function unpauseBank() external onlyRole(ADMIN_ROLE) {
        bankStatus = BankStatus.Active;
        emit BankUnpaused(msg.sender);
    }

    /**
     * @dev Grant OPERATOR_ROLE to a new user.
     * @notice Only admins can call this function.
     * @param account Address to grant operator role to.
     */
    function grantOperatorRole(address account) external onlyRole(ADMIN_ROLE) {
        if (account == address(0)) {
            revert InvalidContract();
        }
        
        _grantRole(OPERATOR_ROLE, account);
        emit RoleGrantedByAdmin(msg.sender, account, OPERATOR_ROLE);
    }

    /* ===========================================
     *     Operator functions (OPERATOR_ROLE)
     * =========================================== */
    /**
     * @dev Update the Chainlink data feed address.
     * @notice Only operators can call this function.
     * @param newDataFeed New Chainlink data feed address.
     */
    function updateDataFeed(address newDataFeed) external onlyRole(OPERATOR_ROLE) {
        if (newDataFeed == address(0)) {
            revert InvalidContract();
        }
        
        address oldDataFeed = address(dataFeed);
        dataFeed = AggregatorV3Interface(newDataFeed);
        
        emit DataFeedUpdated(msg.sender, oldDataFeed, newDataFeed);
    }
    
    /**
     * @dev Update the USDC address.
     * @notice Only operators can call this function.
     * @param newUSDC New USDC address.
     */
    function updateUSDC(address newUSDC) external onlyRole(OPERATOR_ROLE) {
        if (newUSDC == address(0)) {
            revert InvalidContract();
        }

        address oldUSDCToken = address(usdcToken);
        usdcToken = IERC20(newUSDC);

        emit USDCAddressUpdated(msg.sender, oldUSDCToken, newUSDC);
    }
}
