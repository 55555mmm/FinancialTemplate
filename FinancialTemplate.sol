// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import {AccessControlDefaultAdminRules} from "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";

contract FinancialTemplate is AccessControlDefaultAdminRules{
    bytes32 public constant ENTERPRISE_ROLE = keccak256("ENTERPRISE_ROLE");//企业
    bytes32 public constant FUNDING_PARTY_ROLE = keccak256("FUNDING_PARTY_ROLE");//资金方
    bytes32 public constant AUCTION_PUBLISHER_ROLE = keccak256("AUCTION_PUBLISHER_ROLE"); // 拍卖信息发布者
    bytes32 public constant BIDDER_ROLE = keccak256("BIDDER_ROLE"); // 投标与竞标者
    uint256 public nextRoleId;
    uint256 public nextAuctionId;

    // 企业注册信息（企业身份）
    struct EnterpriseInfo {
        string registrationNumber;  // 注册号
        string legalRepresentative; // 法定代表人
        string companyName;         // 企业名称
        string registrationAddress; // 注册地址
        uint256 establishmentDate;   // 成立日期，可使用 Unix 时间戳表示
        bool isValid;
    }


    // 仓单
    struct WarehouseReceipt {
        string description;   // 货物描述
        string warehouseName; // 仓库名称
        uint256 quantity;     // 货物数量
        uint256 storageDate;  // 存储日期
        uint256 expiryDate;   // 仓单有效期
        address owner;        // （货物）所有权持有人
    }

    // 票据
    struct BillOfExchange {
        address drawer;        // 出票人
        address payee;         // 收款人
        uint256 amount;        // 金额
        uint256 paymentDate;   // 支付日期
        string goodsDescription; // 货物描述
    }

    // 贸易数据信息
    struct TradeData {
        WarehouseReceipt warehouseReceipt; // 仓单信息
        BillOfExchange billOfExchange;     // 票据信息
        //可添加其他跟贸易有关的信息
    }

    // 物流信息
    struct LogisticsInfo {
        string startPoint;      // 起始点
        string destination;     // 目的地
        string transportation;  // 运输方式
        string cargoStatus;     // 货物状态
    }

    // 企业还款记录
    struct RepaymentRecord {
        uint256 amount;         // 还款金额
        uint256 repaymentDate;  // 还款日期，可使用 Unix 时间戳表示
    }

    //资金方放款记录
    struct DisbursementRecord {
        uint256 amount;         // 放款金额
        uint256 disbursementDate; // 放款日期，可使用 Unix 时间戳表示
    }

    // 贷款申请信息
    struct LoanApplication {
        uint256 requestedAmount;   // 请求的贷款金额
        string purpose;            // 贷款用途
        string repaymentPlan;      // 还款计划
        LoanApplicationStatus status; // 贷款申请状态
        DisbursementRecord disbursementRecord;//资金方放款
        RepaymentRecord repaymentRecord;//企业还款
    }

    //贷款申请审核状态
    enum LoanApplicationStatus {
        Pending,     // 待审核
        Approved,    // 已批准
        Rejected     // 已拒绝
    }

    // 参与拍卖的用户信息
    struct UserInfo {
        bytes32 encryptedId; // 加密后的用户ID(用地址做hash)
        string username;
        string contactInfo;//联系信息
        bool isRegistered;
    }

    // 拍卖信息
    struct AuctionInfo {
        uint256 auctionId;
        string itemDescription;
        uint256 startPrice;//起拍价
        bool isOpen; //拍卖是否开放
        bytes32 encryptedWinningBidder; //加密后的中标者信息 
        uint256 winningBid; //中标价格
        uint256 depositAmount; //定金数量
    }

    //定金信息以及支付信息
    struct Deposit {
        uint256 auctionId;//拍卖ID
        uint256 depositAmount;
        uint256 paymentDate;
        bool isPaid;
    }

    //投标信息
    struct Bid {
        uint256 auctionId;
        uint256 bid;
        address bidder;
    }

    //转账信息
    struct Transfer{
        uint256 auctionId;
        uint256 transferAmount;
        uint256 paymentDate;
    }

    mapping(address => EnterpriseInfo) public enterpriseDataSet;//企业注册信息数据集
    mapping (address => uint256) public EnterpriseTradeDataNum;//企业贸易信息条数
    mapping (address => mapping (uint256 => TradeData)) public EnterpriseTradeDataSet;//企业贸易信息数据集
    mapping (address => bool) public FPTradeInquiryAccess;//资金方查询贸易数据权限
    mapping(address => uint256) public EnterpriseLogisticsDataNum;//企业物流信息条数
    mapping(address => mapping(uint256 => LogisticsInfo)) public EnterpriseLogisticsDataSet;//企业物流信息数据集
    mapping (address => bool) public FPLogisticsInquiryAccess;//资金方查询物流信息权限
    mapping (address => uint256) public enterpriseCreditRating;//企业信用等级
    mapping(address => uint256) public EnterpriseLoanApplicationNum;//企业贷款申请信息条数
    mapping(address => mapping(uint256 => LoanApplication)) public EnterpriseLoanApplicationDataSet;//企业贷款申请数据集
    mapping(address => UserInfo) public users;//拍卖用户集合
    mapping(uint256 => AuctionInfo) public auctions;//拍卖信息集合
    mapping(address => Deposit[]) public userDeposits;//用户定金信息
    mapping(uint256 => Bid[]) public bids;//投标信息
    mapping (address=> Transfer[]) transfers;//转账信息
    mapping(uint256 => bytes32) roles;

    event AuctionPublished(uint256 indexed auctionId, string itemDescription, uint256 startPrice, bool isopen);//拍卖信息发布 
    event AuctionClosed(uint256 indexed auctionId, bytes encryptedWinningBidder, uint256 winningBid);//拍卖结束

    constructor()AccessControlDefaultAdminRules(3 days,msg.sender){
        roles[0]=ENTERPRISE_ROLE;
        roles[1]=FUNDING_PARTY_ROLE;
        roles[2]=AUCTION_PUBLISHER_ROLE;
        roles[3]=BIDDER_ROLE;

        nextRoleId = 4;//增加角色记得修改
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
        EnterpriseInfo memory newEnterprise = EnterpriseInfo(regNumber,legalRep,name,regAddress,establishmentDate,true);
        enterpriseDataSet[_enterpriseAddr]=newEnterprise;
        grantRole(ENTERPRISE_ROLE, _enterpriseAddr);
    }

    // 返回新的仓单
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
        require(hasRole(FUNDING_PARTY_ROLE, _fundingPartyAddr), "Error: _fundingPartyAddr not FUNDING_PARTY_ROLE");
        
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
        // 确保地址是资金方角色
        require(hasRole(FUNDING_PARTY_ROLE, _fundingPartyAddr), "Error: _fundingPartyAddr not FUNDING_PARTY_ROLE");
        
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

    //资金方评估企业信用等级并将评估结果上链
    function EvaluateCreditRating(address _enterpriseAddr, uint256 credit)public onlyRole(FUNDING_PARTY_ROLE) {
        // 确保企业已注册
        require(enterpriseDataSet[_enterpriseAddr].isValid, "Error: Enterprise not registered");
        enterpriseCreditRating[_enterpriseAddr]=credit;
    }

    // 上链企业贷款申请信息
    function applyForLoan(address _enterpriseAddr, uint256 _requestedAmount, string memory _purpose,
        string memory _repaymentPlan) public onlyRole(ENTERPRISE_ROLE) {
        // 确保企业已注册
        require(enterpriseDataSet[_enterpriseAddr].isValid, "Error: Enterprise not registered.");

        DisbursementRecord memory newDR = DisbursementRecord(0, block.timestamp);
        RepaymentRecord memory newRR = RepaymentRecord(0, block.timestamp);        
        EnterpriseLoanApplicationDataSet[_enterpriseAddr][EnterpriseLoanApplicationNum[_enterpriseAddr]] = 
        LoanApplication(_requestedAmount, _purpose, _repaymentPlan, LoanApplicationStatus.Pending, newDR, newRR);
        EnterpriseLoanApplicationNum[_enterpriseAddr]++;
    }

    // 企业查询贷款申请状态(返回整个申请)
    function getLoanApplication(address _enterpriseAddr, uint256 _loanAppId) 
    public view onlyRole(ENTERPRISE_ROLE) returns (LoanApplication memory) {
        // 确保企业已注册
        require(enterpriseDataSet[_enterpriseAddr].isValid, "Error: Enterprise not registered");
        
        uint256 numLoanApps = EnterpriseLoanApplicationNum[_enterpriseAddr];
        require(_loanAppId < numLoanApps, "Error: Invalid loanAppId");

        return EnterpriseLoanApplicationDataSet[_enterpriseAddr][_loanAppId];
    }

    // 资金方评估审核贷款申请
    function evaluateLoanApplication(address _enterpriseAddr, uint256 _loanAppId, bool _isApproved) 
    public onlyRole(FUNDING_PARTY_ROLE) {
        // 确保企业已注册
        require(enterpriseDataSet[_enterpriseAddr].isValid, "Error: Enterprise not registered.");
        uint256 numLoanApps = EnterpriseLoanApplicationNum[_enterpriseAddr];
        require(_loanAppId < numLoanApps, "Error: Invalid loanAppId");

        LoanApplication storage loanApplication = EnterpriseLoanApplicationDataSet[_enterpriseAddr][_loanAppId];
        if (_isApproved) {
            loanApplication.status = LoanApplicationStatus.Approved;
        } else {
            loanApplication.status = LoanApplicationStatus.Rejected;
        }
    }

    //资金方放款记录上链
    function disburseLoan(address _enterpriseAddr, uint256 _loanAppId, uint256 _amount) 
    public onlyRole(FUNDING_PARTY_ROLE) {
        // 确保企业已注册
        require(enterpriseDataSet[_enterpriseAddr].isValid, "Error: Enterprise not registered.");
        uint256 numLoanApps = EnterpriseLoanApplicationNum[_enterpriseAddr];
        require(_loanAppId < numLoanApps, "Error: Invalid loanAppId");
        
        LoanApplication storage loanApplication = EnterpriseLoanApplicationDataSet[_enterpriseAddr][_loanAppId];
        require(loanApplication.status == LoanApplicationStatus.Approved, "Error: Loan not approved.");
        
        loanApplication.disbursementRecord.amount+=_amount;
        loanApplication.disbursementRecord.disbursementDate = block.timestamp;
    }

    //企业还款记录上链
    function repayLoan(address _enterpriseAddr, uint256 _loanAppId, uint256 _amount) 
    public onlyRole(ENTERPRISE_ROLE) {
        // 确保企业已注册
        require(enterpriseDataSet[_enterpriseAddr].isValid, "Error: Enterprise not registered.");
        uint256 numLoanApps = EnterpriseLoanApplicationNum[_enterpriseAddr];
        require(_loanAppId < numLoanApps, "Error: Invalid loanAppId");
        
        LoanApplication storage loanApplication = EnterpriseLoanApplicationDataSet[_enterpriseAddr][_loanAppId];
        require(loanApplication.status == LoanApplicationStatus.Approved, "Error: Loan not approved.");
        
        loanApplication.repaymentRecord.amount += _amount;
        loanApplication.repaymentRecord.repaymentDate = block.timestamp;
    }

    // 拍卖用户注册(加密账号)
    function registerUser(address _userAddr, string memory _username, string memory _contactInfo, bool isPublished) public {
        require(!users[msg.sender].isRegistered, "User is already registered");

        UserInfo memory newUser = UserInfo(keccak256(abi.encodePacked(_userAddr)), _username, _contactInfo, true);
        users[_userAddr]=newUser;

        if(isPublished)grantRole(AUCTION_PUBLISHER_ROLE, _userAddr);
        grantRole(BIDDER_ROLE, _userAddr);
    }

    // 拍卖信息发布者发布拍卖活动
    function publishAuction(string memory _itemDescription, uint256 _startingPrice, uint256 _depositAmount) 
    public onlyRole(AUCTION_PUBLISHER_ROLE) {
        uint256 auctionId = getNextAuctionId()-1;//从0开始
        auctions[auctionId] = AuctionInfo(auctionId, _itemDescription, _startingPrice, 
        true, bytes32(""), 0, _depositAmount);

        // 拍卖信息发布事件通知
        emit AuctionPublished(auctionId, _itemDescription, _startingPrice, true);
    }

    // 获取下一个拍卖ID
    function getNextAuctionId() internal returns (uint256) {
        nextAuctionId++;
        return nextAuctionId;
    }

    //定金信息上链
    function payDeposit(uint256 _auctionId) external onlyRole(BIDDER_ROLE) {
        AuctionInfo storage auction = auctions[_auctionId];
        require(auction.isOpen, "Auction closed");
    
        Deposit memory depositRecord = Deposit(_auctionId, auction.depositAmount, block.timestamp, true);
        userDeposits[msg.sender].push(depositRecord);
    }

    //投标者投标
    function placeBid(uint256 _auctionId, uint256 bid) external onlyRole(BIDDER_ROLE) {
        AuctionInfo storage auction = auctions[_auctionId];
        require(auction.isOpen, "Auction closed");
        bids[_auctionId].push(Bid(_auctionId, bid, msg.sender));
    }

    //最高出价筛选和中标上链
    function closeAuction(uint256 _auctionId, bytes calldata _encryptedWinningBidder) external onlyRole(DEFAULT_ADMIN_ROLE) {
        AuctionInfo storage auction = auctions[_auctionId];
        require(!auction.isOpen, "Auction already closed");

        uint256 highestBid = 0;
        address winningBidder = address(0);

        for (uint256 i = 0; i < bids[_auctionId].length; i++) {
            if (bids[_auctionId][i].bid > highestBid) {
                highestBid = bids[_auctionId][i].bid;
                winningBidder = bids[_auctionId][i].bidder;
            }
        }

        auction.isOpen = false;
        auction.encryptedWinningBidder =keccak256(abi.encodePacked(winningBidder));
        auction.winningBid = highestBid;

        emit AuctionClosed(_auctionId, _encryptedWinningBidder, highestBid);

        // 善后工作
        uint256 deposit = auctions[_auctionId].depositAmount;
        for (uint256 i = 0; i < bids[_auctionId].length; i++) {
            if (bids[_auctionId][i].bidder != winningBidder) {
                transfers[bids[_auctionId][i].bidder].push(Transfer(_auctionId, deposit, block.timestamp));
            }else{
                transfers[bids[_auctionId][i].bidder].push(Transfer(_auctionId, deposit-highestBid, block.timestamp));
            }
        }

    }

}