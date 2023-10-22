//SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {AppEventFactory} from "./AppEventFactory.sol";

interface AppEventInterface {
    function getEventAttendeeStatus(
        address _attendee
    ) external view returns (bool);
}

contract EventStaker {
    mapping(address => mapping(string => uint256)) public balances;

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

    function stake(
        string memory _eventId,
        uint256 _deadline,
        bool _eventStatus
    ) public payable {
        uint256 amount = msg.value;
        address attendant = msg.sender;

        uint256 eventDeadline = _deadline;
        bool eventStatus = _eventStatus;

        if (amount == 0) {
            revert NoStakeIncluded();
        }
        if (block.timestamp >= eventDeadline) {
            revert DeadlineExceeded(eventDeadline, block.timestamp);
        }
        if (!eventStatus) {
            revert EventClosed("The event is closed");
        }

        balances[attendant][_eventId] += amount;
        emit Stake(attendant, amount);
    }

    function withdraw(
        address _event,
        string memory _eventId,
        uint256 _eventDeadlineAttendance
    ) external {
        address attendant = msg.sender;
        uint256 amount = balances[attendant][_eventId];

        AppEventInterface eventContract = AppEventInterface(_event);
        bool attendance = eventContract.getEventAttendeeStatus(msg.sender);

        if (amount == 0) {
            revert NothingToWithdraw(attendant, amount);
        }
        if (block.timestamp <= _eventDeadlineAttendance) {
            revert DeadlineNotReached("The event has not yet taken place");
        }
        if (!attendance) {
            revert NotAttended("You did not attend the event");
        }

        balances[attendant][_eventId] = 0;

        (bool success, ) = attendant.call{value: amount}("");
        if (!success) {
            revert WithdrawalFailed();
        } else {
            emit WithdrawalCompleted(attendant, amount);
        }
    }
}
