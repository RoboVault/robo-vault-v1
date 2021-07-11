pragma solidity ^0.5.0;
import "../vaultHelpers.sol";

contract ILend {
    /// Lend and Borrow wrapper for cream 
    using SafeMath for uint256;
    address public BorrowPlatform;
    address public LendPlatform;

    function enterMarkets() external;
    
    /*
    * Borrow Methods
    */
    function borrow(uint256 _borrowAmount) external returns (uint256);
    function borrowBalanceStored(address _account) external view returns (uint);
    function repayBorrow(uint _repayAmount) external;

    /*
    * Lend Methods
    */
    function mint(uint256 _mintAmount) external;
    function redeem(uint _redeemTokens) external;
    function redeemUnderlying(uint _redeemAmount) external;
    function balanceOf(address _owner) external view returns (uint256);
    function exchangeRateCurrent() external view returns (uint256);
    function exchangeRateStored() external view returns (uint);
    function getCash() external view returns (uint);
    function balanceOfUnderlying(address _addr) external view returns (uint256);
}

        