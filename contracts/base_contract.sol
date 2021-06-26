///https://mainnet.infura.io/v3/04ca3c45766d460f94fd4cbae7c60365

pragma solidity ^0.5.0;

/*
///import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
///import '@openzeppelin/contracts/utils/math/SafeMath.sol';
*/

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;

        return c;
    }
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}


interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface LEND {
    /// interface for depositing into CREAM
    function mint(uint256 mintAmount) external; 
    function redeem(uint redeemTokens) external; 
    function balanceOf(address owner) external view returns (uint256); 
    function exchangeRateCurrent() external view returns (uint256);
    function balanceOfUnderlying(address) external view returns (uint256);
}

interface BORROW {
    /// interface for borrowing from CREAM
    function borrow(uint256 borrowAmount) external ; 
    function borrowBalanceCurrent(address) external view returns (uint256);
    function repayBorrow(uint repayAmount) external ; /// borrowAmount: The amount of the underlying borrowed asset to be repaid. A value of -1 (i.e. 2^256 - 1) can be used to repay the full amount.

}

interface WRAPPER {
    /// placeholder -> wrap / unrwap ETH / FTM etc 
    function deposit() external; /// used to transfer FTM in exchange for WFTM 
    function withdraw(uint256 amount) external;
}

interface EXCHANGE {
    /// placeholder -> where to exchange tokens 
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata, address to, uint256 deadline) external; 
}

interface POOL {
    /// placeholder -> contract for providing Liquidity 
    function addLiquidity(address tokenA, address tokenB, uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline) external;
    function removeLiquidityETH(address token,uint liquidity,uint amountTokenMin,uint amountETHMin,address to,uint deadline) external;
}

interface FARM {
    /// placeholder -> contract for farming 
    function deposit(uint256 _pid, uint256 _amount) external; /// deposit LP into farm -> call deposit with _amount = 0 to harvest LP 
    function withdraw(uint256 _pid, uint256 _amount) external; /// withdraw LP from farm
}


