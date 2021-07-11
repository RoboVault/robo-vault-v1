pragma solidity ^0.5.0;
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
    function balanceOfUnderlying(address addr) external view returns (uint256);
}

interface Icomptroller {
  function enterMarkets(address[] calldata cTokens) external returns (uint[] memory);
}

contract Cream is ILend {
    /// Lend and Borrow wrapper for cream 
    using SafeMath for uint256;
    address public constant BorrowPlatform = 0xd528697008aC67A21818751A5e3c58C8daE54696;
    address public constant LendPlatform = 0x328A7b4d538A2b3942653a9983fdA3C12c571141; 
    address public constant ComptrollerAddress = 0x4250A6D3BD57455d7C6821eECb6206F507576cD2; /// Cream Comptroller 

    function enterMarkets() external {
        Icomptroller comptroller = Icomptroller(ComptrollerAddress);
        address[] memory cTokens = new address[](1);
        cTokens[0] = LendPlatform;
        comptroller.enterMarkets(cTokens);
    }
    
    /*
    * Borrow Methods
    */
    function borrow(uint256 _borrowAmount) external returns (uint256) {
        return BORROW(BorrowPlatform).borrow(_borrowAmount);
    } 
    function borrowBalanceStored(address _account) external view returns (uint) {
        return BORROW(BorrowPlatform).borrowBalanceStored(_account);
    }
    function repayBorrow(uint _repayAmount) external {
        BORROW(BorrowPlatform).repayBorrow(_repayAmount);
    }

    /*
    * Lend Methods
    */
    function mint(uint256 _mintAmount) external {
        LEND(LendPlatform).mint(_mintAmount);
    }
    function redeem(uint _redeemTokens) external {
        LEND(LendPlatform).redeem(_redeemTokens);
    }
    function redeemUnderlying(uint _redeemAmount) external {
        LEND(LendPlatform).redeemUnderlying(_redeemAmount);
    }
    function balanceOf(address _owner) external view returns (uint256) {
        return LEND(LendPlatform).balanceOf(_owner);
    }
    function exchangeRateCurrent() external view returns (uint256) {
        return LEND(LendPlatform).exchangeRateCurrent();
    }
    function exchangeRateStored() external view returns (uint) {
        return LEND(LendPlatform).exchangeRateStored();
    }
    function getCash() external view returns (uint) {
        return LEND(LendPlatform).getCash();
    }
    function balanceOfUnderlying(address _addr) external view returns (uint256) {
        return LEND(LendPlatform).balanceOfUnderlying(_addr);
    }
}

        