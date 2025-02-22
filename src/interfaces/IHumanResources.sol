// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

/// @notice This interface defines the functions that the HumanResources contract must implement.
/// The contract must be able to register employees, terminate them, and allow employees to withdraw their salary.
/// The contract will be funded using only USDC but will pay the employees in USDC or ETH.
interface IHumanResources {
    /// @notice This error is raised if a user tries to call a function they are not authorized to call.
    error NotAuthorized();

    /// @notice This error is raised if a user tries to register an employee that is already registered.
    error EmployeeAlreadyRegistered();

    /// @notice This error is raised if a user tries to terminate an employee that is not registered.
    error EmployeeNotRegistered();

    /// @notice This event is emitted when an employee is registered.
    event EmployeeRegistered(address indexed employee, uint256 weeklyUsdSalary);

    /// @notice This event is emitted when an employee is terminated.
    event EmployeeTerminated(address indexed employee);

    /// @notice This event is emitted when an employee withdraws their salary.
    /// @param amount The amount in the currency the employee prefers (USDC or ETH), scaled correctly.
    event SalaryWithdrawn(address indexed employee, bool isEth, uint256 amount);

    /// @notice This event is emitted when an employee switches the currency in which they receive their salary.
    event CurrencySwitched(address indexed employee, bool isEth);

    // HR Manager functions
    // Only the address returned by the `hrManager` function below can call these functions.
    // If anyone else tries to call them, the transaction must revert with the `NotAuthorized` error.

    /// @notice Registers an employee in the HR system.
    /// @param employee The address of the employee.
    /// @param weeklyUsdSalary The weekly salary of the employee in USD, scaled with 18 decimals.
    function registerEmployee(address employee, uint256 weeklyUsdSalary) external;

    /// @notice Terminates the contract of a given employee.
    /// The salary of the employee will stop accumulating.
    /// @param employee The address of the employee.
    function terminateEmployee(address employee) external;

    // Employee functions
    // These functions are only callable by employees.
    // If anyone else tries to call them, the transaction shall revert with the `NotAuthorized` error.
    // Only the `withdrawSalary` function can be called by non-active (i.e., terminated) employees.

    /// @notice Withdraws the salary of the employee.
    /// This sends either USDC or ETH to the employee, depending on their preference.
    /// The salary accumulates with time (regardless of nights, weekends, or other non-working hours),
    /// according to the employee's weekly salary.
    /// For example, after 2 days, the employee will be able to withdraw 2/7th of their weekly salary.
    function withdrawSalary() external;

    /// @notice Switches the currency in which the employee receives their salary.
    /// By default, the salary is paid in USDC.
    /// If the employee calls this function, the salary will be paid in ETH.
    /// If called again, the salary switches back to USDC.
    /// When the salary is paid in ETH, the contract will swap the amount to be paid from USDC to ETH.
    /// When this function is called, the current accumulated salary should be withdrawn automatically (emitting the `SalaryWithdrawn` event).
    function switchCurrency() external;

    // Views

    /// @notice Returns the salary available for withdrawal for a given employee.
    /// This returns the amount in the currency the employee prefers (USDC or ETH).
    /// The amount is scaled with the correct number of decimals for the currency.
    /// @param employee The address of the employee.
    function salaryAvailable(address employee) external view returns (uint256);

    /// @notice Returns the address of the HR manager.
    function hrManager() external view returns (address);

    /// @notice Returns the number of active employees registered in the HR system.
    function getActiveEmployeeCount() external view returns (uint256);

    /// @notice Returns information about an employee.
    /// If the employee does not exist, the function does not revert but all values returned will be 0.
    /// @param employee The address of the employee.
    /// @return weeklyUsdSalary The weekly salary of the employee in USD, scaled with 18 decimals.
    /// @return employedSince The timestamp at which the employee was registered.
    /// @return terminatedAt The timestamp at which the employee was terminated (or 0 if still active).
    function getEmployeeInfo(address employee) 
        external 
        view 
        returns (
            uint256 weeklyUsdSalary,
            uint256 employedSince,
            uint256 terminatedAt
        );
}