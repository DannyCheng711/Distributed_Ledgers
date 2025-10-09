# Human Resources Payroll Smart Contract

This repository contains the `HumanResources` Solidity smart contract, which is a payroll system for managing employee salaries. It offers functionality to register employees, terminate them, update their salary balances, and withdraw their salaries in either ETH or USDC.

## Features

- **Employee Management:**
  - Register and terminate employees.
  - Store weekly salaries in USD.
  - Maintain records of employment and termination dates.

- **Payment System:**
  - Supports salary withdrawals in ETH or USDC.
  - Calculates employee balances based on time employed.
  - Allows employees to switch between ETH and USDC for payments.

- **Swapping Mechanism:**
  - Converts USD balances to ETH or USDC.
  - Uses the Uniswap v3 router for token swapping.
  - Fetches real-time ETH/USD price feeds using Chainlink oracles.

## How It Works

1. **Registration and Termination:**
   - The `registerEmployee` function registers a new employee with a weekly salary.
   - The `terminateEmployee` function stops an employee's payments and updates their balance.

2. **Balance Updates:**
   - The `updateBalance` function calculates accrued salary based on the time elapsed since the last update.

3. **Currency Switching:**
   - Employees can switch their preferred payment currency (ETH or USDC) using the `switchCurrency` function.

4. **Salary Withdrawals:**
   - Employees withdraw their accrued salary using the `withdrawSalary` function.
   - Salaries are converted to the preferred currency before payment.

5. **Token Swapping:**
   - Implements token swapping via the Uniswap v3 router for ETH/USDC conversions.
   - Leverages Chainlink price feeds for accurate conversion rates.

## Requirements

- **Solidity Version:** `^0.8.24`
- **Dependencies:**
  - Chainlink's AggregatorV3Interface for price feeds.
  - Uniswap v3's ISwapRouter for token swaps.
  - ERC20 token interface for USDC interaction.

---

### Function Logic

#### Manager Functions

- **`registerEmployee(address _employee, uint256 _weeklyUsdSalary)`**  
  - Checks if the employee is already registered; reverts if true.
  - Initializes the employee’s salary, start time, and active status.
  - Updates the total active employee count.
  - Emits the EmployeeRegistered event.

- **`terminateEmployee(address _employee)`**  
  - Ensures the employee is registered and active; reverts otherwise.
  - Updates the employee’s salary balance up to the termination timestamp
  - Marks the employee as inactive and decrements the active employee count
  - Emits the EmployeeTerminated event.

#### Employee Functions

- **`withdrawSalary()`**  
  - If active, updates the employee’s balance to account for the latest salary accrual.
  - Converts the salary to ETH (via USDC and Uniswap swap) or transfers USDC directly based on preference.
  - Emits the SalaryWithdrawn event.
  - Reverts if there’s no salary to withdraw or insufficient USDC balance for USDC transfer

- **`switchCurrency()`**  
  - Updates the employee’s balance to ensure salary accrual is captured.
  - Processes any pending salary withdrawal before switching currency.
  - Toggles the prefersPayETH flag.
  - Emits the CurrencySwitched event.

#### Utility Functions

- **`updateBalance(address _employee)`**  
  - Calculates the accrued salary.
  - Updates the balance and resets the lastBalanceUpdateTime to the current timestamp.

- **`convertUsdToUsdc(uint256 _usdAmount)`**  
  - Fetches the USDC token decimals and scales the USD value accordingly.

- **`convertUsdToEth(uint256 _usdAmount)`**  
  - Retrieves the ETH/USD price and adjusts for price feed decimals
  - Calculates the ETH equivalent of the given USD amount.

- **`swapUsdcToWeth(uint256 _usdcSwapped, uint256 _ethToWithdraw)`**  
  - Approves the Uniswap router to spend USDC.
  - Executes a swap with specified slippage protection (2% minimum).
  - Returns the WETH amount received from the swap.

---

### Events

- **`EmployeeRegistered(address indexed employee, uint256 weeklyUsdSalary)`**  
  Emitted when an employee is registered.

- **`EmployeeTerminated(address indexed employee)`**  
  Emitted when an employee is terminated.

- **`SalaryWithdrawn(address indexed employee, bool isETH, uint256 amount)`**  
  Emitted when an employee withdraws their salary.

- **`CurrencySwitched(address indexed employee, bool isETH)`**  
  Emitted when an employee switches their preferred payment currency.

---
### Setting Up and Running the Project

- **`Update .env`**
  Copy .env.example to .env and fill in your own keys and contract addresses.

- **`Install Foundry`**

  To set up Foundry, run the following command:  
  ```sh
  curl -L https://foundry.paradigm.xyz | bash
  ```
  This will download and install Foundry on your system.

- **`Update Foundry to the latest version`**
  ```sh
  foundryup
  ```
  This ensures you are using the latest features and fixes.

- **`Building the Project`**

  Compile the smart contracts:
  ```sh
  forge build
  ```
  This command compiles all Solidity files and generates necessary artifacts.

- **`Running Tests`**

  Execute all test cases:
  ```sh
  forge test
  ```
---

### Acknowledgments

- [Uniswap V3](https://uniswap.org/) for token swapping.
- [Chainlink Oracles](https://chain.link/) for price feeds.
- [OpenZeppelin Contracts](https://openzeppelin.com/contracts/) for reusable ERC20 components.
