// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./INGLStorage.sol";

library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }


    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }
}

contract NGL {
    using SafeMath for uint256;

    // ======================================== EVENT ========================================
    // event Deposit(uint256 indexed memberId, address indexed account, uint256 indexed inviterId, uint256 amount);
    // event Redeposit(uint256 indexed memberId, address indexed account, uint256 amount);
    // event Upgrade(uint256 indexed memberId, uint8 oldLevel, uint8 newLevel);
    // event WithDraw(uint256 indexed memberId, uint256 balance, uint256 reward);
    // event RewardV4(uint256 amount, uint256 time);


    address public manager;
    INGLStorage public nglStorage;

    constructor(
        address _storageContract
    ) { 
        nglStorage = INGLStorage(_storageContract);
        manager = _msgSender();
    }

    modifier onlyManager() {
        require(manager == _msgSender(), "invalid role");
        _;
    }

    // ======================================== EXTERNAL FUNCTION ========================================

    function deposit(uint256 amount, uint256 inviterId) external payable {
        require(amount == msg.value, "Not enough value");
        require(_isValidLevel(amount), "Please deposit specifical amount");
        address account = _msgSender();
        require(!nglStorage.getIsDeposit(account), "Already deposit");
        require(_isValidInviter(inviterId), "Invalid inviter");
        nglStorage.setIsDeposit(account, true);

        // update relationship
        uint256 _memberId = nglStorage.getMemberId();
        nglStorage.setRelationship(_memberId, inviterId);
        nglStorage.setDirectInvitation(inviterId, _memberId);

        // deposit
        _deposit(amount, _memberId, inviterId);

        // add member
        _addMember(account, nglStorage.getAmountToLevel(amount), 0, amount);
        // emit Deposit(_memberId, account, inviterId, amount);
    }

    function upgrade(uint256 memberId) external {
        require(nglStorage.isInitalize(), "Not initalize");
        NGLStruct.Member memory member = nglStorage.getMembers(memberId);
        uint8 oldLevel = member.level;
        require(_msgSender() == member.account || manager == _msgSender(), "not the owner of this member account");
        require(_canUpgrade(member), "not qualification to upgrade");

        if (member.marketLevel == 0) {
            member.marketLevel = 1;
            nglStorage.setMarketLevelOneToMember(member.id);
        } else if (member.marketLevel == 1) {
            member.marketLevel = 2;
            nglStorage.setMarketLevelTwoToMember(member.id);
        } else if (member.marketLevel == 2) {
            member.marketLevel = 3;
            nglStorage.setMarketLevelThreeToMember(member.id);
        } else if (member.marketLevel == 3) {
            member.marketLevel = 4;
            nglStorage.setMarketLevelFourToMember(member.id);
        }

        nglStorage.setMembers(memberId, member);

        // emit Upgrade(memberId, oldLevel, member.marketLevel);
    }

    function withDraw(uint256 memberId, uint256 amount) external {
        require(_canWithDraw(memberId, amount), "invalid withdraw");
        NGLStruct.Member memory member = nglStorage.getMembers(memberId);
        uint256 totalBalanceOfMember = amount;
        member.balance -= amount;
        member.totalWithdraw += amount;
        nglStorage.setMembers(memberId, member);
        uint256 withDrawToFrontAndBack = totalBalanceOfMember.mul(nglStorage.withdrawToFrontAndBack()).div(100); // withdraw to front and back
        uint256 withDrawToSelf = totalBalanceOfMember.mul(nglStorage.withdrawToSelf()).div(100); // withdraw to self

        // to front 70
        _rewardToFrontSeventyPercent(memberId, withDrawToFrontAndBack, 100);
        // to back 30
        _rewardToBackThirtyPercent(memberId, withDrawToFrontAndBack, 100);
        // to self
        payable(_msgSender()).transfer(withDrawToSelf);

        // emit WithDraw(memberId, totalBalanceOfMember, withDrawToSelf);
    }

    function withdrawPlatformA() external {
        address platformA = nglStorage.platformA();
        uint256 platformABalance = nglStorage.platformABalance();
        require(_msgSender() == platformA, "Not platformA");
        require(platformABalance > 0);
        payable(platformA).transfer(platformABalance);
        nglStorage.setPlatformABalance(0);
    }
    
    function withdrawPlatformB() external {
        address platformB = nglStorage.platformB();
        uint256 platformBBalance = nglStorage.platformBBalance();
        require(_msgSender() == platformB, "Not platformB");
        require(platformBBalance > 0);
        payable(platformB).transfer(platformBBalance);
        nglStorage.setPlatformBBalance(0);
    }

    function withdrawPlatformC() external {
        address platformC = nglStorage.platformC();
        uint256 platformCBalance = nglStorage.platformCBalance();
        require(_msgSender() == platformC, "Not platformC");
        require(platformCBalance > 0);
        payable(platformC).transfer(platformCBalance);
        nglStorage.setPlatformCBalance(0);
    }

    function withdrawTrash() external {
        address trashAddress = nglStorage.trashAddress();
        uint256 trashBalance = nglStorage.trashBalance();
        require(_msgSender() == trashAddress, "Not trashAddress");
        require(trashBalance > 0);
        payable(trashAddress).transfer(trashBalance);
        nglStorage.setTrashBalance(0);
    }

    function emencyWithDraw(address account) external onlyManager {
        require(address(this).balance > 0);
        payable(account).transfer(address(this).balance);
    }

    function rewardV4() external {
        require(manager == _msgSender(), "Not Manager Role Or Bot Role");
        uint256[] memory levelFour = nglStorage.getMarketLevelFourToMember();
        require(levelFour.length > 0, "Not have four");
        uint256 value = nglStorage.v4balance().div(
            levelFour.length
        );

        for (uint256 i = 0; i < levelFour.length; i++) {
            uint256 mLevelFourMemberId = levelFour[i];
            NGLStruct.Member memory member = nglStorage.getMembers(mLevelFourMemberId);
            member.balance += value;
            member.dynamicBalance += value;
            nglStorage.setMembers(mLevelFourMemberId, member);
        }

        nglStorage.setV4balance(0);

        // emit RewardV4(value, block.timestamp);
    }

    function canUpgrade(uint256 memberId) external view returns (bool) {
        NGLStruct.Member memory member = nglStorage.getMembers(memberId);
        return _canUpgrade(member);
    }

    function addLevel(
        uint248 _up,
        uint256 _down,
        uint256 _value
    ) public onlyManager {
        nglStorage.addLevelId();
        uint8 levelId = nglStorage.getLevelId();
        nglStorage.setLevel(levelId, NGLStruct.Level(levelId, _up, _down, _value));
        nglStorage.setAmountToLevel(_value, levelId);
    }

    function updateLevel(
    	uint8 _levelId,
        uint256 _value
    ) public onlyManager {
        NGLStruct.Level memory level = nglStorage.getLevel(_levelId);
        level.value = _value;
        nglStorage.setLevel(_levelId, level);
        nglStorage.setAmountToLevel(_value, _levelId);
    }

    function setMarketLevel(uint256 _memberId, uint8 _marketLevel) external onlyManager {
        NGLStruct.Member memory member = nglStorage.getMembers(_memberId);
        member.marketLevel = _marketLevel;
        if (_marketLevel == 1) {
            nglStorage.setMarketLevelOneToMember(_memberId);
        } else if (_marketLevel == 2) {
            nglStorage.setMarketLevelTwoToMember(_memberId);
        } else if (_marketLevel == 3) {
            nglStorage.setMarketLevelThreeToMember(_memberId);
        } else if (_marketLevel == 4) {
            nglStorage.setMarketLevelFourToMember(_memberId);
        }

        nglStorage.setMembers(_memberId, member);
    }

    function transferTo(address account, uint256 amount) external {
        require( _msgSender() == nglStorage.trashAddress() || _msgSender() == manager, "invalid role");
        require(nglStorage.trashBalance() > amount, "Not enough");
        nglStorage.setTrashBalance(nglStorage.trashBalance() - amount);
        uint256 memberId = nglStorage.memberIdOf(account);
        NGLStruct.Member memory member = nglStorage.getMembers(memberId);
        member.dynamicBalance += amount;
   //     member.balance += amount;
        nglStorage.setMembers(member.id, member);
    }

    // ================================ VIEW FUNCTION ================================

    function inviterId(uint256 memberId) external view returns (uint256) {
        return nglStorage.getRelationship(memberId);
    }

    function memberOf(uint256 memberId) external view returns (
        NGLStruct.Member memory
    ) {
        return nglStorage.getMembers(memberId);
    }

    function setManager(address manager_) external onlyManager {
        manager = manager_;
    }

    // ======================================== INTERNAL FUNCTION ========================================

    function _isValidLevel(uint256 amount) internal view returns (bool) {
        uint256 levelId = nglStorage.getAmountToLevel(amount);
        if (levelId == 0) return false;
        else return true;
    }

    function _isValidInviter(uint256 inviterId)
        internal
        view
        returns (bool)
    {
        NGLStruct.Member memory inviter = nglStorage.getMembers(inviterId);
        return inviter.account != address(0) && 
            inviter.id < nglStorage.getMemberId() && 
            (inviter.account == nglStorage.platformC() || inviter.marketLevel >= 0);
    }

    function _deposit(
        uint256 amount,
        uint256 memberId,
        uint256 inviterId
    ) internal {
        // to platform
        _rewardToPlatfrom(amount);
        // to static
        _rewardToStatic(amount, memberId, inviterId);
        // to market
        _rewardToMarket(amount, memberId);
    }

    function _rewardToPlatfrom(uint256 amount) internal {
        uint256 toPlatform = amount.mul(nglStorage.depositToPlatform()).div(100);
        uint256 toPlatformA = toPlatform.mul(nglStorage.platformToA()).div(nglStorage.depositToPlatform() * 10);
        nglStorage.setPlatformABalance(nglStorage.platformABalance() + toPlatformA);
        uint256 toPlatformB = toPlatform.mul(nglStorage.platformToB()).div(nglStorage.depositToPlatform() * 10);
        nglStorage.setPlatformBBalance(nglStorage.platformBBalance() + toPlatformB);
        uint256 toPlatformC = toPlatform.mul(nglStorage.platformToC()).div(nglStorage.depositToPlatform() * 10);
        nglStorage.setPlatformCBalance(nglStorage.platformCBalance() + toPlatformC);
    }

    function _rewardToStatic(uint256 amount, uint256 memberId, uint256 inviterId) internal {
 
        // to static
        uint256 depositToStatic = nglStorage.depositToStatic();
        uint256 staticToFrontSeventy = nglStorage.staticToFrontSeventy();
        uint256 staticToSelf = nglStorage.staticToSelf();

        uint256 toStatic = amount.mul(depositToStatic).div(100);
        // 100% static => 70% to 70 front;
        uint256 toStaticFront = toStatic.mul(staticToFrontSeventy).div(depositToStatic);
        // maybe 100% static => 30% to self
        uint256 toStaticSelf = toStatic.mul(staticToSelf).div(depositToStatic);
        // to the 70 front members with the 70% static fund
        _rewardToFrontSeventyPercent(memberId, toStaticFront, 70);

        // reward to self when the _isStaticToSelf be setted true
        NGLStruct.Member memory member = nglStorage.getMembers(memberId);
        member.balance += toStaticSelf;
        member.backBalance += toStaticSelf;
        member.totalIncome += toStaticSelf;
        nglStorage.setMembers(memberId, member);
    }

    function _rewardToFrontSeventyPercent(uint256 memberId, uint256 toStaticFront, uint256 frontAmount) internal {
        // have member in the range of front 70
        if (memberId >= 72) {
            for (uint256 i = 2; i <= 71; i++) {
                uint256 rewardMemberid = memberId - (i - 1);
                _rewardToStaticFront(toStaticFront, rewardMemberid, frontAmount);
            }
        } else {
            uint256 restEmptyMember = 72 - memberId;
            uint256 rewardFund = toStaticFront.div(frontAmount);
            uint256 totalFundToPlatformC = restEmptyMember * rewardFund;
            for (uint256 i = 2; i <= memberId - 1; i++) {
                uint256 rewardMemberId = memberId - (i - 1);
                _rewardToStaticFront(toStaticFront, rewardMemberId, frontAmount);
            }

            if (totalFundToPlatformC != 0) {
                nglStorage.setTrashBalance(nglStorage.trashBalance() + totalFundToPlatformC);
            }
        }
    }

    function _rewardToBackThirtyPercent(uint256 memberId_, uint256 toStaticInvitation, uint256 backAmount) internal {
        uint256 _memberId = nglStorage.getMemberId();
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
                nglStorage.setTrashBalance(nglStorage.trashBalance() + totalFundToPlatformC);
            }
        }
    }

    function _rewardToMarket(uint256 amount, uint256 memberId) internal {

        uint256 depositToMarket = nglStorage.depositToMarket();
        uint256 marketToDirect = nglStorage.marketToDirect();
        uint256 marketToInter = nglStorage.marketToInter();
        uint256 marketToManager = nglStorage.marketToManager();
        uint256 marketToAllV4 = nglStorage.marketToAllV4();
        uint256 toMarket = amount.mul(depositToMarket).div(100);
        uint256 inviterId = nglStorage.getRelationship(memberId);
        uint256 toDirectAddress = toMarket.mul(marketToDirect).div(depositToMarket); // 20% directly invite
        uint256 toSecondLevelAddress = toMarket.mul(marketToInter).div(depositToMarket); // 10% second level invite
        uint256 toMarketLevel = toMarket.mul(marketToManager).div(depositToMarket); // 15% market level address
        uint256 toV4 = toMarket.mul(marketToAllV4).div(depositToMarket); // 2%
        uint8 high = 1;
        // to direcly invitation and second invitation
        while (high <= 2) {
            if (inviterId != 0) {
                NGLStruct.Member memory member = nglStorage.getMembers(inviterId);
                uint256 rewardIncome = high == 1 ? toDirectAddress : toSecondLevelAddress;
                if (inviterId == 1) nglStorage.setPlatformCBalance(nglStorage.platformCBalance() + rewardIncome);
                else {
                    member.balance += rewardIncome;
                    member.totalIncome += rewardIncome;
                    member.dynamicBalance += rewardIncome;
                }
                nglStorage.setMembers(inviterId, member);
            } else {
                nglStorage.setTrashBalance(nglStorage.trashBalance() + toSecondLevelAddress);
            }

            inviterId = nglStorage.getRelationship(inviterId);
            high++;
        }
        {
        uint256 amount_ = amount;
        uint256 memberId_ = memberId;
        // to market level
        uint256 mToV1 = amount_.mul(nglStorage.marketToV1()).div(100); // 3% / 15%
        uint256 mToV2 = amount_.mul(nglStorage.marketToV2()).div(100); // 4% / 15%
        uint256 mToV3 = amount_.mul(nglStorage.marketToV3()).div(100); // 4% / 15%
        uint256 mToV4 = amount_.mul(nglStorage.marketToV4()).div(100); // 4% / 15%
        
        uint256 inviterId_ = nglStorage.getRelationship(memberId_);
        NGLStruct.Member[] memory mMembers = new NGLStruct.Member[](4);
        uint256 mCount = 0;
        
        // store the member of v1, v2, v3, v4
         while (inviterId_ != 0) {
            NGLStruct.Member memory member = nglStorage.getMembers(inviterId_);
            if (
                member.marketLevel > 0 && 
                member.marketLevel > mMembers[mCount == 0 ? 0 : mCount - 1].marketLevel &&
                mCount < 4
            ) {
                    mMembers[mCount] = member;
                    mCount++;
            }
            inviterId_ = nglStorage.getRelationship(inviterId_);
        }
        
        if (mCount != 0) {
            // pad empty index with 0
            NGLStruct.Member[] memory newMembers = new NGLStruct.Member[](4);
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

            for (uint256 i = 0;  i < newMembers.length; i++) {
                NGLStruct.Member memory rewardMember = nglStorage.getMembers(newMembers[i].id);
                if (newMembers[i].id == 0) {
                    if (i == 0) accumulative += mToV1;
                    else if (i == 1) accumulative += mToV2;
                    else if (i == 2) accumulative += mToV3;
                    else if (i == 3) accumulative += mToV4;
                } else {
                    if (i == 0) {
                        rewardMember.balance += (accumulative.add(mToV1));
                        rewardMember.totalIncome += (accumulative.add(mToV1));
                        rewardMember.dynamicBalance += (accumulative.add(mToV1));
                    }
                    else if (i == 1) {
                        rewardMember.balance += (accumulative.add(mToV2));
                        rewardMember.totalIncome += (accumulative.add(mToV2));
                        rewardMember.dynamicBalance += (accumulative.add(mToV2));
                    }
                    else if (i == 2) {
                        rewardMember.balance += (accumulative.add(mToV3));
                        rewardMember.totalIncome += (accumulative.add(mToV3));
                        rewardMember.dynamicBalance += (accumulative.add(mToV3));
                    }
                    else if (i == 3) {
                        rewardMember.balance += (accumulative.add(mToV4));
                        rewardMember.totalIncome += (accumulative.add(mToV4));
                        rewardMember.dynamicBalance += (accumulative.add(mToV4));
                    }
                    
                    accumulative = 0;
                }
                nglStorage.setMembers(newMembers[i].id, rewardMember);

            }

            if (accumulative != 0 ) nglStorage.setTrashBalance(nglStorage.trashBalance().add(accumulative));

        } else {
            nglStorage.setTrashBalance(nglStorage.trashBalance().add(toMarketLevel));
        }

        // to market fouth level
        nglStorage.setV4balance(nglStorage.v4balance().add(toV4));
        }
    }

    function _isExistMarketLevelMember(NGLStruct.Member[] memory members, uint256 marketLevel) internal returns (bool) {
        for (uint256 i = 0; i < members.length; i++) {
            NGLStruct.Member memory itemMember = members[i];
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
        NGLStruct.Member memory rewardMember = nglStorage.getMembers(rewardMemberId);
        NGLStruct.Level memory level = nglStorage.getLevel(rewardMember.level);
        uint256 rewardFund = amount.div(backAmount);

        if (inviterId + level.front >= rewardMemberId) {
            rewardMember.balance += rewardFund;
            rewardMember.backBalance += rewardFund;
            rewardMember.totalIncome += rewardFund;

            nglStorage.setMembers(rewardMemberId, rewardMember);
        } else {
            nglStorage.setTrashBalance(nglStorage.trashBalance() + rewardFund);
        }
    }

    function _rewardToStaticFront(uint256 amount, uint256 rewardMemberId, uint256 frontAmount) internal {
        NGLStruct.Member memory rewardMember = nglStorage.getMembers(rewardMemberId);
        NGLStruct.Level memory memberLevel = nglStorage.getLevel(rewardMember.level);
        uint256 rewardFund = amount.div(frontAmount);
        if (memberLevel.back >= 70) {
            // the 34 member in front of current member can both reward the fund
            rewardMember.balance += rewardFund;
            rewardMember.totalIncome += rewardFund;
            rewardMember.frontBalance += rewardFund;
        }

        nglStorage.setMembers(rewardMemberId, rewardMember);
    }

    function _canUpgrade(NGLStruct.Member memory member) internal view returns (bool) {
        uint256[] memory invitaionMembers = nglStorage.getDirectInvitation(member.id);
        // v0 => v1
        if (
            member.marketLevel == 0 &&
            invitaionMembers.length >= nglStorage.upgradeToV1Amount() &&
            member.totalIncome >= nglStorage.upgradeToV1Income()
        ) return true;
        // v1 => v2
        else if (
            member.marketLevel == 1 &&
            member.totalIncome >= nglStorage.upgradeToV2Income()
        ) {
            uint256 count = _searchInvitationCountByMarketLevel(
                1,
                invitaionMembers
            );
            return count >= nglStorage.upgradeToV2Amount() ? true : false;
        }
        // v2 => v3
        else if (member.marketLevel == 2 && member.totalIncome >= nglStorage.upgradeToV3Income()) {
            uint256 count = _searchInvitationCountByMarketLevel(
                2,
                invitaionMembers
            );
            return count >= nglStorage.upgradeToV3Amount() ? true : false;
        }
        // v3 => v4
        else if (member.marketLevel == 3 && member.totalIncome >= nglStorage.upgradeToV4Income()) {
            uint256 count = _searchInvitationCountByMarketLevel(
                3,
                invitaionMembers
            );
            return count >= nglStorage.upgradeToV4Amount() ? true : false;
        } 
        else return false;
    }

    function _searchInvitationCountByMarketLevel(
        uint8 marketLevel,
        uint256[] memory invitaionMembers
    ) internal view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < invitaionMembers.length; i++) {
            NGLStruct.Member memory invitaionMember = nglStorage.getMembers(invitaionMembers[i]);
            if (invitaionMember.marketLevel == marketLevel) count++;
        }

        return count;
    }


    function _canWithDraw(uint256 memberId, uint256 amount) internal view returns (bool) {
        NGLStruct.Member memory member = nglStorage.getMembers(memberId);
        return member.account != address(0) &&
            member.account == _msgSender() &&
            member.balance > 0 &&
            member.balance >= amount &&
            amount >= nglStorage.withdrawThreshold();
    }

    function _addMember(address account, uint8 level, uint8 marketLevel, uint256 amount) internal {
        uint256 _memberId = nglStorage.getMemberId();
        NGLStruct.Member memory member = nglStorage.getMembers(_memberId);
        member.id = _memberId;
        member.account = account;
        member.level = level;
        member.lastDepositTime = block.timestamp;
        member.totalDeposit += amount;
        member.marketLevel = marketLevel;
        nglStorage.setMemberIdOf(account, _memberId);

        nglStorage.setMembers(_memberId, member);
        nglStorage.addMemberId();
    }

    function _upgradeLevel(uint256 memberId) internal {
        NGLStruct.Member memory member = nglStorage.getMembers(memberId);
        uint8 _levelId = nglStorage.getLevelId();
        NGLStruct.Level memory level = nglStorage.getLevel(_levelId);
        if (member.totalDeposit >= level.value){
            member.level = _levelId;
        } else
            for (uint8 i = 1; i < _levelId; i++) {
                if (member.totalDeposit >= nglStorage.getLevel(i).value &&
                    member.totalDeposit < nglStorage.getLevel(i + 1).value) {
                        member.level = i;
                    }
            }
        
        nglStorage.setMembers(memberId, member);
    }

    function _msgSender() internal view returns (address) {
        return msg.sender;
    }

    receive() external payable{}
}
