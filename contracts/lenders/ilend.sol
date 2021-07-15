// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "../vaultHelpers.sol";

abstract contract ILend {
    /// Lend and Borrow wrapper for cream 
    using SafeMath for uint256;
    function borrowPlatform() public view virtual returns (address);
    function lendPlatform() public view virtual returns (address);
    function comptrollerAddress() public view virtual returns (address);
    
    /*
    * Borrow Methods
    */
    function borrow(uint256 _borrowAmount) internal virtual returns (uint256);
    function borrowBalanceStored(address _account) internal view virtual returns (uint);
    function borrowRepay(uint _repayAmount) internal virtual;

    /*
    * Lend Methods
    */
    function lendMint(uint256 _mintAmount) internal virtual;
    function lendRedeem(uint _redeemTokens) internal virtual;
    function lendRedeemUnderlying(uint _redeemAmount) internal virtual;
    function lendBalanceOf(address _owner) internal view virtual returns (uint256);
    function lendExchangeRateCurrent() internal view virtual returns (uint256);
    function lendExchangeRateStored() internal view virtual returns (uint);
    function lendGetCash() internal view virtual returns (uint);
    function lendBalanceOfUnderlying(address _addr) internal view virtual returns (uint256);
}

        