pragma solidity ^0.5.0;

contract IFarm {
    address public FarmAddress; 
    address public RouterAddress; 
    address public Token; 
    address public TokenLp; 
    address public LP; /// LP contract for base & short token
    uint256 public pid; /// iquidity Pool ID

    /*
     * Farming Methods
     */
    function deposit(uint256 _pid, uint256 _amount) external;
    function withdraw(uint256 _pid, uint256 _amount) external;
    function userInfo(uint256 _pid, address _user) external view returns (uint);
    function pendingRewards(uint256 _pid, address _user) external view returns (uint256);

    /*
     * Router Methods
     */
    function permit(address _owner, address _spender, uint _value, uint _deadline, uint8 _v, bytes32 _r, bytes32 _s) external;
    function addLiquidity(address _tokenA, address _tokenB, uint256 _amountADesired, uint256 _amountBDesired, uint256 _amountAMin, uint256 _amountBMin, address _to, uint256 _deadline) external;
    function removeLiquidity(address _tokenA, address _tokenB, uint _liquidity, uint _amountAMin,uint _amountBMin,address _to, uint _deadline) external returns (uint amountA, uint amountB);

    /*
     * Exchange Methods
     */
    function swapExactTokensForTokens(uint256 _amountIn, uint256 _amountOutMin, address[] calldata _path, address _to, uint256 _deadline) external;
    function swapTokensForExactTokens(uint _amountOut, uint _amountInMax, address[] calldata _path, address _to, uint _deadline) external;
}
        