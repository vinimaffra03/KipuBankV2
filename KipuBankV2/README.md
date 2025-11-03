# KipuBank - Smart Contract

![Solidity](https://img.shields.io/badge/Solidity-^0.8.22-blue)
![License](https://img.shields.io/badge/License-MIT-green)

## 📋 Description

KipuBank is a smart contract developed in Solidity that simulates a multi-token decentralized bank. It allows users to deposit and withdraw ETH and USDC with implemented security restrictions, including per-transaction limits and global bank capacity.

### Main Features

- **Multi-Token Support**: Support for ETH and USDC with unified USD accounting
- **Price Oracles**: Chainlink integration for real-time ETH/USD conversions
- **Access Control**: Role-based system (Admin/Operator) with OpenZeppelin AccessControl
- **Advanced Security**: Reentrancy protection and comprehensive validations
- **Configurable Limits**: Global capacity and USD withdrawal limits
- **Events and Statistics**: Complete multi-token operation logging
- **Custom Types**: Type-safe definitions using Solidity structs, enums, and type aliases

## 🆕 Improvements and Design Decisions (KipuBankV2)

This version (KipuBankV2) introduces several architectural improvements over previous iterations:

### **1. Custom Type Declarations**

**Why implemented:**

- **Type Safety**: User-defined types (`USDValue`, `ETHAmount`) provide semantic meaning and prevent accidental mixing of different decimal representations
- **Code Clarity**: Makes it immediately clear what a variable represents (USD vs ETH) without relying solely on naming conventions
- **Future Extensibility**: Type aliases can be extended with library functions for additional operations

**Trade-offs:**

- ✅ Better code readability and maintainability
- ⚠️ Slight increase in code complexity, but improves developer experience
- ✅ Compile-time type checking prevents common decimal mixing bugs

### **2. Enum-Based State Management**

**Why implemented:**

- **BankStatus Enum**: Replaced boolean `bankPaused` with `BankStatus` enum (Active, Paused, Maintenance)
- **Type Safety**: Prevents invalid state transitions (e.g., can't accidentally set an invalid state value)
- **Extensibility**: Easy to add new states (Maintenance mode, Emergency mode, etc.) without breaking changes

**Trade-offs:**

- ✅ More expressive and maintainable state management
- ✅ Prevents invalid state values at compile time
- ⚠️ Slightly more gas for state checks (negligible)

### **3. Structured Data Models**

**Why implemented:**

- **DepositRecord Struct**: Comprehensive deposit tracking with token, amounts, timestamp, and depositor
- **TokenInfo Struct**: Centralized token metadata registry for better organization
- **Historical Tracking**: Deposit history mapping enables audit trails and analytics

**Trade-offs:**

- ✅ Better data organization and query capabilities
- ✅ Enables future features like deposit history queries, analytics, and reporting
- ⚠️ Additional storage costs for historical records (acceptable trade-off for auditability)

### **4. AccessControl over Ownable**

**Why implemented:**

- **Granular Permissions**: Separate ADMIN_ROLE and OPERATOR_ROLE enable fine-grained access control
- **Multi-Admin Support**: Multiple administrators can manage the contract
- **Operational Flexibility**: Operators can update oracles/addresses without full admin privileges

**Trade-offs:**

- ✅ More flexible permission model than single-owner approach
- ⚠️ Slightly higher gas costs for role checks (OpenZeppelin AccessControl overhead)
- ✅ Industry-standard security pattern with proven track record

### **5. Unified USD Accounting with 6 Decimals**

**Why implemented:**

- **Standardization**: USDC uses 6 decimals, so all internal accounting uses this standard
- **Simplified Limits**: Bank capacity and withdrawal limits can be checked in a single currency
- **Precision Balance**: 6 decimals provide sufficient precision for USD amounts while avoiding overflows

**Trade-offs:**

- ✅ Simplified limit checks across different tokens
- ⚠️ Requires real-time ETH price conversion (gas cost on each deposit/withdrawal)
- ✅ Consistent accounting simplifies audit and reporting

### **6. Immutable Configuration Parameters**

**Why implemented:**

- **Security**: `withdrawalLimitUSD` and `bankCapUSD` are immutable, preventing admin abuse
- **Gas Efficiency**: Immutable variables are cheaper than storage variables
- **Trust**: Users can verify limits won't change arbitrarily

**Trade-offs:**

- ✅ Maximum security and user trust
- ⚠️ Requires contract redeployment to adjust limits (acceptable for security-critical parameters)
- ✅ Clear contract guarantees improve transparency

## 🏗️ Contract Architecture

### Key Variables

- `withdrawalLimitUSD` (immutable): Maximum USD per withdrawal
- `bankCapUSD` (immutable): Total bank capacity in USD
- `balances`: User balances mapping by user and token (address(0) = ETH)
- `dataFeed`: Chainlink oracle for ETH/USD prices
- `usdcToken`: USDC contract address

### Main Functions

| Function                         | Visibility       | Description                               |
| -------------------------------- | ---------------- | ----------------------------------------- |
| `deposit()`                      | external payable | Deposit ETH (converted to USD internally) |
| `depositUSD(amount)`             | external         | Deposit USDC directly                     |
| `withdraw(amount)`               | external         | Withdraw ETH (validated in USD)           |
| `withdrawUSD(amount)`            | external         | Withdraw USDC directly                    |
| `getUserBalanceUSD(user, token)` | external view    | View user USD balance by token            |
| `getBankValueUSD()`              | external view    | View total USD value of bank              |
| `getETHPriceUSD()`               | external view    | View current ETH/USD price                |

### Implemented Security

- ✅ **Reentrancy Protection**: OpenZeppelin ReentrancyGuard
- ✅ **Access Control**: Admin/Operator role-based system
- ✅ **CEI Pattern**: Checks-Effects-Interactions properly implemented
- ✅ **Custom Errors**: Specific error types for each validation
- ✅ **Safe Transfers**: Use of `.call()` for ETH and standard ERC20
- ✅ **Oracle Validation**: Verification of valid price data

## 🚀 Deployment on Remix IDE

### Step 1: Preparation

1. Open [Remix IDE](https://remix.ethereum.org)
2. Connect MetaMask to **Sepolia Testnet**
3. Ensure you have test ETH ([Sepolia Faucet](https://faucet.aragua.org/))

### Step 2: Deploy Auxiliary Contracts

1. Compile and deploy `Circle.sol` (USDC stub)
2. Compile and deploy `Oracle.sol` (Price feed stub)
3. Note the deployed addresses

### Step 3: Deploy KipuBank

1. Go to "Solidity Compiler" → Version `0.8.22+`
2. Compile `KipuBank.sol`
3. Configure constructor parameters:

```
_withdrawalLimitUSD: 1000000000     (1,000 USD with 6 decimals)
_bankCapUSD:         5000000000     (5,000 USD with 6 decimals)
_dataFeed:           DEPLOYED_ORACLE_ADDRESS
_usdcToken:          DEPLOYED_CIRCLE_ADDRESS
```

4. Click "Deploy" → Confirm in MetaMask
5. ✅ Contract deployed!

## 🔧 Contract Interaction

### Making ETH Deposits

```javascript
// In Remix:
// 1. Go to "VALUE" → Enter amount in wei
// 2. Click "deposit" button (orange)
// 3. Confirm transaction in MetaMask

Example values:
0.1 ETH = 100000000000000000 wei (~$411.78)
0.05 ETH = 50000000000000000 wei (~$205.89)
```

### Making USDC Deposits

```javascript
// 1. First approve USDC in Circle contract:
approve(KIPUBANK_ADDRESS, 1000000000); // 1,000 USDC

// 2. Then deposit in KipuBank:
depositUSD(1000000000); // 1,000 USDC (6 decimals)
```

### Making Withdrawals

```javascript
// Withdraw ETH:
withdraw(50000000000000000) // 0.05 ETH

// Withdraw USDC:
withdrawUSD(500000000) // 500 USDC

// Automatic validations:
- USD limit per transaction ✓
- Sufficient balance ✓
```

### Public Queries (No Gas)

```javascript
// View USD balance by token
getUserBalanceUSD("0xYourAddress", "0x000...000") → ETH balance in USD
getUserBalanceUSD("0xYourAddress", USDC_ADDRESS) → USDC balance

// View bank statistics
getBankValueUSD() → Total USD value of bank
getETHPriceUSD() → Current ETH/USD price from oracle
getDepositsCount() → Number of deposits
getWithdrawalsCount() → Number of withdrawals
```

## 📊 Events and Monitoring

### Emitted Events

- `Deposit(address indexed account, address indexed token, string tokenSymbol, uint256 originalAmount, uint256 usdValue)`
- `Withdraw(address indexed account, address indexed token, string tokenSymbol, uint256 originalAmount, uint256 usdValue)`
- `BankPaused(address indexed admin)` / `BankUnpaused(address indexed admin)`
- `DataFeedUpdated(address indexed operator, address oldDataFeed, address newDataFeed)`
- `RoleGrantedByAdmin(address indexed admin, address indexed account, bytes32 indexed role)`

Events appear in the Remix console after each successful transaction and include detailed information about original amounts and USD values.

## 🛡️ Custom Errors

| Error                     | When It Occurs                               |
| ------------------------- | -------------------------------------------- |
| `ExceedsBankCapUSD`       | Deposit exceeds bank's USD capacity          |
| `ExceedsWithdrawLimitUSD` | Withdrawal exceeds USD limit per transaction |
| `InsufficientBalanceUSD`  | Insufficient USD balance for withdrawal      |
| `TransferFailed`          | ETH transfer failure                         |
| `InvalidContract`         | Invalid contract address                     |
| `ZeroAmount`              | Attempted deposit/withdrawal with amount 0   |
| `BankPausedError`         | Operation blocked by bank pause              |

## 🧪 Test Cases

See **[USE_CASES.md](USE_CASES.md)** for detailed test cases including:

1. **✅ Valid ETH/USDC deposits**: With automatic USD conversions
2. **✅ Valid ETH/USDC withdrawals**: Validated against USD limits
3. **❌ Exceed bankCapUSD**: Attempt to deposit more than total limit
4. **❌ Exceed withdrawalLimitUSD**: Attempt to withdraw more than per-transaction limit
5. **✅ Admin functions**: Pause/unpause bank, grant roles
6. **✅ Operator functions**: Update price oracles
7. **✅ State queries**: Balances, prices, statistics

**Recommended test configuration:**

- Withdrawal Limit: 1,000 USD
- Bank Cap: 5,000 USD
- Fixed ETH price: $4,117.88 (for testing)

## 🔗 Auxiliary Contracts

### Circle.sol (USDC Stub)

- **Purpose**: Simulates USDC token for testing
- **Decimals**: 6 (same as real USDC)
- **Functions**: `mint()`, `decimals()`, standard ERC20

### Oracle.sol (Price Feed Stub)

- **Purpose**: Simulates Chainlink ETH/USD oracle
- **Fixed price**: $4,117.88 (for consistent testing)
- **Decimals**: 8 (Chainlink standard)
- **Compatibility**: AggregatorV3Interface

### IOracle.sol

- **Purpose**: Interface for Chainlink compatibility
- **Functions**: `latestAnswer()`, `latestRoundData()`

## ⚖️ Additional Design Trade-offs

### **Nested Mappings for Multi-Token Accounting**

- ✅ **Benefit**: Efficient storage and lookup of user balances per token
- ✅ **Gas Efficiency**: O(1) access time, no iteration required
- ⚠️ **Trade-off**: More complex queries require multiple calls (address + token)

### **Oracle Price Validation**

- ✅ **Benefit**: Stale price detection (1-hour timeout) and negative price checks
- ✅ **Security**: Prevents using invalid or outdated price data
- ⚠️ **Trade-off**: Additional gas for timestamp validation, potential for temporary unavailability

### **ReentrancyGuard Usage**

- ✅ **Benefit**: Protection against reentrancy attacks on all external functions
- ✅ **Security**: Industry-standard pattern for funds transfer operations
- ⚠️ **Trade-off**: Small gas overhead (~5,000 gas per transaction)

### **CEI Pattern (Checks-Effects-Interactions)**

- ✅ **Benefit**: Reduces attack surface, ensures state consistency
- ✅ **Best Practice**: Follows Solidity security best practices
- ✅ **No significant trade-off**: Standard pattern with minimal overhead

## ⚠️ Important Notes

- **Testing**: Stub contracts are designed only for development and testing
- **Production**: Use real Chainlink and USDC addresses on mainnet
- **Security**: Perform complete audit before production deployment
- **Oracles**: Fixed price is only for testing, use dynamic feeds in production

## 📄 License

- **KipuBank on Sepolia**: [0xeDaFaFa183Af5356af9e0b2dA8706a3affdE9933](https://sepolia.etherscan.io/address/0x09cE4B882c46c430cA28A4DfD30fFf21DCcDAD29)
- **Custom USDC Token on Sepolia**: [0xb5b73D233Ef9DEdd98f4DbC178099bf311950d0a](https://sepolia.etherscan.io/address/0xc22c484da337f1d4be2cbf27fb1ed69fa772a240)
- **Custom Data Feed on Sepolia**: [0xcdb9f8df0e2224587035a0811a85ce94ec07e0ff](https://sepolia.etherscan.io/address/0xcdb9f8df0e2224587035a0811a85ce94ec07e0ff)
- **Custom fixed ETH Price**: $4,117.88 (411788170000 with 8 decimals)
- **Mint USDC from Custom Circle**: your_address, 10000000000
- **ETH/USD Chainlink Ethereum Sepolia**: [0x694AA1769357215DE4FAC081bf1f309aDC325306](https://sepolia.etherscan.io/address/0x694AA1769357215DE4FAC081bf1f309aDC325306)
- **USDC Ethereum Sepolia**: [0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238](https://sepolia.etherscan.io/address/0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238)

## 📄 License

MIT License - See `LICENSE` for complete details.

---

**⚠️ Important**: This contract is for educational purposes. Stub contracts (Circle, Oracle) are designed only for testing. Perform complete security audit before production use.
