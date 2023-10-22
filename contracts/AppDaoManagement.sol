// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

abstract contract AppDaoManagement {
    struct DaoInfo {
        string name;
        address daoAddress;
    }

    mapping(address => DaoInfo) private daos;

    function registerDao(string memory _daoName, address _daoAddress) public {
        require(bytes(_daoName).length > 0, "Dao name cannot be empty");

        DaoInfo storage newDao = daos[_daoAddress];
        newDao.name = _daoName;
        newDao.daoAddress = _daoAddress;
    }

    function getDaoInfo(
        address _daoAddress
    ) public view returns (DaoInfo memory) {
        DaoInfo memory daoReturned = daos[_daoAddress];
        require(daoReturned.daoAddress != address(0), "Dao not found");
        return daoReturned;
    }
}