contract vaultHelper {

    using SafeMath for uint256;
    
    address owner ;
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address SUSHI = 0x6B3595068778DD592e39A122f4f5a5cF09C90fE2;
    address crUSDC = 0x44fbeBd2F576670a6C33f6Fc0B00aA8c5753b322;
    address crETH = 0xD06527D5e56A3495252A528C4987003b712860eE;
    address USDCWETHLP = 0x397FF1542f962076d0BFE58eA045FfA2d347ACa0; 

    IERC20 router = IERC20(0xEF0881eC094552b2e128Cf945EF17a6752B4Ec5d);
    IERC20 base = IERC20(USDC);  
    IERC20 short_token = IERC20(WETH);  
    IERC20 harvest_token = IERC20(SUSHI);   
    address public constant lend_platform = 0x44fbeBd2F576670a6C33f6Fc0B00aA8c5753b322; 
    address public constant borrow_platform =0xD06527D5e56A3495252A528C4987003b712860eE;  
    IERC20 farm = IERC20(0x9083EA3756BDE6Ee6f27a6e996806FBD37F6F093); 
    IERC20 lp = IERC20(USDCWETHLP);
    IERC20 lp_harvest_token = IERC20(SUSHI);  
    IERC20 wrapper = IERC20(WETH); 
    /*
    /// EXCHANGE exchange = IERC20(0x16327E3FbDaCA3bcF7E38F5Af2599D2DDc33aE52); 
    /// IERC20 pool = IERC20(0x16327E3FbDaCA3bcF7E38F5Af2599D2DDc33aE52);  
    /// address[] pathBase = [0x5cc61a78f164885776aa610fb0fe1257df78e59b,0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83,0x04068da6c83afcfa0e13ba15a6696662335d5b75];
    /// address[] pathShort = [0x5cc61a78f164885776aa610fb0fe1257df78e59b,0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83];
    */
    uint256 pid  =  4; 

    uint256 lpPooled = 0; 
    uint256 shortborrowed = 0;
    uint256 baselent = 0; 


    function _get_collateral_ratio() public view returns(uint256) {
        uint256 short_token_Price = _get_short_price();
        uint256 debt = BORROW(borrow_platform).borrowBalanceCurrent(address(this))*short_token_Price; 
        uint256 creamvalue = LEND(lend_platform).balanceOfUnderlying(address(this));
        return ( debt.div(creamvalue).div(100));            

    }
    
    function _get_short_price() public view returns (uint256) {
        uint256 base_lp = base.balanceOf(address(lp)) ; 
        uint256 short_lp = short_token.balanceOf(address(lp)) ; 
        uint256 price = short_lp.div(short_lp);
        return (price);          
    }

    function _get_harvest_price() public view returns(uint256) {
        uint256 harvest_lp = harvest_token.balanceOf(address(lp_harvest_token)); 
        uint256 short_token_lp = short_token.balanceOf(address(lp_harvest_token)); 
        return short_token_lp.div(harvest_lp);          
    }

    function _get_lp_position(uint256 n_lp_tokens) public view returns(uint256){ 
        uint256 base_lp = base.balanceOf(address(lp)) ; 
        uint256 short_lp = short_token.balanceOf(address(lp)) ; 
        uint256 supply = lp.totalSupply(); 
        uint256 lpShare = n_lp_tokens.div(supply);
        return base_lp.mul(lpShare).mul(2); 
    }

    function net_debt_position() public view returns(uint256){
        uint256 short_token_Price = _get_short_price();
        uint256 lpvalue = _get_lp_position(lpPooled);
        uint256 debt = BORROW(borrow_platform).borrowBalanceCurrent(address(this))*short_token_Price; 
        return debt - lpvalue.div(2) ; 
    }

    function get_total_balance() public view returns(uint256){
        uint256 short_token_Price = _get_short_price();
        uint256 lpvalue = _get_lp_position(lpPooled);
        uint256 creamvalue = LEND(lend_platform).balanceOfUnderlying(address(this));
        uint256 debtShort = BORROW(borrow_platform).borrowBalanceCurrent(address(this));
        uint256 inwallet = base.balanceOf(address(this));

        return lpvalue + creamvalue - debtShort.mul(short_token_Price) + inwallet ; 

    }


    function _lend_base(uint256 amount) internal {
        base.approve(address(lend_platform), amount);
        LEND(lend_platform).mint(amount);
        baselent += amount;
    }

    function _borrow(uint256 borrowAmount) internal {
        BORROW(borrow_platform).borrow(borrowAmount);
        shortborrowed += borrowAmount;
    }
    /*
    function _add_to_LP(uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin) internal {
        pool.addLiquidity(address(short_token), address(base), amountADesired, amountBDesired, amountAMin, amountBMin, address(this), block.timestamp + 120); /// add liquidity 
    }

    function _depoistLp() internal {
        uint256 lp_balance = lp.balanceOf(address(this)); /// get number of LP tokens
        farm.deposit(pid, lp_balance); /// deposit LP tokens to farm
        lpPooled += lp_balance; /// update balance for number of LP tokens in Farm 

    }

    function _withdrawSomeLp(uint256 _amount) internal {
        require(_amount <= lpPooled);
        farm.withdraw(pid, _amount);
        lpPooled -= _amount; 
    }

    function _harvest() internal {
        farm.deposit(pid, 0);
    }

    function _sell_harvest_base() internal {
        uint256 harvestBalance = harvest_token.balanceOf(address(this)); 
        uint256 harvestPrice = _get_harvest_price(); 
        uint256 short_token_Price = _get_short_price();
        uint256 amountOutMin = harvestBalance.mul(.99).mul(harvestPrice).mul(short_token_Price);
        exchange.swapExactTokensForTokens(harvestBalance, amountOutMin, pathBase, address(this), block.timestamp + 120);
    }

    function _sell_harvest_borrow() internal {
        uint256 harvestBalance = harvest_token.balanceOf(address(this)); 
        uint256 harvestPrice = _get_harvest_price(); 
        uint256 amountOutMin = harvestBalance.mul(.99).mul(harvestPrice);
        exchange.swapExactTokensForTokens(harvestBalance, amountOutMin, pathShort, address(this), block.timestamp + 120);
    }
    
    function _repay_debt() internal {
        uint256 _bal = short_token.balanceOf(address(this)); 
        uint256 _debt =  borrow_platform.borrowBalanceCurrent(address(this)); 
        if (_bal < _debt){
            borrow_platform.repayBorrow(_bal);
        }
        else {
            borrow_platform.repayBorrow(_debt);
        }
        
    }
    
    /// function for removing LP and converting back to base / LP 
    function _removeLp() internal {
        uint256 amount = lp.balanceOf(address(this));
        uint256 base_rem = _get_lp_position(amount); 
        uint256 short_token_price = _get_short_price(); 
        lp.approve(router, lp.balanceOf(address(this)));
        pool.removeLiquidityETH(address(lp), amount, base_rem.div(2).mul(.99), base_rem.div(2).mul(.99).div(short_token_price) ,address(this),block.timestamp + 120);
    }
    */

}