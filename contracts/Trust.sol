// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Vibra.sol";

//trust needs starting date-ending date
//  amount is set so that it would take "10 days"to withdraw all of the ETH
// there is a function that is called to update the state required to determine if a beneficiary  waited period  before attempting to withdraw from the fund again.

contract Trust is Ownable {
    VibraToken internal vibra;
    address public beneficiary;
    address public organization;
    uint256 internal balance;
    uint256 public minBalance;

    modifier onlyBeneficiary() {
        require(
            msg.sender == beneficiary,
            "Only the beneficiary can call this function"
        );
        _;
    }

    modifier onlyOrganization() {
        require(
            msg.sender == organization,
            "Only the organization can call this function"
        );
        _;
    }

    event Payment(address indexed from, address indexed to, uint256 amount);
    event Deposit(address indexed from, uint256 amount);
    event Withdrawal(address indexed to, uint256 amount);
    event LowBalance(address indexed holder, uint256 balance);

    constructor(
        address _vibra,
        address _beneficiary,
        address _organization,
        uint256 _minBalance
    ) {
        vibra = VibraToken(_vibra);
        beneficiary = _beneficiary;
        organization = _organization;
        minBalance = _minBalance;
    }

    function deposit(uint256 amount) public onlyOwner returns (bool) {
        require(
            amount > minBalance,
            "Deposit must be greater than the min balance"
        );
        require(
            vibra.allowance(msg.sender, address(this)) >= amount,
            "Insufficient allowance"
        );
        require(vibra.balanceOf(msg.sender) >= amount, "Insufficient balance");

        vibra.transferFrom(msg.sender, address(this), amount);

        balance += amount;
        emit Deposit(msg.sender, amount);
        return true;
    }

    function chargeFees(uint256 amount) public onlyOrganization returns (bool) {
        require(balance > amount, "Insufficient balance");
        require(
            vibra.transfer(msg.sender, amount),
            "Unable to complete payment"
        );

        balance -= amount;
        emit Payment(address(this), organization, amount);

        if (balance <= minBalance) {
            emit LowBalance(owner(), balance);
        }
        return true;
    }

    function withdraw(uint256 amount) public onlyOwner returns (bool) {
        require(balance > amount, "Insufficient balance");
        require(vibra.transfer(msg.sender, amount));

        balance -= amount;
        emit Withdrawal(msg.sender, amount);

        if (balance <= minBalance) {
            emit LowBalance(owner(), balance);
        }

        return true;
    }

    function withdrawAll() public onlyOwner returns (bool) {
        require(balance > 0, "There is no balance");
        require(vibra.transfer(msg.sender, balance), "Insufficient balance");

        emit Withdrawal(msg.sender, balance);
        balance = 0;
        return true;
    }
}