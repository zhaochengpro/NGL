// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";
	// "address _platformA": "0x6D07a8885e8a72A32c4DbDe11A7e6D286d86a267",
	// "address _platformB": "0xD57346E0bf19e372f966BCb7F520BE2620bB6194",
	// "address _platformC": "0x9de2c3AA448Badf1fCB4f9CcAcA3Eb59f9C59298"
    //0x357b4C6CF77B6a7085Aa7C94B5CcF84441971EA7
    // 10000000000000000
    //10000000000000000

contract NGL is AccessControl, ReentrancyGuard {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    // ======================================== EVENT ========================================
    event Deposit(uint256 indexed memberId, address indexed account, uint256 indexed inviterId, uint256 amount);
    event Redeposit(uint256 indexed memberId, address indexed account, uint256 amount);
    event Upgrade(uint256 indexed memberId, uint8 oldLevel, uint8 newLevel);
    event WithDraw(uint256 indexed memberId, uint256 balance, uint256 reward);
    event RewardV4(uint256 amount, uint256 time);

    // ======================================== CONSTANT VARIBLE ========================================
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
    uint256 public withdrawThreshold;

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

    // ======================================== PRIVATE VARIBLE ========================================
    mapping(address => bool) private _isDeposit;
    mapping(uint256 => Member) private _members;
    mapping(uint8 => Level) private _levels;
    uint8 private _levelId;
    mapping(uint256 => uint8) private _amountToLevel;

    mapping(uint256 => uint256) private _relationship;
    mapping(uint256 => EnumerableSet.UintSet) private _directInvitation;
    EnumerableSet.UintSet private _marketLevelOneToMember;
    EnumerableSet.UintSet private _marketLevelTwoToMember;
    EnumerableSet.UintSet private _marketLevelThreeToMember;
    EnumerableSet.UintSet private _marketLevelFourToMember;

    struct Member {
        uint256 id;
        uint256 balance;
        uint256 totalIncome;
        uint256 frontBalance;
        uint256 backBalance;
        uint256 totalDeposit;
        uint256 totalWithdraw;
        uint256 dynamicBalance;
        uint256 lastDepositTime;
        address account;
        uint8 level;
        uint8 marketLevel;
    }

    struct Level {
        uint8 id;
        uint248 front;
        uint256 back;
        uint256 value;
    }

    constructor(
        address _platformA,
        address _platformB,
        address _platformC,
        address _trashAddress,
        uint256 _withdrawThreshold
    ) {
        // initialize roles
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(MANAGER_ROLE, _msgSender());

        // initialize level
        addLevel(30, 70, 1 * 10 ** 17);

        _amountToLevel[1 * 10 ** 17] = _levelId;

        platformA = _platformA;
        platformB = _platformB;
        platformC = _platformC;
        trashAddress = _trashAddress;
        // skip 0
        _memberId++;
        _addMember(platformC, 6, 0, 0);

        withdrawThreshold = _withdrawThreshold;
    }

    // ======================================== EXTERNAL FUNCTION ========================================
    // function deposit(uint256 amount, uint256 inviterId) external payable nonReentrant {
    //     require(amount == msg.value, "Not enough value");
    //     require(_isValidLevel(amount), "Please deposit specifical amount");
    //     address account = _msgSender();
    //     require(!_isDeposit[account], "Already deposit");
    //     require(_isValidInviter(inviterId), "Invalid inviter");
    //     _isDeposit[account] = true;

    //     // update relationship
    //     _relationship[_memberId] = inviterId;
    //     _directInvitation[inviterId].add(_memberId);

    //     // deposit
    //     _deposit(amount, _memberId, inviterId);

    //     // add member
    //     _addMember(account, _amountToLevel[amount], 0, amount);
    //     emit Deposit(_memberId, account, inviterId, amount);
    // }

    function deposit(uint256 memberId_, uint256 inviterId_, uint256 amount, Member[] memory staticMembers, Member[] memory marketMembers) external payable {
        require(memberId_ == staticMembers[0].id, "member id not match");
        require(_verify(memberId_, inviterId_, amount, staticMembers, marketMembers), "Invalid deposit");
    }

    function _verify(uint256 memberId, uint256 inviterId, uint256 amount, Member[] memory staticMembers, Member[] memory marketMembers) internal view returns (bool) {
        Member memory member = _members[1];
        _deposit(memberId, inviterId, amount, staticMembers, marketMembers);
        return false;
    }

    function upgrade(uint256 memberId) external {
        require(isInitalize, "Not initalize");
        Member storage member = _members[memberId];
        uint8 oldLevel = member.level;
        require(_msgSender() == member.account || hasRole(MANAGER_ROLE, _msgSender()), "not the owner of this member account");
        require(_canUpgrade(member), "not qualification to upgrade");

        if (member.marketLevel == 0) {
            member.marketLevel = 1;
            _marketLevelOneToMember.add(member.id);
        } else if (member.marketLevel == 1) {
            member.marketLevel = 2;
            _marketLevelTwoToMember.add(member.id);
        } else if (member.marketLevel == 2) {
            member.marketLevel = 3;
            _marketLevelThreeToMember.add(member.id);
        } else if (member.marketLevel == 3) {
            member.marketLevel = 4;
            _marketLevelFourToMember.add(member.id);
        }

        emit Upgrade(memberId, oldLevel, member.marketLevel);
    }

    // function withDraw(uint256 memberId, uint256 amount) external nonReentrant {
    //     require(_canWithDraw(memberId, amount), "invalid withdraw");
    //     Member storage member = _members[memberId];
    //     uint256 totalBalanceOfMember = amount;
    //     member.balance -= amount;
    //     member.totalWithdraw += amount;
    //     uint256 withDrawToFrontAndBack = totalBalanceOfMember.mul(withdrawToFrontAndBack).div(100); // withdraw to front and back
    //     uint256 withDrawToSelf = totalBalanceOfMember.mul(withdrawToSelf).div(100); // withdraw to self

    //     // to front 70
    //     _rewardToFrontSeventyPercent(memberId, withDrawToFrontAndBack, 100);
    //     // to back 30
    //     _rewardToBackThirtyPercent(memberId, withDrawToFrontAndBack, 100);

    //     // to self
    //     payable(_msgSender()).transfer(withDrawToSelf);

    //     emit WithDraw(memberId, totalBalanceOfMember, withDrawToSelf);
    // }

    function withdrawPlatformA() external onlyRole(MANAGER_ROLE) {
        payable(platformA).transfer(platformABalance);
    }
    
    function withdrawPlatformB() external onlyRole(MANAGER_ROLE) {
        payable(platformB).transfer(platformBBalance);
    }

    function withdrawPlatformC() external onlyRole(MANAGER_ROLE) {
        payable(platformC).transfer(platformCBalance);
    }

    function withdrawTrash() external onlyRole(MANAGER_ROLE) {
        payable(trashAddress).transfer(trashBalance);
    }

    function emencyWithDraw(address account) external onlyRole(MANAGER_ROLE) {
        payable(account).transfer(address(this).balance);
    }

    function rewardV4() external onlyRole(BOT_ROLE) {
        (bool success, uint256 value) = v4balance.tryDiv(
            _marketLevelFourToMember.length()
        );
        require(success, "reward failed");

        for (uint256 i = 0; i < _marketLevelFourToMember.length(); i++) {
            uint256 mLevelFourMemberId = _marketLevelFourToMember.at(i);
            Member storage member = _members[mLevelFourMemberId];
            member.balance += value;
            member.dynamicBalance += value;
        }

        v4balance = 0;

        emit RewardV4(value, block.timestamp);
    }

    function canUpgrade(uint256 memberId) external view returns (bool) {
        Member memory member = _members[memberId];
        return _canUpgrade(member);
    }

    function initalize(
        uint256 _upgradeToV1Amount,
        uint256 _upgradeToV1Income,
        uint256 _upgradeToV2Amount,
        uint256 _upgradeToV2Income,
        uint256 _upgradeToV3Income,
        uint256 _upgradeToV3Amount,
        uint256 _upgradeToV4Income,
        uint256 _upgradeToV4Amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
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

    function addLevel(
        uint248 _up,
        uint256 _down,
        uint256 _value
    ) public onlyRole(MANAGER_ROLE) {
        _levelId++;
        _levels[_levelId] = Level(_levelId, _up, _down, _value);
        _amountToLevel[_value] = _levelId;
    }

    function setUpgradeToV1Income(uint256 amount)
        external
        onlyRole(MANAGER_ROLE)
    {
        upgradeToV1Income = amount;
    }

    function setUpgradeToV2Amount(uint256 amount)
        external
        onlyRole(MANAGER_ROLE)
    {
        upgradeToV2Amount = amount;
    }

    function setUpgradeIncome(uint8 marketLevel, uint256 needIncome)
        external
        onlyRole(MANAGER_ROLE)
    {
        if (marketLevel == 2) {
            upgradeToV2Income = needIncome;
        } else if (marketLevel == 3) {
            upgradeToV3Income = needIncome;
        } else if (marketLevel == 4) {
            upgradeToV4Income = needIncome;
        }
    }

    function setMarketLevel(uint256 _memberId, uint8 _marketLevel) external onlyRole(MANAGER_ROLE) {
        Member storage member = _members[_memberId];
        member.marketLevel = _marketLevel;
    }

    function setThreshold(uint256 _threshold) external onlyRole(MANAGER_ROLE) {
        withdrawThreshold = _threshold;
    }

    function setPlatformA(address _platformA) external onlyRole(MANAGER_ROLE) {
        platformA = _platformA;
    }

    function setPlatformB(address _platformB) external onlyRole(MANAGER_ROLE) {
        platformB = _platformB;
    }

    function setPlatformC(address _platformC) external onlyRole(MANAGER_ROLE) {
        platformC = _platformC;
    }

    function setTrashAddress(address _trashAddress) external onlyRole(MANAGER_ROLE) {
        trashAddress = _trashAddress;
    }

    function resetFundRate(
        uint16 _depositToPlatform,
        uint16 _depositToStatic,
        uint16 _depositToMarket
    ) external onlyRole(MANAGER_ROLE) {
        depositToPlatform = _depositToPlatform;
        depositToStatic = _depositToStatic;
        depositToMarket = _depositToMarket;
    }

    function resetStaticRate(
        uint16 _staticToFrontSeventy,
        uint16 _staticToInviation,
        uint16 _staticToSelf
    ) external onlyRole(MANAGER_ROLE) {
        staticToFrontSeventy = _staticToFrontSeventy;
        staticToInviation = _staticToInviation;
        staticToSelf = _staticToSelf;
    }

    function resetPlatformRate(
        uint16 _platformToC,
        uint16 _platformToB,
        uint16 _platformToA
    ) external onlyRole(MANAGER_ROLE) {
        platformToC = _platformToC;
        platformToB = _platformToB;
        platformToA = _platformToA;
    }

    function resetMarket(
        uint16 _marketToDirect,
        uint16 _marketToInter,
        uint16 _marketToManager,
        uint16 _marketToAllV4
    ) external onlyRole(MANAGER_ROLE) {
        marketToDirect = _marketToDirect;
        marketToInter = _marketToInter;
        marketToManager = _marketToManager;
        marketToAllV4 = _marketToAllV4;
    }

    function resetManager(
        uint64 _marketToV1,
        uint64 _marketToV2,
        uint64 _marketToV3,
        uint64 _marketToV4
    ) external onlyRole(MANAGER_ROLE) {
        marketToV1 = _marketToV1;
        marketToV2 = _marketToV2;
        marketToV3 = _marketToV3;
        marketToV4 = _marketToV4;
    }

    function resetWithdraw(
        uint16 _withdrawToFrontAndBack,
        uint16 _withdrawToSelf
    ) external onlyRole(MANAGER_ROLE) {
        withdrawToFrontAndBack = _withdrawToFrontAndBack;
        withdrawToSelf = _withdrawToSelf;
    }

    // ================================ VIEW FUNCTION ================================

    function inviterId(uint256 memberId) external view returns (uint256) {
        return _relationship[memberId];
    }

    function memberOf(uint256 memberId) external view returns (
        uint256 _frontBalance,
        uint256 _backBalance,
        uint256 _totalDeposit,
        uint256 _totalWithdraw,
        uint256 _totalIncome,
        uint256 _dynamicBalance,
        uint256 _id,
        uint256 _balance,
        address _account,
        uint8 _level,
        uint8 _marketLevel,
        uint256 _lastDepositTime
    ) {
        Member memory member = _members[memberId];
        _id = member.id;
        _balance = member.balance;
        _account = member.account;
        _level = member.level;
        _totalIncome = member.totalIncome;
        _marketLevel = member.marketLevel;
        _frontBalance = member.frontBalance;
        _backBalance = member.backBalance;
        _totalDeposit = member.totalDeposit;
        _totalWithdraw = member.totalWithdraw;
        _dynamicBalance = member.dynamicBalance;
        _lastDepositTime = member.lastDepositTime;
    } 

    function marketLevelOneToMember() external view returns (uint256[] memory) {
        return _marketLevelOneToMember.values();
    }
    
    function marketLevelTwoToMember() external view returns (uint256[] memory) {
        return _marketLevelTwoToMember.values();
    }

    function marketLevelThreeToMember() external view returns (uint256[] memory) {
        return _marketLevelThreeToMember.values();
    }

    function marketLevelFourToMember() external view returns (uint256[] memory) {
        return _marketLevelFourToMember.values();
    }

    function directInvitation(uint256 memberId) external view returns (uint256[] memory) {
        return _directInvitation[memberId].values();
    }

    // ======================================== INTERNAL FUNCTION ========================================

    function _isValidLevel(uint256 amount) internal view returns (bool) {
        uint256 levelId = _amountToLevel[amount];
        if (levelId == 0) return false;
        else return true;
    }

    function _isValidInviter(uint256 inviterId)
        internal
        view
        returns (bool)
    {
        Member memory inviter = _members[inviterId];
        return inviter.account != address(0) && 
            inviter.id < _memberId && 
            (inviter.account == platformC || inviter.marketLevel >= 0);
    }

    function _deposit(
        uint256 memberId,
        uint256 inviterId,
        uint256 amount,
        Member[] memory staticMembers,
        Member[] memory marketMembers
    ) internal view returns (
        uint256[5] memory,
        Member[] memory,
        Member[] memory
    ){
        return _depositCaculate(amount, memberId, inviterId, marketMembers);
    }

    function _depositCaculate(
        uint256 amount_,
        uint256 memberId_,
        uint256 inviterId_,
        Member[] memory marketMembers_
    ) internal view returns (
        uint256[5] memory,
        Member[] memory,
        Member[] memory
    ) {
        uint256 amount__ = amount_;
        uint256 memberId__ = memberId_;
        Member[] memory marketMembers__ = marketMembers_;
        // uint256 
        // to platform
        (uint256 toPlatformA, uint256 toPlatformB, uint256 toPlatformC) = _rewardToPlatfrom(amount_);
        // to static
        (Member[] memory staticMembers, uint256 trashReward) = _rewardToStatic(amount_, memberId__, inviterId_);
        // to market
        uint256 trashReward__ = trashReward;
        (
            Member[] memory marketMembers, 
            uint256 trashReward_,
            uint256 platformCReward_,
            uint256 toV4
        ) = _rewardToMarket(amount__, memberId__, marketMembers__, trashReward__, toPlatformC);

        return (
            [toPlatformA, toPlatformB, toPlatformC + platformCReward_, trashReward_, toV4],
            staticMembers,
            marketMembers
        );
    }

    function _rewardToPlatfrom(uint256 amount) internal view returns (
        uint256 toPlatformA,
        uint256 toPlatformB,
        uint256 toPlatformC
    ) {
        uint256 toPlatform = amount.mul(depositToPlatform).div(100);
        toPlatformA = toPlatform.mul(platformToA).div(depositToPlatform * 10);
        toPlatformB = toPlatform.mul(platformToB).div(depositToPlatform * 10);
        toPlatformC = toPlatform.mul(platformToC).div(depositToPlatform * 10);
    }

    function _rewardToStatic(
        uint256 amount, 
        uint256 memberId, 
        uint256 inviterId
    ) internal view returns (Member[] memory rewardedMember, uint256 trashReward){
 
        // to static
        uint256 toStatic = amount.mul(depositToStatic).div(100);
        // 100% static => 70% to 70 front;
        uint256 toStaticFront = toStatic.mul(staticToFrontSeventy).div(depositToStatic);
        // maybe 100% static => 30% to self
        uint256 toStaticSelf = toStatic.mul(staticToSelf).div(depositToStatic);
        
        // reward to self 
        rewardedMember[0].balance += toStaticSelf;
        rewardedMember[0].backBalance + toStaticSelf;
        rewardedMember[0].totalIncome + toStaticSelf;

        // to the 70 front members with the 70% static fund      otherReward include trashAddress
        (rewardedMember, trashReward) = _rewardToFrontSeventyPercent(memberId, toStaticFront, 70);
    }

    function _rewardToFrontSeventyPercent(
        uint256 memberId, 
        uint256 toStaticFront, 
        uint256 frontAmount
    ) internal view returns (Member[] memory rewardedMember, uint256 trashReward) {
        uint256 verify_count = 0;
        // have member in the range of front 70
        if (memberId >= 72) {
            for (uint256 i = 2; i <= 71; i++) {
                uint256 rewardMemberId = 72 - (i - 1);
                Member memory rewardMember = _members[rewardMemberId];
                Level memory memberLevel = _levels[rewardMember.level];
                (rewardedMember[verify_count], verify_count, trashReward) = _rewardToStaticFront(
                   toStaticFront, 
                   rewardMember, 
                   memberLevel, 
                   frontAmount, 
                   rewardedMember[verify_count], 
                   trashReward,
                   verify_count
                );
                
            }
        } else {
            uint256 restEmptyMember = 72 - memberId;
            uint256 rewardFund = toStaticFront.div(frontAmount);
            uint256 totalFundToPlatformC = restEmptyMember * rewardFund;
            for (uint256 i = 2; i <= memberId - 1; i++) {
                uint256 rewardMemberId = memberId - (i - 1);
                Member memory rewardMember = _members[rewardMemberId];
                Level memory memberLevel = _levels[rewardMember.level];
               (rewardedMember[verify_count], verify_count, trashReward) = _rewardToStaticFront(
                   toStaticFront, 
                   rewardMember, 
                   memberLevel, 
                   frontAmount, 
                   rewardedMember[verify_count], 
                   trashReward,
                   verify_count
                );
            }

            if (totalFundToPlatformC != 0) {
                trashReward += totalFundToPlatformC;
            }
        }
    }

    function _rewardToStaticFront(
        uint256 amount,
        Member memory rewardMember, 
        Level memory memberLevel,
        uint256 frontAmount, 
        Member memory rewardedMember,
        uint256 trashReward,
        uint256 verify_count
    ) internal view returns (Member memory, uint256, uint256) {
        uint256 rewardFund = amount.div(frontAmount);
        if (memberLevel.back >= 70) {
            // the 34 member in front of current member can both reward the fund
            verify_count++;
            rewardedMember.account = rewardMember.account;
            rewardedMember.id = rewardMember.id;
            rewardedMember.balance += rewardFund;
            rewardedMember.totalIncome += rewardFund;
            rewardedMember.frontBalance += rewardFund;
        } else {
            // the rest of member who satisfy specified condition in front of current member can reward the fund
            uint256 canRewardRange = rewardMember.id + memberLevel.back;
            // judge current member whether can reward the fund
            if (canRewardRange >= _memberId) {
                verify_count++;
                rewardedMember.account = rewardMember.account;
                rewardedMember.id = rewardMember.id;
                rewardedMember.balance += rewardFund;
                rewardedMember.totalIncome += rewardFund;
                rewardedMember.frontBalance + rewardFund;
            } else {
                // no qualifications, reward to platform c
                trashReward += rewardFund;
            }
        }

        return (rewardedMember, verify_count, trashReward);
    }


    function _rewardToBackThirtyPercent(uint256 memberId_, uint256 toStaticInvitation, uint256 backAmount) internal {
        if (memberId_ + 30 <= _memberId) {
            for (uint256 i = 1; i <= 30; i++) {
                uint256 rewardMemberId = memberId_ + i;
                _rewardToInvaitation(toStaticInvitation, rewardMemberId, memberId_, backAmount);
            }
        } else {
            uint256 _inviterId = memberId_; // avoid deep stack
            uint256 shouldRewardMember = _memberId - _inviterId;
            uint256 restEmptyMember = 30 - shouldRewardMember;
            uint256 rewardFund = toStaticInvitation.div(backAmount);
            uint256 totalFundToPlatformC = restEmptyMember * rewardFund;
            for (uint256 i = 1; i <= shouldRewardMember; i++) {
                uint256 rewardMemberId = _inviterId + i;

                _rewardToInvaitation(toStaticInvitation, rewardMemberId, _inviterId, backAmount);
            }

            if (totalFundToPlatformC != 0) {
                trashBalance += totalFundToPlatformC;
            }
        }
    }

    function _rewardToMarket(
        uint256 amount, 
        uint256 memberId,
        Member[] memory marketMembers, 
        uint256 trashReward,
        uint256 platformCReward
    ) internal view returns (
        Member[] memory rewardedMembers, 
        uint256, 
        uint256,
        uint256
    ) {
        Member[] memory marketMembers_ = marketMembers;
        uint256 trashReward_ = trashReward;
        uint256 platformCReward_ = platformCReward;
        uint256 amount_ = amount;
        uint256 memberId_ = memberId;
        uint256 invitaion_count;
        uint256 toMarket = amount_.mul(depositToMarket).div(100);
        uint256 toMarketLevel = toMarket.mul(marketToManager).div(1000); // 15% market level address
        uint256 toV4 = toMarket.mul(marketToAllV4).div(1000); // 2%

        // to invitaion
        (marketMembers_, trashReward_, platformCReward_, invitaion_count) = _rewardMarketToInvitation(
            memberId_, 
            amount_,
            marketMembers_,
            trashReward_,
            platformCReward_
        );

        // to market level
        (Member[] memory mMembers, uint256 mCount) = _getMarketLevelMember(memberId_);
        
        (marketMembers_, trashReward_) =  _rewardMarketToLevel(amount_, mCount, mMembers, invitaion_count, marketMembers_, trashReward_, toMarketLevel);

        // to market fouth level
        return (
            marketMembers_,
            trashReward_,
            platformCReward_,
            toV4
        );
    }

    function _rewardMarketToInvitation(
        uint256 memberId_, 
        uint256 toMarket,
        Member[] memory marketMembers_,
        uint256 platformCReward_,
        uint256 trashReward_
    ) internal view returns (
        Member[] memory,
        uint256,
        uint256,
        uint256
    ){
        uint256 toDirectAddress = toMarket.mul(marketToDirect).div(1000); // 20% directly invite
        uint256 toSecondLevelAddress = toMarket.mul(marketToInter).div(1000); // 10% second level invite
        uint256 inviterId = _relationship[memberId_];
        uint8 high = 1;
        uint8 invitaion_count = 0;
        while (high <= 2) {
            if (inviterId != 0) {
                Member memory member = _members[inviterId];
                uint256 rewardIncome = high == 1 ? toDirectAddress : toSecondLevelAddress;
                if (inviterId == 1) platformCReward_ += rewardIncome;
                else {
                    marketMembers_[invitaion_count].balance += rewardIncome;
                    marketMembers_[invitaion_count].totalIncome += rewardIncome;
                    marketMembers_[invitaion_count].dynamicBalance += rewardIncome;
                    invitaion_count++;
                }
            } else {
                trashReward_ += toSecondLevelAddress;
            }

            inviterId = _relationship[inviterId];
            high++;
        }
    }

    function _getMarketLevelMember(uint256 memberId_) internal view returns (Member[] memory, uint256) {
        uint256 inviterId_ = _relationship[memberId_];
        Member[] memory mMembers = new Member[](4);
        uint256 mCount = 0;
        
        // store the member of v1, v2, v3, v4
        while (inviterId_ != 0) {
            if (_members[inviterId_].marketLevel > 0) {
                if (_isExistMarketLevelMember(mMembers, _members[inviterId_].marketLevel)) {
                    inviterId_ = _relationship[inviterId_];
                } else {
                    mMembers[mCount] = _members[inviterId_];
                    mCount++;
                }
            }
            inviterId_ = _relationship[inviterId_];
        }

        return (mMembers, mCount);
    }

    function _rewardMarketToLevel(
        uint256 amount_,
        uint256 mCount,
        Member[] memory mMembers,
        uint256 invitaion_count,
        Member[] memory marketMembers_,
        uint256 trashReward,
        uint256 toMarketLevel
    ) internal view returns (
        Member[] memory,
        uint256
    ) {
        uint256 skipAmount = amount_;
        uint256 mToV1 = skipAmount.mul(marketToV1).div(10000); // 3% / 15%
        uint256 mToV2 = skipAmount.mul(marketToV2).div(10000); // 4% / 15%
        uint256 mToV3 = skipAmount.mul(marketToV3).div(10000); // 4% / 15%
        uint256 mToV4 = skipAmount.mul(marketToV4).div(10000); // 4% / 15%
        if (mCount != 0) {
            // pad empty index with 0
            Member[] memory newMembers = new Member[](4);
            for (uint256 i = 0; i < newMembers.length; i++) {
                for (uint256 j = 0; j < mCount; j++) {
                    if (mMembers[j].marketLevel == i + 1) {
                        newMembers[i] = mMembers[j];
                        break;
                    }
                }
            }

            // rewawrd to market v1 => v4
            // [v1, v2, v3, v4]  = [0, 2, 3, 0]
            uint256 accumulative = 0;
            uint256 market_count = invitaion_count;
            for (uint256 i = 0;  i < newMembers.length; i++) {
                if (newMembers[i].id == 0) {
                    if (i == 0) accumulative += mToV1;
                    else if (i == 1) accumulative += mToV2;
                    else if (i == 2) accumulative += mToV3;
                    else if (i == 3) accumulative += mToV4;
                } else {
                    if (i == 0) {
                        marketMembers_[market_count].balance += (accumulative.add(mToV1));
                        marketMembers_[market_count].totalIncome += (accumulative.add(mToV1));
                        marketMembers_[market_count].dynamicBalance += (accumulative.add(mToV1));
                    }
                    else if (i == 1) {
                        marketMembers_[market_count].balance += (accumulative.add(mToV2));
                        marketMembers_[market_count].totalIncome += (accumulative.add(mToV2));
                        marketMembers_[market_count].dynamicBalance += (accumulative.add(mToV2));
                    }
                    else if (i == 2) {
                        marketMembers_[market_count].balance += (accumulative.add(mToV3));
                        marketMembers_[market_count].totalIncome += (accumulative.add(mToV3));
                        marketMembers_[market_count].dynamicBalance += (accumulative.add(mToV3));
                    }
                    else if (i == 3) {
                        marketMembers_[market_count].balance += (accumulative.add(mToV4));
                        marketMembers_[market_count].totalIncome += (accumulative.add(mToV4));
                        marketMembers_[market_count].dynamicBalance += (accumulative.add(mToV4));
                    }
                    
                    console.log(" market level: ", i, newMembers[i].id, mToV1);
                    accumulative = 0;
                }
            }

            if (accumulative != 0 ) trashReward += accumulative;

        } else {
            trashReward += toMarketLevel;
        }
    }

    function _isExistMarketLevelMember(Member[] memory members, uint256 marketLevel) internal view returns (bool) {
        for (uint256 i = 0; i < members.length; i++) {
            Member memory itemMember = members[i];
            if (itemMember.marketLevel == marketLevel) return true;
        }

        return false;
    }

    function _rewardToInvaitation(
        uint256 amount,
        uint256 rewardMemberId,
        uint256 inviterId,
        uint256 backAmount
    ) internal {
        Member storage rewardMember = _members[rewardMemberId];
        Level memory level = _levels[rewardMember.level];
        uint256 rewardFund = amount.div(backAmount);

        if (inviterId + level.front >= rewardMemberId) {
            rewardMember.balance += rewardFund;
            rewardMember.backBalance += rewardFund;
            rewardMember.totalIncome += rewardFund;
        } else {
            trashBalance += rewardFund;
        }
    }

    function _canUpgrade(Member memory member) internal view returns (bool) {
        uint256[] memory invitaionMembers = _directInvitation[member.id]
            .values();
        // v0 => v1
        if (
            member.marketLevel == 0 &&
            invitaionMembers.length >= upgradeToV1Amount &&
            member.totalIncome >= upgradeToV1Income
        ) return true;
        // v1 => v2
        else if (
            member.marketLevel == 1 &&
            member.totalIncome >= upgradeToV2Income
        ) {
            uint256 count = _searchInvitationCountByMarketLevel(
                1,
                invitaionMembers
            );
            return count >= upgradeToV2Amount ? true : false;
        }
        // v2 => v3
        else if (member.marketLevel == 2 && member.totalIncome >= upgradeToV3Income) {
            uint256 count = _searchInvitationCountByMarketLevel(
                2,
                invitaionMembers
            );
            return count >= upgradeToV3Amount ? true : false;
        }
        // v3 => v4
        else if (member.marketLevel == 3 && member.totalIncome >= upgradeToV4Income) {
            uint256 count = _searchInvitationCountByMarketLevel(
                3,
                invitaionMembers
            );
            return count >= upgradeToV4Amount ? true : false;
        } 
        else return false;
    }

    function _searchInvitationCountByMarketLevel(
        uint8 marketLevel,
        uint256[] memory invitaionMembers
    ) internal view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < invitaionMembers.length; i++) {
            Member memory invitaionMember = _members[invitaionMembers[i]];
            if (invitaionMember.marketLevel == marketLevel) count++;
        }

        return count;
    }


    function _canWithDraw(uint256 memberId, uint256 amount) internal view returns (bool) {
        Member memory member = _members[memberId];
        return member.account != address(0) &&
            member.account == _msgSender() &&
            member.balance > 0 &&
            member.balance >= amount &&
            amount >= withdrawThreshold;
    }

    function _addMember(address account, uint8 level, uint8 marketLevel, uint256 amount) internal {
        Member storage member = _members[_memberId];
        member.id = _memberId;
        member.account = account;
        member.level = level;
        member.lastDepositTime = block.timestamp;
        member.totalDeposit += amount;
        member.marketLevel = marketLevel;
        memberIdOf[account] = _memberId;

        _memberId++;
    }

    function _upgradeLevel(uint256 memberId) internal {
        Member storage member = _members[memberId];
        if (member.totalDeposit >= _levels[_levelId].value){
            member.level = _levelId;
        } else
            for (uint8 i = 1; i < _levelId; i++) {
                if (member.totalDeposit >= _levels[i].value &&
                    member.totalDeposit < _levels[i + 1].value) {
                        member.level = i;
                    }
            }
    }
}
