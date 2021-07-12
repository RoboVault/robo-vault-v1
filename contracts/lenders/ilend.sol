pragma solidity ^0.5.0;
import "../vaultHelpers.sol";

contract ILend {
    /// Lend and Borrow wrapper for cream 
    using SafeMath for uint256;
    function borrowPlatform() public view returns (address);
    function lendPlatform() public view returns (address);
    function comptrollerAddress() public view returns (address);
    
    /*
    * Borrow Methods
    */
    function borrow(uint256 _borrowAmount) internal returns (uint256);
    function borrowBalanceStored(address _account) internal view returns (uint);
    function borrowRepay(uint _repayAmount) internal;

    /*
    * Lend Methods
    */
    function lendMint(uint256 _mintAmount) internal;
    function lendRedeem(uint _redeemTokens) internal;
    function lendRedeemUnderlying(uint _redeemAmount) internal;
    function lendBalanceOf(address _owner) internal view returns (uint256);
    function lendExchangeRateCurrent() internal view returns (uint256);
    function lendExchangeRateStored() internal view returns (uint);
    function lendGetCash() internal view returns (uint);
    function lendBalanceOfUnderlying(address _addr) internal view returns (uint256);
}

        