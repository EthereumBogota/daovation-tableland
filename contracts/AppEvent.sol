// SPDX-License-Identifier: MIT

import './IAppNFT.sol';

pragma solidity ^0.8.19;

contract AppEvent {
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
    address public eventNfts;

    enum consVarInt {
        startDate,
        endDate,
        capacity
    }

    enum consVarStr {
        eventId,
        eventName,
        eventDescription,
        eventLocation,
        nftName,
        nftSymbol,
        nftUri
    }

    enum consVarAdr {
        owner,
        nfts
    }

    struct dataEvent {
        bool active;
        uint256 eventNum;
        string eventId;
        AppEvent eventAddr;
        bytes32 hashId;
    }

    // event mappings

    mapping(address => bool) public eventAttendees;

    // event events

    event UpdatedEventName(string eventName);
    event UpdatedEventDescription(string eventDescription);
    event UpdatedEventLocation(string eventLocation);
    event UpdatedEventTotalTickets(uint256 eventTotalTickets);
    event UpdatedEventStartTime(uint256 eventStartTime);
    event UpdatedEventEndTime(uint256 eventEndTime);
    event UpdatedReedemableTimeAndSecretWordHash(
        uint256 eventReedemableTime,
        bytes32 eventSecretWordHash
    );
    event UpdatedEventOwner(address eventOwner);
    event BoughtTicket(address buyer);
    event RefundedTicket(address buyer);
    event TransferredTicket(address buyer, address newOwner);

    constructor(
        address[] memory _varAdr,
        string[] memory _varStr,
        uint256[] memory _varInt
    ) {
        eventOwner = _varAdr[uint256(consVarAdr.owner)];
        eventNfts = _varAdr[uint256(consVarAdr.nfts)];

        eventId = _varStr[uint256(consVarStr.eventId)];
        eventName = _varStr[uint256(consVarStr.eventName)];
        eventDescription = _varStr[uint256(consVarStr.eventDescription)];
        eventLocation = _varStr[uint256(consVarStr.eventLocation)];

        eventStartTime = _varInt[uint256(consVarInt.startDate)];
        eventEndTime = _varInt[uint256(consVarInt.endDate)];
        eventTotalTickets = eventRemainingTickets = _varInt[
            uint256(consVarInt.capacity)
        ];
    }

    function reedemNft(string calldata _eventSecretWord) public {
        require(eventAttendees[msg.sender] == true, "You do not have a ticket");
        require(
            block.timestamp <= eventReedemableTime,
            "You cannot reedem your NFT yet"
        );
        require(
            keccak256(abi.encodePacked(_eventSecretWord)) ==
                eventSecretWordHash,
            "Secret word is incorrect"
        );
        require(
            IAppNFT(eventNfts).balanceOf(msg.sender) == 0,
            "You already have a NFT"
        );

        IAppNFT(eventNfts).safeMint(msg.sender);
    }

    function updateEventName(string memory _eventName) public {
        eventName = _eventName;

        emit UpdatedEventName(eventName);
        (_eventName);
    }

    function updateEventDescription(
        string memory _eventDescription // onlyOwner
    ) public {
        eventDescription = _eventDescription;

        emit UpdatedEventDescription(eventDescription);
    }

    function updateEventLocation(
        string memory _eventLocation // onlyOwner
    ) public {
        eventLocation = _eventLocation;

        emit UpdatedEventLocation(eventLocation);
    }

    function updateEventStartTime(
        uint256 _eventStartTime // onlyOwner
    ) public {
        require(
            _eventStartTime > eventStartTime,
            "Start time must be greater than start time"
        );

        eventStartTime = _eventStartTime;

        emit UpdatedEventStartTime(eventStartTime);
    }

    function updateEventEndTime(
        uint256 _eventEndTime // onlyOwner
    ) public {
        require(
            _eventEndTime > eventStartTime,
            "End time must be greater than start time"
        );

        eventEndTime = _eventEndTime;

        emit UpdatedEventEndTime(eventEndTime);
    }

    function updateEventTotalTickets(
        uint256 _eventTotalTickets // onlyOwner
    ) public {
        require(
            _eventTotalTickets >= eventRemainingTickets,
            "Total tickets must be greater than or equal to remaining tickets"
        );

        eventTotalTickets = _eventTotalTickets;

        emit UpdatedEventTotalTickets(eventTotalTickets);
    }

    function updateEventOwner(
        address _eventOwner // onlyOwner
    ) public {
        eventOwner = _eventOwner;

        emit UpdatedEventOwner(eventOwner);
    }

    function buyTicket() public {
        require(
            eventAttendees[msg.sender] == false,
            "You already have a ticket"
        );

        eventAttendees[msg.sender] = true;
        eventRemainingTickets -= 1;

        emit BoughtTicket(msg.sender);
    }

    function refundTicket() public {
        require(eventAttendees[msg.sender] == true, "You do not have a ticket");

        eventAttendees[msg.sender] = false;
        eventRemainingTickets += 1;

        emit RefundedTicket(msg.sender);
    }

    function transferTicket(address _newOwner) public {
        require(eventAttendees[msg.sender] == true, "You do not have a ticket");

        eventAttendees[msg.sender] = false;
        eventAttendees[_newOwner] = true;

        emit TransferredTicket(msg.sender, _newOwner);
    }
}
