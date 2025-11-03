## 🧪 **KipuBank Test Cases**

## 🔍 **Case 1: Verify Initial Configuration**

### **Actions to execute:**

```
// 1. Verify bank limits
getBankCapUSD()
// Expected result: 5000000000 (5,000 USD)

getWithdrawalLimitUSD()
// Expected result: 1000000000 (1,000 USD)

// 2. Verify oracle price
getETHPriceUSD()
// Expected result: 411788170000 ($4,117.88)

// 3. Verify initial state
getBankValueUSD()
// Expected result: 0

isBankPaused()
// Expected result: false
```

## 🔍 **Case 2: ETH Deposit (Successful)**

### **Action:**

```
// Deposit 0.1 ETH (worth ~$411.78)
deposit()
// Value: 100000000000000000 (0.1 ETH in wei)
```

### **Expected results:**

```
getUserBalanceUSD(YOUR_ADDRESS, "0x0000000000000000000000000000000000000000")
// Expected result: ~411788170 (USD with 6 decimals)

getBankValueUSD()
// Expected result: ~411788170

getDepositsCount()
// Expected result: 1

getUserETHBalance(YOUR_ADDRESS)
// Expected result: ~100000000000000000 (0.1 ETH in wei)
```

### **Expected event:**

`Deposit(your_address, 0x000...000, "ETH", 100000000000000000, 411788170)`

## 🔍 **Case 3: USDC Deposit (Successful)**

### **Preparation:**

```
// 1. First, approve USDC for KipuBank contract
// In Circle contract (USDC):
approve(KIPUBANK_ADDRESS, 1000000000)
// 1000000000 = 1,000 USDC (6 decimals)
```

### **Action:**

```
// 2. Deposit 1,000 USDC
depositUSD(1000000000)
```

### **Expected results:**

```
getUserBalanceUSD(YOUR_ADDRESS, CIRCLE_ADDRESS)
// Expected result: 1000000000

getBankValueUSD()
// Expected result: ~1411788170 (411.78 + 1000)

getDepositsCount()
// Expected result: 2

getBankUSDCBalance()
// Expected result: 1000000000
```

### **Expected events:**

`Transfer(your_address, KIPUBANK_ADDRESS, 1000000000)`
`Deposit(your_address, CIRCLE_ADDRESS, "USDC", 1000000000, 1000000000)`

## 🔍 **Case 4: ETH Withdrawal (Successful)**

### **Action:**

```
// Withdraw 0.05 ETH (worth ~$205.89)
withdraw(50000000000000000)
// 50000000000000000 = 0.05 ETH in wei
```

### **Expected results:**

```
getUserBalanceUSD(YOUR_ADDRESS, "0x0000000000000000000000000000000000000000")
// Expected result: ~205894085 (411.78 - 205.89)

getWithdrawalsCount()
// Expected result: 1

getBankValueUSD()
// Expected result: ~1205894085
```

### **Expected event:**

`Withdraw(your_address, 0x000...000, "ETH", 50000000000000000, 205894085)`

## 🔍 **Case 5: USDC Withdrawal (Successful)**

### **Action:**

```
// Withdraw 500 USDC
withdrawUSD(500000000)
```

### **Expected results:**

```
getUserBalanceUSD(YOUR_ADDRESS, CIRCLE_ADDRESS)
// Expected result: 500000000

getBankUSDCBalance()
// Expected result: 500000000

getWithdrawalsCount()
// Expected result: 2
```

### **Expected events:**

`Withdraw(your_address, CIRCLE_ADDRESS, "USDC", 500000000, 500000000)`
`Transfer(KIPUBANK_ADDRESS, your_address, 500000000)`

---

## 🚫 **Case 6: Attempt to Exceed Withdrawal Limit**

### **Action:**

```
// Attempt to withdraw more than $1,000 USD
// Calculate: 1000 USD / 4117.88 USD/ETH ≈ 0.243 ETH
withdraw(250000000000000000)
// 0.25 ETH in wei (more than $1,000)
```

