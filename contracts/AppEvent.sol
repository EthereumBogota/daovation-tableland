// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {EventStaker} from "./EventStaker.sol";

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
        address _owner,
        string[] memory _eventInfo,
        uint256[] memory _numericData,
        bool _status
    ) {
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

    // This is in case the caller is part from the dao
    // function reedemNft(string calldata _eventSecretWord) public {
    //     // require(eventAttendees[msg.sender] == true, "You do not have a ticket");
    //     // require(
    //     //     block.timestamp <= eventReedemableTime,
    //     //     "You cannot reedem your NFT yet"
    //     // );
    //     require(
    //         keccak256(abi.encodePacked(_eventSecretWord)) ==
    //             eventSecretWordHash,
    //         "Secret word is incorrect"
    //     );
    //     require(
    //         IAppNFT(eventNfts).balanceOf(msg.sender) == 0,
    //         "You already have a NFT"
    //     );

    //     IAppNFT(eventNfts).safeMint(msg.sender);
    // }

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

    function confirmAttendanceDaoUser() public {
        // reedemNft(_eventSecretWord);
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
