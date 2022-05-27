pragma solidity ^0.8.4;

import "./NGLStruct.sol";
interface INGLStorage {
    function withdrawThreshold() external view returns (uint256);
    function upgradeToV1Amount() external view returns (uint256);
    function upgradeToV1Income() external view returns (uint256);
    function upgradeToV2Income() external view returns (uint256);
    function upgradeToV2Amount() external view returns (uint256);
    function upgradeToV3Amount() external view returns (uint256);
    function upgradeToV4Amount() external view returns (uint256);
    function upgradeToV3Income() external view returns (uint256);
    function upgradeToV4Income() external view returns (uint256);
    function marketToAllV4() external view returns (uint256);
    function marketToV1() external view returns (uint256);
    function marketToV2() external view returns (uint256);
    function marketToV3() external view returns (uint256);
    function marketToV4() external view returns (uint256);
    function marketToDirect() external view returns (uint256);
    function marketToInter() external view returns (uint256);
    function marketToManager() external view returns (uint256);
    function depositToMarket() external view returns (uint256);
    function depositToPlatform() external view returns (uint256);
    function staticToFrontSeventy() external view returns (uint256);
    function staticToSelf() external view returns (uint256);
    function depositToStatic() external view returns (uint256);
    function platformA() external view returns (address);    
    function platformB() external view returns (address);
    function platformC() external view returns (address);
    function trashAddress() external view returns (address);
    function platformABalance() external view returns (uint256);
    function platformToA() external view returns (uint256);
    function platformToB() external view returns (uint256);
    function platformToC() external view returns (uint256);
    function v4balance() external view returns (uint256);
    function platformBBalance() external view returns (uint256);
    function platformCBalance() external view returns (uint256);
    function trashBalance() external view returns (uint256);
    function withdrawToSelf() external view returns (uint256);
    function withdrawToFrontAndBack() external view returns (uint256);
    function isInitalize() external view returns (bool);
    function logicContract(address logicAddress_) external;
    function setMemberId(uint256 memberId) external;
    function getMemberId() external view returns (uint256);
    function setWithdrawThreshold(uint256 withdrawThreshold_) external;
    function addMemberId() external;
    function setMemberIdOf(address account, uint256 memberId) external;
    function setV4balance(uint256 amount) external;
    function setPlatformA(address account) external;
    function setPlatformABalance(uint256 amount) external;
    function setPlatformB(address account) external;
    function setPlatformBBalance(uint256 amount) external;
    function setPlatformC(address account) external;
    function setPlatformCBalance(uint256 amount) external;
    function setTrashAddress(address account) external;
    function setTrashBalance(uint256 amount) external;
    function setIsInitalize(bool isInitalize_) external;
    function setIsDeposit(address account, bool isDeposit_) external;
    function getIsDeposit(address account) external view returns (bool);
    function setMembers(uint256 memberId, NGLStruct.Member memory member) external;
    function getMembers(uint256 memberId) external view returns (NGLStruct.Member memory);
    function setLevel(uint8 levelId, NGLStruct.Level memory level) external;
    function getLevel(uint8 levelId) external view returns (NGLStruct.Level memory);
    function setLevelId(uint8 levelId) external;
    function addLevelId() external;
    function getLevelId() external view returns (uint8);
    function setAmountToLevel(uint256 amount, uint8 levelId) external;
    function getAmountToLevel(uint256 amount) external view returns (uint8);
    function setRelationship(uint256 memberId, uint256 inviterId) external;
    function getRelationship(uint256 memberId) external view returns (uint256);
    function setDirectInvitation(uint256 inviterId, uint256 memberId) external;
    function getDirectInvitation(uint256 inviterId) external view returns (uint256[] memory);
    function setMarketLevelOneToMember(uint256 memberId) external;
    function getMarketLevelOneToMember() external view returns (uint256[] memory);
    function setMarketLevelTwoToMember(uint256 memberId) external;
    function getMarketLevelTwoToMember() external view returns (uint256[] memory);
    function setMarketLevelThreeToMember(uint256 memberId) external;
    function getMarketLevelThreeToMember() external view returns (uint256[] memory);
    function setMarketLevelFourToMember(uint256 memberId) external;
    function getMarketLevelFourToMember() external view returns (uint256[] memory);
    function setUpgradeMarketLevel(
        uint256 _upgradeToV1Amount,
        uint256 _upgradeToV1Income,
        uint256 _upgradeToV2Amount,
        uint256 _upgradeToV2Income,
        uint256 _upgradeToV3Income,
        uint256 _upgradeToV3Amount,
        uint256 _upgradeToV4Income,
        uint256 _upgradeToV4Amount
    ) external;
}