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

    // 物流信息结构体
    struct LogisticsInfo {
        string startPoint;      // 起始点
        string destination;     // 目的地
        string transportation;  // 运输方式
        string cargoStatus;     // 货物状态
    }


    mapping(address => EnterpriseInfo) public enterpriseDataSet;//企业注册信息数据集
    mapping (address => uint256) public EnterpriseTradeDataNum;//企业贸易信息条数
    mapping (address => mapping (uint256 => TradeData)) public EnterpriseTradeDataSet;//企业贸易信息数据集
    mapping (address => mapping (address=>bool)) public isFundingParty;//资金方与企业对应
    mapping (address => bool) public FPTradeInquiryAccess;//资金方查询贸易数据权限
    mapping(address => uint256) public EnterpriseLogisticsDataNum;//企业物流信息条数
    mapping(address => mapping(uint256 => LogisticsInfo)) public EnterpriseLogisticsDataSet;//企业物流信息数据集
    mapping (address => bool) public FPLogisticsInquiryAccess;//资金方查询物流信息权限
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
        string memory name,string memory regAddress,uint256 establishmentDate) public onlyRole(DEFAULT_ADMIN_ROLE){
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
    uint256 _quantity, uint256 _storageDate, uint256 _expiryDate, address _owner) 
    public view onlyRole(ENTERPRISE_ROLE) returns (WarehouseReceipt memory) {
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
    function getTradeData(address _enterpriseAddr, uint256 _tradeId) public view 
    onlyRole(ENTERPRISE_ROLE) returns (TradeData memory) {
        // 确保企业已注册
        require(enterpriseDataSet[_enterpriseAddr].isValid, "Error: Enterprise not registered");

        uint256 numTradeData = EnterpriseTradeDataNum[_enterpriseAddr];
        require(_tradeId < numTradeData, "Error: Invalid tradeId");
        
        return EnterpriseTradeDataSet[_enterpriseAddr][_tradeId];
    }

    // 授予资金方贸易数据查询权限
    function grantTradeDataAccess(address _fundingPartyAddr, address _enterpriseAddr) public onlyRole(ENTERPRISE_ROLE) {
        // 确保企业已注册
        require(enterpriseDataSet[_enterpriseAddr].isValid, "Error: Enterprise not registered");
        // 确保地址是企业资金方
        require(hasRole(FUNDING_PARTY_ROLE, _fundingPartyAddr) 
        && isFundingParty[_fundingPartyAddr][_enterpriseAddr], "Error: _fundingPartyAddr not FUNDING_PARTY_ROLE");
        
        FPTradeInquiryAccess[_fundingPartyAddr]=true;
    }

    // 资金方查询贸易数据
    function getTradeDataForFundingParty(address _fundingPartyAddr, address _enterpriseAddr, uint256 _tradeId) public view 
    onlyRole(FUNDING_PARTY_ROLE) returns (TradeData memory) {
        // 确保企业已注册
        require(enterpriseDataSet[_enterpriseAddr].isValid, "Error: Enterprise not registered");
        // 确保有权限
        require(FPTradeInquiryAccess[_fundingPartyAddr], "The Funding Party has no Trade Data access");

        uint256 numTradeData = EnterpriseTradeDataNum[_enterpriseAddr];
        require(_tradeId < numTradeData, "Error: Invalid tradeId");

        return EnterpriseTradeDataSet[_enterpriseAddr][_tradeId];
    }

    //物流信息上链
    function uploadLogisticsInfo(address _enterpriseAddr, string memory _startPoint,
        string memory _destination, string memory _transportation, string memory _cargoStatus) 
        public onlyRole(ENTERPRISE_ROLE) {
        // 确保企业已注册
        require(enterpriseDataSet[_enterpriseAddr].isValid, "Error: Enterprise not registered.");

        EnterpriseLogisticsDataSet[_enterpriseAddr][EnterpriseLogisticsDataNum[_enterpriseAddr]] = 
        LogisticsInfo(_startPoint, _destination, _transportation, _cargoStatus);

        // 更新物流信息条数
        EnterpriseLogisticsDataNum[_enterpriseAddr]++;
    }

    //企业查询物流信息
    function getLogisticsInfoForEnterprise(address _enterpriseAddr, uint256 _logisticsId) 
    public view onlyRole(ENTERPRISE_ROLE) returns (LogisticsInfo memory) {
        // 确保企业已注册
        require(enterpriseDataSet[_enterpriseAddr].isValid, "Error: Enterprise not registered");
        
        uint256 numLogisticsData = EnterpriseLogisticsDataNum[_enterpriseAddr];
        require(_logisticsId < numLogisticsData, "Error: Invalid logisticsId");

        return EnterpriseLogisticsDataSet[_enterpriseAddr][_logisticsId];
    }

    //授予资金方物流信息查询权限
    function grantLogisticsAccess(address _fundingPartyAddr, address _enterpriseAddr) public onlyRole(ENTERPRISE_ROLE) {
        // 确保企业已注册
        require(enterpriseDataSet[_enterpriseAddr].isValid, "Error: Enterprise not registered");
        // 确保地址是企业资金方
        require(hasRole(FUNDING_PARTY_ROLE, _fundingPartyAddr) 
        && isFundingParty[_fundingPartyAddr][_enterpriseAddr], "Error: _fundingPartyAddr not FUNDING_PARTY_ROLE");
        
        FPLogisticsInquiryAccess[_fundingPartyAddr]=true;
    }

    //资金方查询物流信息
    function getLogisticsInfoForFundingParty(address _fundingPartyAddr, address _enterpriseAddr,
    uint256 _logisticsId) public view onlyRole(FUNDING_PARTY_ROLE) returns (LogisticsInfo memory) {
        // 确保企业已注册
        require(enterpriseDataSet[_enterpriseAddr].isValid, "Error: Enterprise not registered");
        // 确保有权限
        require(FPLogisticsInquiryAccess[_fundingPartyAddr], "The Funding Party has no Logistics access");

        uint256 numLogisticsData = EnterpriseLogisticsDataNum[_enterpriseAddr];
        require(_logisticsId < numLogisticsData, "Error: Invalid logisticsId");

        return EnterpriseLogisticsDataSet[_enterpriseAddr][_logisticsId];
    }















}