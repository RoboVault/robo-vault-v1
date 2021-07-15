// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "../vaultHelpers.sol";

abstract contract IFarm {
    using SafeMath for uint256;
    function farmAddress() public view virtual returns (address); 
    function routerAddress() public view virtual returns (address); 
    function farmToken() public view virtual returns (address); 
    function farmTokenLp() public view virtual returns (address); 
    function farmLP() public view virtual returns (address); /// LP contract for base & short token
    function farmPid() public view virtual returns (uint256); /// iquidity Pool ID
    
    /*
     * Farming Methods
     */
    function farmDeposit(uint256 _pid, uint256 _amount) internal virtual;
    function farmWithdraw(uint256 _pid, uint256 _amount) internal virtual;
    function farmUserInfo(uint256 _pid, address _user) internal virtual view returns (uint);
    function farmPendingRewards(uint256 _pid, address _user) internal virtual view returns (uint256);

    /*
     * Router Methods
     */
    function farmPermit(address _owner, address _spender, uint _value, uint _deadline, uint8 _v, bytes32 _r, bytes32 _s) internal virtual;
    function farmAddLiquidity(address _tokenA, address _tokenB, uint256 _amountADesired, uint256 _amountBDesired, uint256 _amountAMin, uint256 _amountBMin, address _to, uint256 _deadline) internal virtual;
    function farmRemoveLiquidity(address _tokenA, address _tokenB, uint _liquidity, uint _amountAMin,uint _amountBMin,address _to, uint _deadline) internal virtual returns (uint amountA, uint amountB);

    /*
     * Exchange Methods
     */
    function farmSwapExactTokensForTokens(uint256 _amountIn, uint256 _amountOutMin, address[] memory _path, address _to, uint256 _deadline) internal virtual;
    function farmSwapTokensForExactTokens(uint _amountOut, uint _amountInMax, address[] memory _path, address _to, uint _deadline) internal virtual;
}
        