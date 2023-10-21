pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

import 'hardhat/console.sol';

error NoStakeIncluded();
error DeadlineExceeded(uint256 deadline, uint256 time);
error DeadlineNotReached(string);
error NotOpenForWithdrawalsCallExecute();
error NothingToWithdraw(address sender, uint256 balance); 
error WithdrawalFailed();
error StakeHasBeenCompleted();
error ExternalContractCallFailed();
error EventClosed(string );

contract Staker {
  
  struct DataEvent {
    bool active;
    uint256 eventId;
    //AppEvent eventAddr;
    bytes32 hashId;
    uint256 deadlineRegister;
    uint256 deadlineAttendance;
    bool AttendanceOK;
}

   
  mapping(address => uint256[]) public idevents;
  mapping(uint256 => DataEvent) public eventData ;

  mapping(address => uint256) public balances;
  uint256 public constant threshold = 1 ether;

  bool public openForWithdraw;
  bool private isCompleted;
  
  
  event Stake(address indexed staker, uint256 amount);
  
  event StakeCompleted();
 
  event OpenForWithdrawals();
 
  event WithrawalCompleted(address indexed staker, uint256 amount);

  // Función para agregar un nuevo evento al mapping - temporal
    function addEvent(bool _active, uint256 _eventId, bytes32 _hashId, uint256 _deadlineRegister, uint256 _deadlineAttendance, bool _attendanceOK ) public {
        DataEvent memory newEvent = DataEvent({
            active: _active,
            eventId: _eventId,
            hashId: _hashId,
            deadlineRegister: _deadlineRegister,
            deadlineAttendance: _deadlineAttendance,
            AttendanceOK: _attendanceOK
        });

        eventData[_eventId] = newEvent;
    }

  constructor() {
   
    
  }

  
  function stake(uint256 _idevent) public payable {
    uint256 amount = msg.value;
    uint256 eventDeadline = eventData[_idevent].deadlineRegister;
    bool eventStatus = eventData[_idevent].active;
    if (amount == 0) {
      revert NoStakeIncluded();
    }
    if (block.timestamp >= eventDeadline) {
      revert DeadlineExceeded(eventDeadline, block.timestamp);
    }
    if (!eventStatus) {
      revert EventClosed("The event closed");
    }

    balances[msg.sender] += amount;
    emit Stake(msg.sender, amount);
  }


  function AttendaceEvent(uint256 _idevent, bool _attendace) external  {
    eventData[_idevent].AttendanceOK = _attendace;      
  }


  function withdraw(uint256 _idevent) external   {
    address sender = msg.sender;
    uint256 amount = balances[sender];

    uint256 eventDeadlineAttendace = eventData[_idevent].deadlineAttendance;
    bool eventAttendace = eventData[_idevent].AttendanceOK;

    if (amount == 0) {
      revert NothingToWithdraw(sender, amount);
    }
    if ( block.timestamp <= eventDeadlineAttendace) {
      revert DeadlineNotReached("The event has not yet taken place");
    }
     if (!eventAttendace ) {
      revert DeadlineNotReached("You did not attend the event");
    }

    balances[sender] = 0;

    (bool success, ) = sender.call{value: amount}('');
    if (!success) {
      revert WithdrawalFailed();
    } else {
      emit WithrawalCompleted(sender, amount);
    }
  }
  

  /* create a function to withdraw money from those who do not attend the event */



}