### **Expected result:**

```
❌ Error: ExceedsWithdrawLimitUSD

{
 "attemptedUSD": {
  "value": "1029470425",
  "documentation": "USD value attempted to withdraw"
 },
 "limitUSD": {
  "value": "1000000000",
  "documentation": "Maximum withdrawal limit in USD"
 }
}
```

---

## 🚫 **Case 7: Attempt to Exceed Bank Cap**

### **Preparation:**

```
// Calculate how much is left to reach $5,000 cap
getBankValueUSD()
// Suppose it returns 705894085 (~$705.89)
// Remaining: 5000 - 705.89 = $4,294.10
```

### **Action:**

```
// Attempt to deposit more USDC than allowed
// Deposit full 5,000 USDC (added to existing balance, exceeds cap)
depositUSD(5000000000)
```

### **Expected result:**

```
❌ Error: ExceedsBankCapUSD
{
 "attemptedUSD": {
  "value": "5000000000",
  "documentation": "USD value attempted to deposit"
 },
 "availableUSD": {
  "value": "4294105915",
  "documentation": "Available USD capacity in the bank"
 }
}
```

---

## 🔍 **Case 8: Admin Functions**

### **Pause as NON-admin user:**

```
// As NON-admin user, pause the bank
pauseBank()
```

### **Expected result:**

```
❌ Error: AccessControlUnauthorizedAccount
{
 "account": {
  "value": "your_address"
 },
 "neededRole": {
  "value": "0xa49807205ce4d355092ef5a8a18f56e8913cf4a201fbe287825b095693c21775"
 }
}
```

### **Pause as admin user:**

```
// As admin, pause the bank
pauseBank()
```

### **Verification:**

```
isBankPaused()
// Expected result: true

// Attempt to deposit with paused bank
deposit()
// Value: 10000000000000000 (0.01 ETH)
// Expected result: ❌ Error: BankPausedError
```

### **Expected event:**

`BankPaused(your_address)`

### **Unpause:**

```
unpauseBank()

isBankPaused()
// Expected result: false
```

### **Expected event:**

`BankUnpaused(your_address)`

### **Grant operator role:**

### **Action:**

```
// As admin, grant operator role to another account
grantOperatorRole(OPERATOR_ADDRESS)
```

### **Verification:**

```
ROLE_OPERATOR -> 0x97667070c54ef182b0f5858b034beac1b6f3089aa2d3188bb1e8929f4fa9b929
hasRole(ROLE_OPERATOR, OPERATOR_ADDRESS)
// Expected result: true
```

### **Expected events:**

`RoleGranted(ROLE_OPERATOR, OPERATOR_ADDRESS, ADMIN_ADDRESS)`
`RoleGrantedByAdmin(ADMIN_ADDRESS, OPERATOR_ADDRESS, ROLE_OPERATOR)`

---

## 🔍 **Case 9: Operator Functions**

### **Action:**

```
// As operator, update the data feed
updateDataFeed(NEW_ORACLE_ADDRESS)
```

### **Verification:**

```
getDataFeed()
// Expected result: NEW_ORACLE_ADDRESS
```

### **Expected event:**

`DataFeedUpdated(your_address, OLD_ORACLE_ADDRESS, NEW_ORACLE_ADDRESS)`

---

## 📊 **Quick reference:**

```
// ETH deposits in wei:
10000000000000000    // 0.01 ETH
50000000000000000    // 0.05 ETH
100000000000000000   // 0.1 ETH
250000000000000000   // 0.25 ETH
1000000000000000000  // 1 ETH

// USDC deposits/withdrawals (6 decimals):
1000000     // 1 USDC
100000000   // 100 USDC
500000000   // 500 USDC
1000000000  // 1,000 USDC
5000000000  // 5,000 USDC

// Special addresses:
0x0000000000000000000000000000000000000000  // address(0) for ETH
```
