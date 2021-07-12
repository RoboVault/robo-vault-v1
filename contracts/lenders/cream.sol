// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "../vaultHelpers.sol";
import "./ilend.sol";

interface BORROW {
    /// interface for borrowing from CREAM
    function borrow(uint256 borrowAmount) external returns (uint256); 
    function borrowBalanceStored(address account) external view returns (uint);
    function repayBorrow(uint repayAmount) external; /// borrowAmount: The amount of the underlying borrowed asset to be repaid. A value of -1 (i.e. 2^256 - 1) can be used to repay the full amount.
}

interface LEND {
    /// interface for depositing into CREAM
    function mint(uint256 mintAmount) external; 
    function redeem(uint redeemTokens) external; 
    function redeemUnderlying(uint redeemAmount) external; 
    function balanceOf(address owner) external view returns (uint256); 
    function exchangeRateCurrent() external view returns (uint256);
    function exchangeRateStored() external view returns (uint);
    function getCash() external view returns (uint);
    function balanceOfUnderlying(address) external view returns (uint256);
}


abstract contract Cream is ILend {
    /// Lend and Borrow wrapper for cream 
    using SafeMath for uint256;

    function borrowPlatform() public view override returns (address) {
        return 0xd528697008aC67A21818751A5e3c58C8daE54696;
    }
    function lendPlatform() public view override returns (address) {
        return 0x328A7b4d538A2b3942653a9983fdA3C12c571141;
    }
    function comptrollerAddress() public view override returns (address) {
        return 0x4250A6D3BD57455d7C6821eECb6206F507576cD2;
    }
    
    /*
    * Borrow Methods
    */
    function borrow(uint256 _borrowAmount) internal override returns (uint256) {
        return BORROW(borrowPlatform()).borrow(_borrowAmount);
    } 
    function borrowBalanceStored(address _account) internal view override returns (uint) {
        return BORROW(borrowPlatform()).borrowBalanceStored(_account);
    }
    function borrowRepay(uint _repayAmount) internal override {
        BORROW(borrowPlatform()).repayBorrow(_repayAmount);
    }

    /*
    * Lend Methods
    */
    function lendMint(uint256 _mintAmount) internal override {
        LEND(lendPlatform()).mint(_mintAmount);
    }
    function lendRedeem(uint _redeemTokens) internal override {
        LEND(lendPlatform()).redeem(_redeemTokens);
    }
    function lendRedeemUnderlying(uint _redeemAmount) internal override {
        LEND(lendPlatform()).redeemUnderlying(_redeemAmount);
    }
    function lendBalanceOf(address _owner) internal view override returns (uint256) {
        return LEND(lendPlatform()).balanceOf(_owner);
    }
    function lendExchangeRateCurrent() internal view override returns (uint256) {
        return LEND(lendPlatform()).exchangeRateCurrent();
    }
    function lendExchangeRateStored() internal view override returns (uint) {
        return LEND(lendPlatform()).exchangeRateStored();
    }
    function lendGetCash() internal view override returns (uint) {
        return LEND(lendPlatform()).getCash();
    }
    function lendBalanceOfUnderlying(address _addr) internal view override returns (uint256) {
        return LEND(lendPlatform()).balanceOfUnderlying(_addr);
    }
}

        