// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import {AccessControlDefaultAdminRules} from "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";

contract FinancialTemplate is AccessControlDefaultAdminRules{
    bytes32 public constant ENTERPRISE_ROLE = keccak256("ENTERPRISE_ROLE");//企业
    bytes32 public constant FUNDING_PARTY_ROLE = keccak256("FUNDING_PARTY_ROLE");//资金方
    uint256 public nextRoleId;

    // 企业注册信息（企业身份）结构体
    struct EnterpriseInfo {
        string registrationNumber;  // 注册号
        string legalRepresentative; // 法定代表人
        string companyName;         // 企业名称
        string registrationAddress; // 注册地址
        uint256 establishmentDate;   // 成立日期，可使用 Unix 时间戳表示
        bool isValid;
    }


    // 仓单结构体
    struct WarehouseReceipt {
        string description;   // 货物描述
        string warehouseName; // 仓库名称
        uint256 quantity;     // 货物数量
        uint256 storageDate;  // 存储日期
        uint256 expiryDate;   // 仓单有效期
        address owner;        // （货物）所有权持有人
    }

    // 票据结构体
    struct BillOfExchange {
        address drawer;        // 出票人
        address payee;         // 收款人
        uint256 amount;        // 金额
        uint256 paymentDate;   // 支付日期
        string goodsDescription; // 货物描述
    }

    // 贸易数据信息结构体
    struct TradeData {
        WarehouseReceipt warehouseReceipt; // 仓单信息
        BillOfExchange billOfExchange;     // 票据信息
        //可添加其他跟贸易有关的信息
    }


    mapping(address => EnterpriseInfo) public enterpriseDataSet;//企业注册信息数据集
    mapping (address => uint256) public EnterpriseTradeDataNum;//企业贸易信息条数
    mapping (address => mapping (uint256 => TradeData)) public EnterpriseTradeDataSet;//企业贸易信息数据集
    mapping(uint256 => bytes32) roles;

    constructor()AccessControlDefaultAdminRules(3 days,msg.sender){
        roles[0]=ENTERPRISE_ROLE;
        roles[1]=FUNDING_PARTY_ROLE;

        nextRoleId = 2;//增加角色记得修改
    }

    //checkRole函数用于检查给定的地址是否拥有某个角色权限
    function checkRole(address _checkAddr,bytes32 _role) public view onlyRole(DEFAULT_ADMIN_ROLE) returns(bool) {
        return hasRole(_role, _checkAddr);
    }

    //企业注册
    function registerEnterprise(address _enterpriseAddr,string memory regNumber,string memory legalRep,
        string memory name,string memory regAddress,uint256 establishmentDate)public onlyRole(DEFAULT_ADMIN_ROLE){
            require(enterpriseDataSet[_enterpriseAddr].isValid==false,
            "Error : This address has already been added as a enterprise.");
            EnterpriseInfo memory newEnterprise = EnterpriseInfo(
                regNumber,legalRep,name,regAddress,establishmentDate,true
            );
            enterpriseDataSet[_enterpriseAddr]=newEnterprise;
            grantRole(ENTERPRISE_ROLE, _enterpriseAddr);
    }

    //返回新的仓单
    function createNewWarehouseReceipt(string memory _description, string memory _warehouseName,
        uint256 _quantity, uint256 _storageDate, uint256 _expiryDate, address _owner
    ) public view onlyRole(ENTERPRISE_ROLE) returns (WarehouseReceipt memory) {
        return WarehouseReceipt(_description, _warehouseName, 
        _quantity, _storageDate, _expiryDate, _owner);
    }

    // 返回新的票据
    function createNewBillOfExchange(address _drawer, address _payee, uint256 _amount, 
    uint256 _paymentDate, string memory _goodsDescription) public view onlyRole(ENTERPRISE_ROLE) 
    returns (BillOfExchange memory) {
        return BillOfExchange(_drawer, _payee, _amount, _paymentDate, _goodsDescription);
    }

    //贸易信息上链
    function uploadTradeData(address _enterpriseAddr, WarehouseReceipt memory _warehouseReceipt,
    BillOfExchange memory _billOfExchange) public onlyRole(ENTERPRISE_ROLE) {
        // 确保企业已注册
        require(enterpriseDataSet[_enterpriseAddr].isValid, "Error: Enterprise not registered.");
        EnterpriseTradeDataSet[_enterpriseAddr][EnterpriseTradeDataNum[_enterpriseAddr]].warehouseReceipt = _warehouseReceipt;
        EnterpriseTradeDataSet[_enterpriseAddr][EnterpriseTradeDataNum[_enterpriseAddr]].billOfExchange = _billOfExchange;
        // 更新贸易信息条数
        EnterpriseTradeDataNum[_enterpriseAddr]++;
    }

    //企业查询贸易数据
    // 查询已上链的贸易数据
    function getTradeData(address _enterpriseAddr, uint256 _tradeId) public view returns (TradeData memory) {
        // 确保企业已注册
        require(enterpriseDataSet[_enterpriseAddr].isValid, "Error: Enterprise not registered");

        uint256 numTradeData = EnterpriseTradeDataNum[_enterpriseAddr];
        require(_tradeId < numTradeData, "Error: Invalid tradeId");
        
        return EnterpriseTradeDataSet[_enterpriseAddr][_tradeId];
    }






}