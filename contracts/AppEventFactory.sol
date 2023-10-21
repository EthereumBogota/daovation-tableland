// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import {AppEvent} from "./AppEvent.sol";
import {AppDaoManagement} from "./AppDaoManagement.sol";

contract AppEventFactory is AppDaoManagement {
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

    struct DataEvent {
        address dao;
        address eventAddr;
        bool active;
        uint256 eventNum;
        string eventId;
        bytes32 hashId;
    }

    uint256 public numEvents;

    mapping(uint256 => DataEvent) public mapNumEvent;

    mapping(bytes32 => DataEvent) public mapIdEvent;

    mapping(address => DataEvent) public mapAddrEventNum;

    mapping(address => DataEvent[]) public mapEventsPerDao;

    event eventCreated(
        uint256 numEvents,
        string eventId,
        bytes32 hashEventId,
        address eventAddr
    );

    function createEvent(
        address _daoAddress,
        string[] memory _eventInfo,
        uint256[] memory _numericData
    ) external {
        require(
            _numericData[uint256(numericVariables.startDate)] >
                block.timestamp,
            "Invalid start Date"
        );
        require(
            _numericData[uint256(numericVariables.endDate)] >
                _numericData[uint256(numericVariables.startDate)],
            "Invalid end Date"
        );
        require(
            _numericData[uint256(numericVariables.capacity)] > 0,
            "Invalid capacity"
        );

        DaoInfo memory daoInfo = getDaoInfo(_daoAddress);
        require(daoInfo.daoAddress != address(0), "Dao is not registered");

        address owner = address(msg.sender);

        AppEvent newEvent = new AppEvent(owner, _eventInfo, _numericData);


        numEvents++;
        bytes32 hashEventId = keccak256(
            abi.encodePacked(_eventInfo[uint256(eventInfo.eventId)])
        );

        mapNumEvent[numEvents] = DataEvent({
            dao: daoInfo.daoAddress,
            eventAddr: address(newEvent),
            active: true,
            eventNum: numEvents,
            eventId: _eventInfo[uint256(eventInfo.eventId)],
            hashId: hashEventId
        });

        mapIdEvent[hashEventId] = mapNumEvent[numEvents];
        mapAddrEventNum[address(newEvent)] = mapNumEvent[numEvents];
        mapEventsPerDao[daoInfo.daoAddress].push(mapNumEvent[numEvents]);

        emit eventCreated(
            numEvents,
            _eventInfo[uint256(eventInfo.eventId)],
            hashEventId,
            address(newEvent)
        );
    }

    function getTimestamp() public view returns (uint256) {
        return block.timestamp;
    }
}
