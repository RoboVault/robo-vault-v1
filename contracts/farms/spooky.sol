// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "./ifarm.sol";

interface FARM {
    function deposit(uint256 _pid, uint256 _amount) external; /// deposit LP into farm -> call deposit with _amount = 0 to harvest LP 
    function withdraw(uint256 _pid, uint256 _amount) external; /// withdraw LP from farm
    function userInfo(uint256 _pid, address user) external view returns (uint); 
    function pendingBOO(uint256 _pid, address _user) external view returns (uint256);
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

abstract contract Spooky is IFarm {
    
    /**
     * Spooky Addresses
     */
    function farmAddress() public view override returns (address) {
        return 0x2b2929E785374c651a81A63878Ab22742656DcDd;
    }
    function routerAddress() public view override returns (address) {
        return 0xF491e7B69E4244ad4002BC14e878a34207E38c29;
    }
    function farmToken() public view override returns (address) {
        return 0x841FAD6EAe12c286d1Fd18d1d525DFfA75C7EFFE;
    }
    function farmTokenLp() public view override returns (address) {
        return 0xEc7178F4C41f346b2721907F5cF7628E388A7a58;
    }
    /*
     * Farm specific methods
     */
    function basePath(IERC20 _harvestToken, IERC20 _shortToken, IERC20 _base) internal view override returns (address[] memory) {
        address[] memory pathBase = new address[](2);
        pathBase[0] = address(_harvestToken);
        pathBase[1] = address(_base);
        return pathBase;
    }

    /*
     * Farming Methods
     */
    function farmDeposit(uint256 _pid, uint256 _amount) internal override {
        return FARM(farmAddress()).deposit(_pid, _amount);
    }
    function farmWithdraw(uint256 _pid, uint256 _amount) internal override {
        return FARM(farmAddress()).withdraw(_pid, _amount);
    }
    function farmUserInfo(uint256 _pid, address _user) internal view override returns (uint) {
        return FARM(farmAddress()).userInfo(_pid, _user);
    }
    function farmPendingRewards(uint256 _pid, address _user) internal view override returns (uint256) {
        return FARM(farmAddress()).pendingBOO(_pid, _user);
    }

    /*
     * Router Methods
     */
    function farmPermit(address _owner, address _spender, uint _value, uint _deadline, uint8 _v, bytes32 _r, bytes32 _s) internal override {
        return ROUTER(routerAddress()).permit(_owner, _spender, _value, _deadline, _v, _r, _s);
    }
    function farmAddLiquidity(address _tokenA, address _tokenB, uint256 _amountADesired, uint256 _amountBDesired, uint256 _amountAMin, uint256 _amountBMin, address _to, uint256 _deadline) internal override {
        return ROUTER(routerAddress()).addLiquidity(_tokenA, _tokenB, _amountADesired, _amountBDesired, _amountAMin, _amountBMin, _to, _deadline);
    }
    function farmRemoveLiquidity(address _tokenA, address _tokenB, uint _liquidity, uint _amountAMin,uint _amountBMin,address _to, uint _deadline) internal override returns (uint amountA, uint amountB) {
        return ROUTER(routerAddress()).removeLiquidity(_tokenA, _tokenB, _liquidity, _amountAMin, _amountBMin, _to, _deadline);
    }

    /*
     * Exchange Methods
     */
    function farmSwapExactTokensForTokens(uint256 _amountIn, uint256 _amountOutMin, address[] memory _path, address _to, uint256 _deadline) internal override {
        return EXCHANGE(routerAddress()).swapExactTokensForTokens(_amountIn, _amountOutMin, _path, _to, _deadline);
    }
    function farmSwapTokensForExactTokens(uint _amountOut, uint _amountInMax, address[] memory _path, address _to, uint _deadline) internal override {
        return EXCHANGE(routerAddress()).swapTokensForExactTokens(_amountOut, _amountInMax, _path, _to, _deadline);
    }
}
        