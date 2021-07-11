pragma solidity ^0.5.0;

interface FARM {
    function deposit(uint256 _pid, uint256 _amount) external; /// deposit LP into farm -> call deposit with _amount = 0 to harvest LP 
    function withdraw(uint256 _pid, uint256 _amount) external; /// withdraw LP from farm
    function userInfo(uint256 _pid, address user) external view returns (uint); 
    function pendingSpirit(uint256 _pid, address _user) external view returns (uint256);
}

interface ROUTER {
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
    function addLiquidity(address tokenA, address tokenB, uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline) external;
    function removeLiquidity(address tokenA,address tokenB, uint liquidity, uint amountAMin,uint amountBMin,address to, uint deadline) external returns (uint amountA, uint amountB);
}

interface EXCHANGE {
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external; 
    function swapTokensForExactTokens(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline) external;
}

contract Farm {
    address constant SpiritRouter = 0x16327E3FbDaCA3bcF7E38F5Af2599D2DDc33aE52;
    address constant FarmAddress = 0x9083EA3756BDE6Ee6f27a6e996806FBD37F6F093; // spirit master
    address constant RouterAddress = SpiritRouter; 
    address constant Token = 0x5Cc61A78F164885776AA610fb0FE1257df78E59B; 
    address constant TokenLp = 0x30748322B6E34545DBe0788C421886AEB5297789; 

    /*
     * Farming Methods
     */
    function deposit(uint256 _pid, uint256 _amount) internal {
        return FARM(FarmAddress).deposit(_pid, _amount);
    }
    function withdraw(uint256 _pid, uint256 _amount) internal {
        return FARM(FarmAddress).withdraw(_pid, _amount);
    }
    function userInfo(uint256 _pid, address _user) internal view returns (uint) {
        return FARM(FarmAddress).userInfo(_pid, _user);
    }
    function pendingRewards(uint256 _pid, address _user) internal view returns (uint256) {
        return FARM(FarmAddress).pendingSpirit(_pid, _user);
    }

    /*
     * Router Methods
     */
    function permit(address _owner, address _spender, uint _value, uint _deadline, uint8 _v, bytes32 _r, bytes32 _s) internal {
        return ROUTER(RouterAddress).permit(_owner, _spender, _value, _deadline, _v, _r, _s);
    }
    function addLiquidity(address _tokenA, address _tokenB, uint256 _amountADesired, uint256 _amountBDesired, uint256 _amountAMin, uint256 _amountBMin, address _to, uint256 _deadline) internal {
        return ROUTER(RouterAddress).addLiquidity(_tokenA, _tokenB, _amountADesired, _amountBDesired, _amountAMin, _amountBMin, _to, _deadline);
    }
    function removeLiquidity(address _tokenA, address _tokenB, uint _liquidity, uint _amountAMin,uint _amountBMin,address _to, uint _deadline) internal returns (uint amountA, uint amountB) {
        return ROUTER(RouterAddress).removeLiquidity(_tokenA, _tokenB, _liquidity, _amountAMin, _amountBMin, _to, _deadline);
    }

    /*
     * Exchange Methods
     */
    function swapExactTokensForTokens(uint256 _amountIn, uint256 _amountOutMin, address[] memory _path, address _to, uint256 _deadline) internal {
        return EXCHANGE(RouterAddress).swapExactTokensForTokens(_amountIn, _amountOutMin, _path, _to, _deadline);
    }
    function swapTokensForExactTokens(uint _amountOut, uint _amountInMax, address[] memory _path, address _to, uint _deadline) internal {
        return EXCHANGE(RouterAddress).swapTokensForExactTokens(_amountOut, _amountInMax, _path, _to, _deadline);
    }
}
        