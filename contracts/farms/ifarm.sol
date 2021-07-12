pragma solidity ^0.5.0;
import "../vaultHelpers.sol";

contract IFarm {
    function farmAddress() public view returns (address); 
    function routerAddress() public view returns (address); 
    function farmToken() public view returns (address); 
    function farmTokenLp() public view returns (address); 
    function farmLP() public view returns (address);
    function farmPid() public view returns (uint256);

    /*
     * Farm specific methods
     * @todo: Move to a IPaths abstract class that's vault specific
     */
    function basePath(IERC20 _harvestToken, IERC20 _shortToken, IERC20 _base) internal view returns (address[] memory);
    
    /*
     * Farming Methods
     */
    function farmDeposit(uint256 _pid, uint256 _amount) internal;
    function farmWithdraw(uint256 _pid, uint256 _amount) internal;
    function farmUserInfo(uint256 _pid, address _user) internal view returns (uint);
    function farmPendingRewards(uint256 _pid, address _user) internal view returns (uint256);

    /*
     * Router Methods
     */
    function farmPermit(address _owner, address _spender, uint _value, uint _deadline, uint8 _v, bytes32 _r, bytes32 _s) internal;
    function farmAddLiquidity(address _tokenA, address _tokenB, uint256 _amountADesired, uint256 _amountBDesired, uint256 _amountAMin, uint256 _amountBMin, address _to, uint256 _deadline) internal;
    function farmRemoveLiquidity(address _tokenA, address _tokenB, uint _liquidity, uint _amountAMin,uint _amountBMin,address _to, uint _deadline) internal returns (uint amountA, uint amountB);

    /*
     * Exchange Methods
     */
    function farmSwapExactTokensForTokens(uint256 _amountIn, uint256 _amountOutMin, address[] memory _path, address _to, uint256 _deadline) internal;
    function farmSwapTokensForExactTokens(uint _amountOut, uint _amountInMax, address[] memory _path, address _to, uint _deadline) internal;
}
        