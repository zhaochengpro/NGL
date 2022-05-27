pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./NGLStruct.sol";

contract NGLStorage is AccessControl {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    // ======================================== CONSTANT VARIBLE ========================================
    bytes32 public constant LOGIC_CONTRACT_ROLE = keccak256("LOGIC_CONTRACT_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant BOT_ROLE = keccak256("BOT_ROLE");

    // ======================================== PUBLIC VARIBLE ========================================
    uint256 public _memberId;
    mapping(address => uint256) public memberIdOf;
    uint256 public v4balance;
    address public platformA;
    uint256 public platformABalance;
    address public platformB;
    uint256 public platformBBalance;
    address public platformC;
    uint256 public platformCBalance;
    address public trashAddress;
    uint256 public trashBalance;
    uint256 public withdrawThreshold = 1 * 10 ** 16;

    // the lowest balane of want to upgrade
    uint256 public upgradeToV1Income = 5 * 10 ** 18;
    uint256 public upgradeToV1Amount = 10;
    // the lowest number of invitation of want to upgrade
    uint256 public upgradeToV2Amount = 2;
    // the lowest balane of want to upgrade
    uint256 public upgradeToV2Income = 8 * 10 ** 18;
    uint256 public upgradeToV3Income = 12 * 10 ** 18;
    uint256 public upgradeToV3Amount = 2;
    uint256 public upgradeToV4Income = 20 * 10 ** 18;
    uint256 public upgradeToV4Amount = 3;
    bool public isInitalize;
    // number div 100
    uint16 public depositToPlatform = 3;
    uint16 public depositToStatic = 50;
    uint16 public depositToMarket = 47;

    // number div 3 * 10
    uint16 public platformToC = 24;
    uint16 public platformToB = 3;
    uint16 public platformToA = 3;

    // number div 50
    uint16 public staticToFrontSeventy = 35;
    uint16 public staticToInviation = 15;
    uint16 public staticToSelf = 15;

    // number div 47
    uint16 public marketToDirect = 20;
    uint16 public marketToInter = 10;
    uint16 public marketToManager = 15;
    uint16 public marketToAllV4 = 2;
    uint64 public marketToV1 = 3;
    uint64 public marketToV2 = 4;
    uint64 public marketToV3 = 4;
    uint64 public marketToV4 = 4;

    // withdraw rate
    uint16 public withdrawToFrontAndBack = 30;
    uint16 public withdrawToSelf = 70;

    address public logicAddress;

    // ======================================== PRIVATE VARIBLE ========================================
    mapping(address => bool) private _isDeposit;
    mapping(uint256 => NGLStruct.Member) private _members;
    mapping(uint8 => NGLStruct.Level) private _levels;
    uint8 private _levelId;
    mapping(uint256 => uint8) private _amountToLevel;

    mapping(uint256 => uint256) private _relationship;
    mapping(uint256 => EnumerableSet.UintSet) private _directInvitation;
    EnumerableSet.UintSet private _marketLevelOneToMember;
    EnumerableSet.UintSet private _marketLevelTwoToMember;
    EnumerableSet.UintSet private _marketLevelThreeToMember;
    EnumerableSet.UintSet private _marketLevelFourToMember;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function logicContract(address logicAddress_) public onlyRole(DEFAULT_ADMIN_ROLE) {
        logicAddress = logicAddress_;
    }

    function setMemberId(uint256 memberId) public onlyRole(LOGIC_CONTRACT_ROLE) {
        _memberId = memberId;
    }

    function getMemberId() public onlyRole(LOGIC_CONTRACT_ROLE) view returns (uint256) {
        return _memberId;
    }

    function setWithdrawThreshold(uint256 withdrawThreshold_) public onlyRole(LOGIC_CONTRACT_ROLE) {
        withdrawThreshold = withdrawThreshold_;
    }


    function addMemberId() public onlyRole(LOGIC_CONTRACT_ROLE) {
        _memberId += 1;
    }

    function setMemberIdOf(address account, uint256 memberId) public onlyRole(LOGIC_CONTRACT_ROLE) {
        memberIdOf[account] = memberId;
    }

    function setV4balance(uint256 amount) public onlyRole(LOGIC_CONTRACT_ROLE) {
        v4balance = amount;
    }

    function setPlatformA(address account) public onlyRole(LOGIC_CONTRACT_ROLE) {
        platformA = account;
    }
    
    function setPlatformABalance(uint256 amount) public onlyRole(LOGIC_CONTRACT_ROLE) {
        platformABalance = amount;
    }
    
    function setPlatformB(address account) public onlyRole(LOGIC_CONTRACT_ROLE) {
        platformB = account;
    }

    function setPlatformBBalance(uint256 amount) public onlyRole(LOGIC_CONTRACT_ROLE) {
        platformBBalance = amount;
    }

    function setPlatformC(address account) public onlyRole(LOGIC_CONTRACT_ROLE) {
        platformC = account;
    }

    function setPlatformCBalance(uint256 amount) public onlyRole(LOGIC_CONTRACT_ROLE) {
        platformCBalance = amount;
    }

    function setTrashAddress(address account) public onlyRole(LOGIC_CONTRACT_ROLE) {
        trashAddress = account;
    }

    function setTrashBalance(uint256 amount) public onlyRole(LOGIC_CONTRACT_ROLE) {
        trashBalance = amount;
    }

    function setIsInitalize(bool isInitalize_) public onlyRole(LOGIC_CONTRACT_ROLE) {
        isInitalize = isInitalize_;
    }

    function setIsDeposit(address account, bool isDeposit_) public onlyRole(LOGIC_CONTRACT_ROLE) {
        _isDeposit[account] = isDeposit_;
    }

    function getIsDeposit(address account) public onlyRole(LOGIC_CONTRACT_ROLE) returns (bool) {
        return _isDeposit[account];
    }

    function setMembers(uint256 memberId, NGLStruct.Member memory member) public onlyRole(LOGIC_CONTRACT_ROLE) {
        _members[memberId] = member;
    }

    function getMembers(uint256 memberId) public onlyRole(LOGIC_CONTRACT_ROLE) view returns (NGLStruct.Member memory) {
        return _members[memberId];
    }

    function setLevel(uint8 levelId, NGLStruct.Level memory level) public onlyRole(LOGIC_CONTRACT_ROLE) {
        _levels[levelId] = level;
    }
    
    function getLevel(uint8 levelId) public onlyRole(LOGIC_CONTRACT_ROLE) view returns (NGLStruct.Level memory) {
        return _levels[levelId];
    }

    function setLevelId(uint8 levelId) public onlyRole(LOGIC_CONTRACT_ROLE) {
        _levelId = levelId;
    }

    function addLevelId() public onlyRole(LOGIC_CONTRACT_ROLE) {
        _levelId += 1;
    }
    
    function getLevelId() public onlyRole(LOGIC_CONTRACT_ROLE) view returns (uint8) {
        return _levelId;
    }

    function setAmountToLevel(uint256 amount, uint8 levelId) public onlyRole(LOGIC_CONTRACT_ROLE) {
        _amountToLevel[amount] = levelId;
    }

    function getAmountToLevel(uint256 amount) public onlyRole(LOGIC_CONTRACT_ROLE) view returns (uint8) {
        return _amountToLevel[amount];
    }

    function setRelationship(uint256 memberId, uint256 inviterId) public onlyRole(LOGIC_CONTRACT_ROLE) {
        _relationship[memberId] = inviterId;
    }

    function getRelationship(uint256 memberId) public onlyRole(LOGIC_CONTRACT_ROLE) view returns (uint256) {
        return _relationship[memberId];
    }

    function setDirectInvitation(uint256 inviterId, uint256 memberId) public onlyRole(LOGIC_CONTRACT_ROLE) {
        _directInvitation[inviterId].add(memberId);
    }
    
    function getDirectInvitation(uint256 inviterId) public onlyRole(LOGIC_CONTRACT_ROLE) view returns (uint256[] memory) {
        return _directInvitation[inviterId].values();
    }

    function setMarketLevelOneToMember(uint256 memberId) public onlyRole(LOGIC_CONTRACT_ROLE) {
        _marketLevelOneToMember.add(memberId);
    }

    function getMarketLevelOneToMember() public onlyRole(LOGIC_CONTRACT_ROLE) view returns (uint256[] memory) {
        return _marketLevelOneToMember.values();
    }

    function setMarketLevelTwoToMember(uint256 memberId) public onlyRole(LOGIC_CONTRACT_ROLE) {
        _marketLevelTwoToMember.add(memberId);
    }

    function getMarketLevelTwoToMember() public onlyRole(LOGIC_CONTRACT_ROLE) view returns (uint256[] memory) {
        return _marketLevelTwoToMember.values();
    }

    function setMarketLevelThreeToMember(uint256 memberId) public onlyRole(LOGIC_CONTRACT_ROLE) {
        _marketLevelThreeToMember.add(memberId);
    }

    function getMarketLevelThreeToMember() public onlyRole(LOGIC_CONTRACT_ROLE) view returns (uint256[] memory) {
        return _marketLevelThreeToMember.values();
    }

    function setMarketLevelFourToMember(uint256 memberId) public onlyRole(LOGIC_CONTRACT_ROLE) {
        _marketLevelFourToMember.add(memberId);
    }

    function getMarketLevelFourToMember() public onlyRole(LOGIC_CONTRACT_ROLE) view returns (uint256[] memory) {
        return _marketLevelFourToMember.values();
    }

    function setUpgradeMarketLevel(
        uint256 _upgradeToV1Amount,
        uint256 _upgradeToV1Income,
        uint256 _upgradeToV2Amount,
        uint256 _upgradeToV2Income,
        uint256 _upgradeToV3Income,
        uint256 _upgradeToV3Amount,
        uint256 _upgradeToV4Income,
        uint256 _upgradeToV4Amount
    ) external onlyRole(LOGIC_CONTRACT_ROLE) {
        upgradeToV1Income = _upgradeToV1Income;
        upgradeToV1Amount = _upgradeToV1Amount;
        upgradeToV2Amount = _upgradeToV2Amount;
        upgradeToV2Income = _upgradeToV2Income;
        upgradeToV3Income = _upgradeToV3Income;
        upgradeToV3Amount = _upgradeToV3Amount;
        upgradeToV4Amount = _upgradeToV4Amount;
        upgradeToV4Income = _upgradeToV4Income;

        isInitalize = true;
    }
}
