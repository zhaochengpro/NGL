pragma solidity ^0.8.4;

library NGLStruct {
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
}
