// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {AppNFT} from "./AppNFT.sol";

abstract contract AppDaoManagement {
    struct DaoInfo {
        string name;
        address daoAddress;
        address nftAddress;
    }

    mapping(address => DaoInfo) private daos;

    function registerDao(string memory _daoName, address _daoAddress) public {
        require(bytes(_daoName).length > 0, "Dao name cannot be empty");

        AppNFT daoNFT = new AppNFT(_daoAddress, "");
        daoNFT.transferOwnership(msg.sender);

        DaoInfo storage newDao = daos[_daoAddress];
        newDao.name = _daoName;
        newDao.daoAddress = _daoAddress;
        newDao.nftAddress = address(daoNFT);
    }

    function getDaoInfo(
        address _daoAddress
    ) public view returns (DaoInfo memory) {
        DaoInfo memory daoReturned = daos[_daoAddress];
        require(daoReturned.daoAddress != address(0), "Dao not found");
        return daoReturned;
    }
}
