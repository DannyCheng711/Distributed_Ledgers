/// @notice This is a test contract for the HumanResources contract
/// You can either run this test for a contract deployed on a local fork or for a contract deployed on Optimism
/// To use a local fork, start `anvil` using `anvil --rpc-url $RPC_URL` where `RPC_URL` should point to an Optimism RPC.
/// Deploy your contract on the local fork and set the following environment variables:
/// - TEST_HR_CONTRACT: the address of the deployed contract
/// - TEST_ETH_RPC_URL: the RPC URL of the local fork (likely http://localhost:8545)
/// To run on Optimism, you will need to set the same environment variables, but with the address of the deployed contract on Optimism
/// and TEST_ETH_RPC_URL should point to the Optimism RPC.
/// Once the environment variables are set, you can run the tests using `forge test --mp test/HumanResourcesTests.t.sol`
/// assuming that you copied the file into the `test` folder of your project.

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

/// @notice You may need to change these import statements depending on your project structure and where you use this test
import {Test, console, stdStorage, StdStorage} from "forge-std/Test.sol";
import {HumanResources, IHumanResources} from "../src/HumanResources.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {AggregatorV3Interface} from "../src/interfaces/AggregatorV3Interface.sol";

/// The main test contract for HumanResources.
contract HumanResourcesTest is Test {
    using stdStorage for StdStorage;

    // Constants for token and feed addresses.
    address internal constant _WETH =
        0x4200000000000000000000000000000000000006;
    address internal constant _USDC =
        0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
        
    AggregatorV3Interface internal constant _ETH_USD_FEED =
        AggregatorV3Interface(0x13e3Ee699D1909E989722E753853AE30b17e08c5);

    // Contract and variable declarations.
    HumanResources public humanResources;

    address public hrManager;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 public aliceSalary = 2100e18;
    uint256 public bobSalary = 700e18;

    uint256 ethPrice;

    /// Sets up the test environment by forking the chain and initializing the contract.
    function setUp() public {
        // Fork the chain based on the provided RPC URL.

        /// vm.createSelectFork(vm.envString("TEST_ETH_RPC_URL")); // for local test
        vm.createSelectFork(vm.envString("PRD_ETH_RPC_URL")); // for production

        // Load the deployed contract address from environment variables.
        /// humanResources = HumanResources(payable(vm.envAddress("TEST_HR_CONTRACT"))); // for local test
        humanResources = HumanResources(payable(vm.envAddress("PRD_HR_CONTRACT"))); // for production
        // Fetch the current ETH price in USD.
        (, int256 answer, , , ) = _ETH_USD_FEED.latestRoundData();
        uint256 feedDecimals = _ETH_USD_FEED.decimals();
        ethPrice = uint256(answer) * 10 ** (18 - feedDecimals);
        // Fetch the HR manager address.
        hrManager = humanResources.hrManager();
    }

    /// Tests registering employees and verifies correct employee data and counts.
    function test_registerEmployee() public {
        _registerEmployee(alice, aliceSalary);
        assertEq(humanResources.getActiveEmployeeCount(), 1);

        uint256 currentTime = block.timestamp;

        (
            uint256 weeklySalary,
            uint256 employedSince,
            uint256 terminatedAt
        ) = humanResources.getEmployeeInfo(alice);
        assertEq(weeklySalary, aliceSalary);
        assertEq(employedSince, currentTime);
        assertEq(terminatedAt, 0);

        skip(10 hours);

        _registerEmployee(bob, bobSalary);

        (weeklySalary, employedSince, terminatedAt) = humanResources
            .getEmployeeInfo(bob);
        assertEq(humanResources.getActiveEmployeeCount(), 2);

        assertEq(weeklySalary, bobSalary);
        assertEq(employedSince, currentTime + 10 hours);
        assertEq(terminatedAt, 0);
    }

    /// Tests terminating an employee and ensures data integrity.
    function test_terminateEmployee() public {

        _registerEmployee(alice, aliceSalary);
        assertEq(humanResources.getActiveEmployeeCount(), 1);

        uint256 currentTime = block.timestamp;

        (
            uint256 weeklySalary,
            uint256 employedSince,
            uint256 terminatedAt
        ) = humanResources.getEmployeeInfo(alice);
        assertEq(weeklySalary, aliceSalary);
        assertEq(employedSince, currentTime);
        assertEq(terminatedAt, 0);

        skip(10 hours);

        _terminateEmployee(alice);

        (weeklySalary, employedSince, terminatedAt) = humanResources
            .getEmployeeInfo(alice);
        assertEq(humanResources.getActiveEmployeeCount(), 0);

        assertEq(weeklySalary, aliceSalary);
        assertEq(employedSince, currentTime);
        assertEq(terminatedAt, currentTime + 10 hours);

    }

    /// Test that unauthorized users cannot register employees
    function test_registerEmployee_unauthorized() public {
        vm.expectRevert(IHumanResources.NotAuthorized.selector);
        humanResources.registerEmployee(alice, aliceSalary);
    }

    /// Test that unauthorized users cannot terminate employees
    function test_terminateEmployee_unauthorized() public {
        _registerEmployee(alice, aliceSalary);
        assertEq(humanResources.getActiveEmployeeCount(), 1);

        vm.expectRevert(IHumanResources.NotAuthorized.selector);
        humanResources.terminateEmployee(alice);
    }

    /// Test that registering the same employee twice is not allowed
    function test_registerEmployee_twice() public {
        _registerEmployee(alice, aliceSalary);
        vm.expectRevert(IHumanResources.EmployeeAlreadyRegistered.selector);
        _registerEmployee(alice, aliceSalary);
    }

    /// Test salary availability calculation in USDC currency
    function test_salaryAvailable_usdc() public {
        _registerEmployee(alice, aliceSalary);
        skip(2 days);
        assertEq(
            humanResources.salaryAvailable(alice),
            ((aliceSalary / 1e12) * 2) / 7
        );

        skip(5 days);
        assertEq(humanResources.salaryAvailable(alice), aliceSalary / 1e12);
    }

    /// Test salary availability calculation in ETH currency
    function test_salaryAvailable_eth() public {
        _registerEmployee(alice, aliceSalary);
        uint256 expectedSalary = (aliceSalary * 1e18 * 2) / ethPrice / 7;
        vm.prank(alice);
        humanResources.switchCurrency();
        skip(2 days);
        assertApproxEqRel(
            humanResources.salaryAvailable(alice),
            expectedSalary,
            0.01e18
        );
        skip(5 days);
        expectedSalary = (aliceSalary * 1e18) / ethPrice;
        assertApproxEqRel(
            humanResources.salaryAvailable(alice),
            expectedSalary,
            0.01e18
        );
    }

    /// Test withdrawal of salary in USDC currency
    function test_withdrawSalary_usdc() public {
        _mintTokensFor(_USDC, address(humanResources), 10_000e6);
        _registerEmployee(alice, aliceSalary);
        skip(2 days);
        vm.prank(alice);
        humanResources.withdrawSalary();
        assertEq(
            IERC20(_USDC).balanceOf(address(alice)),
            ((aliceSalary / 1e12) * 2) / 7
        );

        skip(5 days);
        vm.prank(alice);
        humanResources.withdrawSalary();
        assertEq(IERC20(_USDC).balanceOf(address(alice)), aliceSalary / 1e12);
    }

    /// Test withdrawal of salary in ETH currency
    function test_withdrawSalary_eth() public {
        _mintTokensFor(_USDC, address(humanResources), 10_000e6);
        _registerEmployee(alice, aliceSalary);
        uint256 expectedSalary = (aliceSalary * 1e18 * 2) / ethPrice / 7;
        vm.prank(alice);
        humanResources.switchCurrency();
        skip(2 days);
        vm.prank(alice);
        humanResources.withdrawSalary();
        assertApproxEqRel(alice.balance, expectedSalary, 0.02e18);
        skip(5 days);
        expectedSalary = (aliceSalary * 1e18) / ethPrice;
        vm.prank(alice);
        humanResources.withdrawSalary();
        assertApproxEqRel(alice.balance, expectedSalary, 0.02e18);
    }

    /// Test that unauthorized users cannot withdraw salary
    function test_withdrawSalary_unauthorized() public {
        vm.expectRevert(IHumanResources.NotAuthorized.selector);
        humanResources.withdrawSalary();
    }

    /// Test that unregistered users cannot switch currency
    function test_switchCurrency_notRegistered() public {
        vm.expectRevert(IHumanResources.NotAuthorized.selector);
        humanResources.switchCurrency();
    }

    /// Test re-registering an employee after termination
    function test_reregisterEmployee() public {
        _mintTokensFor(_USDC, address(humanResources), 10_000e6);
        _registerEmployee(alice, aliceSalary);
        skip(2 days);
        vm.prank(hrManager);
        humanResources.terminateEmployee(alice);
        skip(1 days);
        _registerEmployee(alice, aliceSalary * 2);

        skip(5 days);
        vm.prank(alice);
        humanResources.withdrawSalary();
        uint256 expectedSalary = ((aliceSalary * 2) / 7) +
            ((aliceSalary * 2 * 5) / 7);
        assertEq(
            IERC20(_USDC).balanceOf(address(alice)),
            expectedSalary / 1e12
        );
    }

    /// Test the HR manager address
    function test_hrmanager() view public {
        address manager = humanResources.hrManager();
        assertEq(manager, hrManager);
    }

    /// Helper function to register an employee
    function _registerEmployee(address employeeAddress, uint256 salary) public {
        vm.prank(hrManager);
        humanResources.registerEmployee(employeeAddress, salary);
    }

    /// Helper function to terminate an employee
    function _terminateEmployee(address employeeAddress) public {
        vm.prank(hrManager);
        humanResources.terminateEmployee(employeeAddress);
    }

    /// Helper function to mint tokens for testing
    function _mintTokensFor(
        address token_,
        address account_,
        uint256 amount_
    ) internal {
        stdstore
            .target(token_)
            .sig(IERC20(token_).balanceOf.selector)
            .with_key(account_)
            .checked_write(amount_);
    }
}

