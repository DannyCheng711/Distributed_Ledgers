// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./interfaces/IHumanResources.sol"; 
import "./interfaces/AggregatorV3Interface.sol";
import "./interfaces/IV3SwapRouter.sol";
import "./interfaces/IERC20.sol"; 
import "./interfaces/ReentrancyGuard.sol";
import "forge-std/console.sol";


contract HumanResources is IHumanResources, ReentrancyGuard {
    
    /* State Variables */
    address private immutable hrManagerAddress; // HR Manager address

    uint256 public activeEmployeeCount = 0; // Count of currently active employees

    address internal constant _WETH = 0x4200000000000000000000000000000000000006; // WETH token address
    address internal constant _USDC = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85; // USDC token address
    AggregatorV3Interface internal constant _ETH_USD_FEED = AggregatorV3Interface(0x13e3Ee699D1909E989722E753853AE30b17e08c5); // ETH/USD price feed
    ISwapRouter internal constant _swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564); // Uniswap V3 router

    // Mappings to store employee data
    mapping(address=>uint256) internal employeeSalary; // Employee's weekly salary in USD
    mapping(address=>uint256) internal employedSinceTime; // Timestamp when employment started
    mapping(address=>uint256) internal terminatedAtTime; // Timestamp when employment was terminated
    mapping(address=>uint256) internal employeeBalance; // Accumulated unpaid salary
    mapping(address=>uint256) internal lastBalanceUpdateTime; // Last time salary was updated
    mapping(address=>bool) internal register; // Whether the employee is registered
    mapping(address=>bool) internal active; // Whether the employee is currently active
    mapping(address => bool) internal prefersPayETH; // Whether the employee prefers ETH payment

   
    /* Modifiers */
    modifier onlyManager() {
        if (msg.sender != hrManagerAddress) {
            revert NotAuthorized();
        }
        _;
    }
    
    modifier onlyActiveEmployee() {
        if (!active[msg.sender]) {
            revert NotAuthorized();
        }
        _;
    }

    modifier onlyEmployee() {
        if (!register[msg.sender]) {
            revert NotAuthorized();
        }
        _;
    }

    /* Constructor: Initializes the HR Manager */
    constructor () {

        require(msg.sender != address(0), "Invalid HR Manager address");   
        hrManagerAddress = msg.sender;

    }

    /* Register a new employee */
    function registerEmployee(address _employee, uint256 _weeklyUsdSalary) external override onlyManager {
        
        if (active[_employee]){
            revert EmployeeAlreadyRegistered();
        }

        // Initialize employee data
        employeeSalary[_employee] = _weeklyUsdSalary;
        terminatedAtTime[_employee] = 0;
        employedSinceTime[_employee] = block.timestamp;
        lastBalanceUpdateTime[_employee] = block.timestamp; // start to calculate the salary 
        register[_employee] = true;
        active[_employee] = true;
        activeEmployeeCount = activeEmployeeCount + 1; 

        emit EmployeeRegistered(_employee, _weeklyUsdSalary);

    }

    /* Terminate an existing employee */
    function terminateEmployee(address _employee) external override onlyManager {
        // Ensure the employee is both registered and active before termination
        if (!register[_employee] || !active[_employee]){
            revert EmployeeNotRegistered();
        }

        terminatedAtTime[_employee] = block.timestamp;

        // Update the balance when the employee is terminated
        updateBalance(_employee);

        active[_employee] = false;
        activeEmployeeCount = activeEmployeeCount - 1; 

        emit EmployeeTerminated(_employee);

    }

    /* Employees withdraw their accrued salary */    
    function withdrawSalary() public override onlyEmployee nonReentrant {
        // If the employee is active, ensure the salary balance is updated
        if (active[msg.sender]){
            updateBalance(msg.sender);
        }

        uint256 amountToWithdraw = employeeBalance[msg.sender];
        require(amountToWithdraw > 0, "No deposit to withdraw");

        // Process payment based on employee's preferred currency (ETH or USDC)
        if (prefersPayETH[msg.sender]){
            uint256 ethAmountToWithdraw = convertUsdToEth(amountToWithdraw); // Convert USD to ETH
            uint256 usdcSwapped = convertUsdToUsdc(amountToWithdraw); // Convert USD to USDC for Uniswap swap
            uint wethAmount = swapUsdcToWeth(usdcSwapped, ethAmountToWithdraw);

            // Unwrap WETH to ETH and transfer it to the employee
            IWETH(_WETH).withdraw(wethAmount);
            (bool success, ) = msg.sender.call{value: wethAmount}("");
            require(success, "ETH transfer failed");

            emit SalaryWithdrawn(msg.sender, true, wethAmount);


        }else{
            // Transfer USDC to the employee
            uint256 usdcAmountToWithdraw = convertUsdToUsdc(amountToWithdraw);
            require(usdcAmountToWithdraw > 0, "Invalid USDC amount");
            require(IERC20(_USDC).balanceOf(address(this)) >= usdcAmountToWithdraw, "Insufficient USDC balance");
            bool success = IERC20(_USDC).transfer(msg.sender, usdcAmountToWithdraw);
            require(success, "USDC transfer failed");

            emit SalaryWithdrawn(msg.sender, false, usdcAmountToWithdraw);
        }
        
        // Reset employee balance after withdrawal
        employeeBalance[msg.sender] = 0;

    }

    /* Swap USDC to WETH using Uniswap V3 */
    function swapUsdcToWeth(uint256 _usdcSwapped, uint256 _ethToWithdraw) internal returns (uint256)  {
        // Approve the router to spend the USDC
        require(IERC20(_USDC).approve(address(_swapRouter), _usdcSwapped), "USDC approve failed");

        // Setup parameters for the Uniswap V3 swap
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: _USDC,
            tokenOut: _WETH,
            fee: 3000, // 0.3% Uniswap pool
            recipient: address(this),
            deadline: block.timestamp + 30,
            amountIn: _usdcSwapped,
            amountOutMinimum: (_ethToWithdraw * 98) / 100, // 2% slippage protection
            sqrtPriceLimitX96: 0
        });

        // Log expected vs actual WETH received after the swap
        console.log("Should At Least Receive: ", (_ethToWithdraw * 98) /100);
        uint256 weth = _swapRouter.exactInputSingle(params);
        console.log("Actually receive: ", weth);

        return weth; 
    }

    /* Update the salary balance of an employee */
    function updateBalance(address _employee) internal {

        // Calculate and update employee balance based on the time passed
        employeeBalance[_employee] += (
            (block.timestamp - lastBalanceUpdateTime[_employee]) * employeeSalary[_employee] / 7 days);

        // Update the last balance update time to the current time
        lastBalanceUpdateTime[_employee] = block.timestamp;

    }

    /* Convert USD to USDC */
    function convertUsdToUsdc(uint _usdAmount) internal view returns (uint256) {
        
        require(_USDC != address(0), "USDC token address is not set!");

        uint8 usdcDecimals = IERC20Metadata(_USDC).decimals(); // USDC decimals (typically 6)
    
        // Ensure USD amount is scaled to match USDC's decimals
        uint256 usdcAmount = (_usdAmount * (10 ** usdcDecimals)) / (1e18); 
    
        return usdcAmount;
    
    }
    
    /* Convert USD to ETH */
    function convertUsdToEth(uint256 _usdAmount) internal view returns (uint256) {

         (, int256 ethPrice, , , ) = _ETH_USD_FEED.latestRoundData();
        require(ethPrice > 0, "Invalid ETH price");

        // Convert USD to ETH based on the current ETH/USD price
        uint8 priceDecimals = _ETH_USD_FEED.decimals();
        uint256 adjustedEthPrice = uint256(ethPrice) / (10 ** (priceDecimals));
        uint256 ethAmount = _usdAmount / adjustedEthPrice;

        return ethAmount;

    }

    /* Switch preferred payment currency */
    function switchCurrency() external override onlyActiveEmployee nonReentrant{

        // Update balance if the employee is switching currency
        updateBalance(msg.sender);
        
        // Withdraw pending salary if any
        if (employeeBalance[msg.sender] > 0 ){
            withdrawSalary(); 
        }

        // Toggle the preferred currency 
        prefersPayETH[msg.sender] = !prefersPayETH[msg.sender];

        // Emit the CurrencySwitched event
        emit CurrencySwitched(msg.sender, prefersPayETH[msg.sender]);

    }

    /* Calculate the available salary for an employee */
    function salaryAvailable(address _employee) external view override returns (uint256) {
        
        // If the employee is active, calculate the accumulated salary since the last update
        // Otherwise, use the balance stored at the time of termination
        uint256 accumulateBalance = 0;

        if (active[_employee]){
            // Calculate earned salary for the active period
            accumulateBalance += (
                (block.timestamp - lastBalanceUpdateTime[_employee]) * employeeSalary[_employee] / 7 days);
        }

        if (prefersPayETH[_employee]){
            // Convert total available salary to ETH
            uint256 ethAmount = convertUsdToEth(employeeBalance[_employee] + accumulateBalance);
            return ethAmount;
        
        }else{
            // Convert total available salary to USDC
            uint256 usdcAmount = convertUsdToUsdc(employeeBalance[_employee] + accumulateBalance);
            return usdcAmount;
        }
    }

    /* Return the address of the HR Manager */
    function hrManager() external view override returns (address) {
        return hrManagerAddress;
    }

    /* Retrieve the count of currently active employees */
    function getActiveEmployeeCount() external view override returns (uint256) {
        return activeEmployeeCount;
    }

    /* Fetch general information about an employee */
    function getEmployeeInfo(address _employee) 
        external 
        view 
        override
        returns (
            uint256 weeklyUsdSalary,
            uint256 employedSince,
            uint256 terminatedAt
        ){
            return (
                employeeSalary[_employee], employedSinceTime[_employee], terminatedAtTime[_employee]);
    }

    /* Fetch payment preferences and balance for an employee */
    function getEmployeePaymentInfo(address _employee)
        external
        view 
        returns (
            bool isETH,
            uint256 balance
        ){ 
            return (prefersPayETH[_employee], employeeBalance[_employee]);
    }

    /* Allow the contract to accept ETH  */
    receive() external payable {
        
    }

}