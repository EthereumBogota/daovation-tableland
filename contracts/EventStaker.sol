//SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

contract EventStaker {
    mapping(address => uint256) public balances;

    event Stake(address indexed staker, uint256 amount);
    event OpenForWithdrawals();
    event WithdrawalCompleted(address indexed staker, uint256 amount);

    error NoStakeIncluded();
    error DeadlineExceeded(uint256 deadline, uint256 time);
    error DeadlineNotReached(string);
    error NothingToWithdraw(address sender, uint256 balance);
    error WithdrawalFailed();
    error EventClosed(string);
    error NotAttended(string);

    function _stake() public payable {
        uint256 amount = msg.value;
        address attendant = msg.sender;

        balances[attendant] += amount;
        emit Stake(attendant, amount);
    }

    function _withdraw() internal {
        address attendant = msg.sender;
        uint256 amount = balances[attendant];

        if (amount == 0) {
            revert NothingToWithdraw(attendant, amount);
        }

        balances[attendant] = 0;

        (bool success, ) = attendant.call{value: amount}("");
        if (!success) {
            revert WithdrawalFailed();
        } else {
            emit WithdrawalCompleted(attendant, amount);
        }
    }
}
