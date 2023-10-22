// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {EventStaker} from "./EventStaker.sol";

interface IAppNFTGenerator {
    function registerAttendanceDaoEvent(
        address _attendee,
        address _daoAddress
    ) external;
}

contract AppEvent is EventStaker {
    string public eventId;
    string public eventName;
    string public eventDescription;
    string public eventLocation;
    uint256 public eventTotalTickets;
    uint256 public eventRemainingTickets;
    uint256 public eventStartTime;
    uint256 public eventEndTime;
    uint256 public eventReedemableTime;
    bytes32 public eventSecretWordHash;
    address public eventFactory;
    address public eventOwner;
    bool public eventStatus;

    address public dao;
    address public nftGenerator = address(0); // ! to replace

    enum numericVariables {
        startDate,
        endDate,
        capacity
    }

    enum eventInfo {
        eventId,
        eventName,
        eventDescription,
        eventLocation
    }

    mapping(address => bool) public eventAttendees;
    mapping(address => bool) public attendeesValidated;

    event AttendanceConfirmed(address buyer);
    event AttendeeValidated(address attendee);
    event RefundedTicket(address buyer);

    modifier onlyHoster() {
        require(
            msg.sender == eventOwner,
            "You are not the hoster of the event"
        );
        _;
    }

    constructor(
        address _daoAddress,
        address _owner,
        string[] memory _eventInfo,
        uint256[] memory _numericData,
        bool _status
    ) {
        dao = _daoAddress;
        eventOwner = _owner;

        eventId = _eventInfo[uint256(eventInfo.eventId)];
        eventName = _eventInfo[uint256(eventInfo.eventName)];
        eventDescription = _eventInfo[uint256(eventInfo.eventDescription)];
        eventLocation = _eventInfo[uint256(eventInfo.eventLocation)];

        eventStartTime = _numericData[uint256(numericVariables.startDate)];
        eventEndTime = _numericData[uint256(numericVariables.endDate)];
        eventTotalTickets = eventRemainingTickets = _numericData[
            uint256(numericVariables.capacity)
        ];

        eventStatus = _status;
    }

    function confirmAttendanceNormalUser() public payable {
        uint256 amount = msg.value;
        if (amount == 0) {
            revert NoStakeIncluded();
        }

        if (block.timestamp >= eventEndTime) {
            revert DeadlineExceeded(eventEndTime, block.timestamp);
        }

        _stake();
        _confirmAttendance();
    }

    function _confirmAttendance() internal {
        require(
            eventAttendees[msg.sender] == false,
            "You already confirmed previously"
        );

        eventAttendees[msg.sender] = true;
        eventRemainingTickets -= 1;

        emit AttendanceConfirmed(msg.sender);
    }

    function validateAttendance(address _attendee) public onlyHoster {
        require(eventAttendees[_attendee] == true, "Attendee not registered");
        attendeesValidated[_attendee] = true;

        IAppNFTGenerator(nftGenerator).registerAttendanceDaoEvent(
            _attendee,
            dao
        );

        emit AttendeeValidated(_attendee);
    }

    function retrieveStaking() public {
        require(block.timestamp > eventEndTime, "The event is not over yet");
        require(
            eventAttendees[msg.sender] == true &&
                attendeesValidated[msg.sender] == true,
            "You did not attend the event"
        );

        _withdraw();
    }

    function getEventAttendeeStatus(
        address _attendee
    ) external view returns (bool) {
        return eventAttendees[_attendee];
    }
}
