// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/token/ERC721/IERC721.sol";
import "@openzeppelin/token/ERC721/extensions/IERC721Metadata.sol";
import {AppEventFactory} from "./AppEventFactory.sol";

interface IAppNFT is IERC721, IERC721Metadata {
    function mint(address to) external;
}

contract AppNFTGenerator is AppEventFactory {
    ///@dev Here we will find out how many times an user has attended some particular DAO events to be
    ///@dev able to upgrade NFT level
    mapping(address => mapping(address => uint256))
        public userDaoEventAttendanceCounter;

    //! To fix. This function MUST have a better method to avoid free execution
    function registerAttendanceDaoEvent(
        address _attendee,
        address _daoAddress
    ) external {
        userDaoEventAttendanceCounter[_attendee][_daoAddress]++;
    }

    function mintNft(address _daoAddress) public {
        address caller = msg.sender;
        address nftAddress = getDaoInfo(_daoAddress);

        require(
            userDaoEventAttendanceCounter[caller][_daoAddress] > 0,
            "You have no attended any event of this DAO"
        );
        require(
            nftAddress != address(0) &&
                IAppNFT(nftAddress).balanceOf(caller) == 0,
            "You already have a NFT"
        );

        IAppNFT(nftAddress).mint(caller);
    }

    function getUserAttendanceCounterPerDao(
        address _user,
        address _daoAddress
    ) public view returns (uint256) {
        return userDaoEventAttendanceCounter[_user][_daoAddress];
    }
}
