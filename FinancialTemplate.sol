// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import {AccessControlDefaultAdminRules} from "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";

contract FinancialTemplate is AccessControlDefaultAdminRules{
    bytes32 public constant ENTERPRISE_ROLE = keccak256("ENTERPRISE_ROLE");//企业
    bytes32 public constant FUNDING_PARTY_ROLE = keccak256("FUNDING_PARTY_ROLE");//资金方
    uint256 public nextRoleId;
    
    


    mapping(uint256 => bytes32) roles;
    constructor()AccessControlDefaultAdminRules(3 days,msg.sender){
        roles[0]=ENTERPRISE_ROLE;
        roles[1]=FUNDING_PARTY_ROLE;

        nextRoleId = 2;//增加角色记得修改
    }
}