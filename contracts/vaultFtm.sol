pragma solidity ^0.5.0;
import "./vaultHelpers.sol";


interface LEND {
    /// interface for depositing into CREAM
    function mint(uint256 mintAmount) external; 
    function redeem(uint redeemTokens) external; 
    function redeemUnderlying(uint redeemAmount) external; 
    function balanceOf(address owner) external view returns (uint256); 
    function exchangeRateCurrent() external view returns (uint256);
    function exchangeRateStored() external view returns (uint);
    function getCash() external view returns (uint);
    
    function balanceOfUnderlying(address) external view returns (uint256);
}

interface BORROW {
    /// interface for borrowing from CREAM
    function borrow(uint256 borrowAmount) external returns (uint256); 
    function borrowBalanceStored(address account) external view returns (uint);
    function repayBorrow(uint repayAmount) external ; /// borrowAmount: The amount of the underlying borrowed asset to be repaid. A value of -1 (i.e. 2^256 - 1) can be used to repay the full amount.

}

interface ROUTER {
    /// placeholder -> contract for providing Liquidity 
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
    function addLiquidity(address tokenA, address tokenB, uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline) external;
    function removeLiquidity(address tokenA,address tokenB, uint liquidity, uint amountAMin,uint amountBMin,address to, uint deadline) external returns (uint amountA, uint amountB);}

interface Icomptroller {
  function enterMarkets(address[] calldata cTokens) external returns (uint[] memory);
}

interface FARM {
    /// placeholder -> contract for farming 
    function deposit(uint256 _pid, uint256 _amount) external; /// deposit LP into farm -> call deposit with _amount = 0 to harvest LP 
    function withdraw(uint256 _pid, uint256 _amount) external; /// withdraw LP from farm
    function userInfo(uint256 _pid, address user) external view returns (uint); 
}

interface EXCHANGE {
    /// placeholder -> where to exchange tokens 
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external; 
}

contract vault {

    using SafeMath for uint256;
    address  USDC = 0x04068DA6C83AFCFA0e13ba15A6696662335D5B75;
    /*
    address  WBTC = 0x321162Cd933E2Be498Cd2267a90534A804051b11;
    address  WETH = 0x74b23882a30290451A17c44f4F05243b6b58C76d;
    address  USDT = 0x049d68029688eAbF473097a2fC38ef61633A3C7A;
    */
    address  WFTM = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;
    address  lend_platform = 0x328A7b4d538A2b3942653a9983fdA3C12c571141; // platform for addding base token as collateral
    address  LP_spirit = 0xe7E90f5a767406efF87Fdad7EB07ef407922EC1D; /// LP contract for base & short token
    address  LP_spooky = 0x2b4C76d0dc16BE1C31D4C1DC53bF9B45987Fc75c; /// LP contract for base & short token (on spooky)
    address  borrow_platform = 0xd528697008aC67A21818751A5e3c58C8daE54696;
    address  comptrollerAddress = 0x4250A6D3BD57455d7C6821eECb6206F507576cD2; /// Cream Comptroller 
    address  SpiritRouter = 0x16327E3FbDaCA3bcF7E38F5Af2599D2DDc33aE52;
    address  SpookyRouter = 0xF491e7B69E4244ad4002BC14e878a34207E38c29;
    address  SpiritMaster = 0x9083EA3756BDE6Ee6f27a6e996806FBD37F6F093;
    address  SpookyMaster =  0x2b2929E785374c651a81A63878Ab22742656DcDd;
    address  routerAddress = SpiritRouter; 
    address  farm = SpiritMaster; /// spirit masterchef 
    address  Spirit = 0x5Cc61A78F164885776AA610fb0FE1257df78E59B; 
    address  Spooky = 0x841FAD6EAe12c286d1Fd18d1d525DFfA75C7EFFE;
    address  SpiritLP = 0x30748322B6E34545DBe0788C421886AEB5297789;
    address  SpookyLP = 0xEc7178F4C41f346b2721907F5cF7628E388A7a58;
    
    
    uint256  pid  =  4; /// spirit = 4 / spooky = 2 ; 
    uint256  tokensBorrowed = 0;

    IERC20 base = IERC20(USDC);
    IERC20 short_token = IERC20(WFTM);
    IERC20 lp = IERC20(LP_spirit);
    IERC20 lp_harvest_token = IERC20(SpiritLP); 
    IERC20 harvest_token = IERC20(Spirit);
    IERC20 lend_tokens = IERC20(lend_platform);
    ///IERC20 router = IERC20(routerAddress);
    


    
    constructor() public  {
        Icomptroller comptroller = Icomptroller(comptrollerAddress);
        address[] memory cTokens = new address[](1);
        cTokens[0] = 0x328A7b4d538A2b3942653a9983fdA3C12c571141; 
        comptroller.enterMarkets(cTokens);
        
    }
    

    
    function calcPoolValueInToken() public view returns(uint256){

        uint256 lpvalue = balanceLp();
        uint256 collateral = balanceLend();
        uint256 baseInWallet = balanceBase();
        uint256 debtShort = balanceDebt();
        uint256 shortInWallet = balanceShortBaseEq(); 

        return (baseInWallet + collateral +  lpvalue - debtShort + shortInWallet) ; 

    }

    function calcDebtRatio() public view returns(uint256){
        uint256 debtShort = balanceDebt();
        uint256 lpvalue = balanceLp();
        uint256 debtRatio = debtShort.mul(200).div(lpvalue); 
        return (debtRatio);
    }

    function calcCollateral() public view returns(uint256){
        uint256 debtShort = balanceDebt();
        uint256 collateral = balanceLend();
        uint256 collatRatio = debtShort.mul(100).div(collateral); 
        return (collatRatio);
    }

    function calcFreeCash() public view returns(uint256){
        uint256 bal = base.balanceOf(address(this)); 
        uint256 totalBal = calcPoolValueInToken();
        uint256 freeCashRatio = bal.mul(100).div(totalBal);
        return (freeCashRatio); 
    }

    /// get value of all LP in base currency
    function balanceLp() public view returns(uint256) {
        uint256 baseLP = _get_base_in_lp();
        uint256 lpIssued = lp.totalSupply();
        uint256 lpPooled = countLpPooled();
        uint256 totalLP = lpPooled + lp.balanceOf(address(this));
        uint256 lpvalue = totalLP.mul(baseLP).div(lpIssued).mul(2);
        return(lpvalue);
    }
    
    function balanceDebt() public view returns(uint256) {
        uint256 shortLP = _get_short_in_lp();
        uint256 baseLP = _get_base_in_lp();
        uint256 debtShort = BORROW(borrow_platform).borrowBalanceStored(address(this));
        return (debtShort.mul(baseLP).div(shortLP));
        
    }
    
    function balanceBase() public view returns(uint256){
        return (base.balanceOf(address(this)));
    }
    
    function balanceShort() public view returns(uint256){
        return (short_token.balanceOf(address(this)));
    }
    
    function balanceShortBaseEq() public view returns(uint256){
        uint256 shortLP = _get_short_in_lp();
        uint256 baseLP = _get_base_in_lp();
        return (short_token.balanceOf(address(this)).mul(baseLP).div(shortLP));
    }
    
    function balanceLend() public view returns(uint256){
        uint256 b = lend_tokens.balanceOf(address(this));
        return (b.mul(LEND(lend_platform).exchangeRateStored()).div(1e18));
    }
    
    function _lendBase(uint256 amount) internal {
        base.approve(address(lend_platform), amount);
        LEND(lend_platform).mint(amount);
        /// baselent += amount;
    }
    
    

    
    function _add_to_LP(uint256 _amount_short) internal {
        uint256 shortLP = _get_short_in_lp();
        uint256 baseLP = _get_base_in_lp();
        uint256 _amount_base = _amount_short.mul(baseLP).div(shortLP);
        _add_to_LP(_amount_short, _amount_base, _amount_short, _amount_base.mul(99).div(100));
        
    }
    

    function _borrow_base_eq(uint256 _amount) internal returns(uint256) {
        ///uint256 bal = base.balanceOf(address(this));
        uint256 shortLP = _get_short_in_lp();
        uint256 baseLP = _get_base_in_lp();
        uint256 borrowamount = _amount.mul(shortLP).div(baseLP);
        _borrow(borrowamount);
        return (borrowamount);
        
    }


    function _borrow(uint256 borrowAmount) internal {
        BORROW(borrow_platform).borrow(borrowAmount);
        tokensBorrowed += borrowAmount;
        
    }
    
    function _repay_debt() public {
        uint256 _bal = short_token.balanceOf(address(this)); 
        short_token.approve(address(borrow_platform), _bal);
        uint256 _debt =  BORROW(borrow_platform).borrowBalanceStored(address(this)); 
        if (_bal < _debt){
            BORROW(borrow_platform).repayBorrow(_bal);
            tokensBorrowed -= _bal;
            
        }
        else {
            BORROW(borrow_platform).repayBorrow(_debt);
            tokensBorrowed -= _debt;
        }
    }
    
    function _get_short_in_lp() public view returns (uint256) {
        uint256 short_lp = short_token.balanceOf(address(lp)) ; 
        return (short_lp);          
    }
    
    function _get_base_in_lp() public view returns (uint256) {
        uint256 base_lp = base.balanceOf(address(lp)) ;
        return (base_lp);
    }
    
    function _get_harvest_in_harvest_lp() public view returns(uint256) {
        uint256 harvest_lp = harvest_token.balanceOf(address(lp_harvest_token)); 
        return harvest_lp;          
    }
    
    function _get_short_in_harvest_lp() public view returns(uint256) {
        uint256 short_token_lp = short_token.balanceOf(address(lp_harvest_token)); 
        return short_token_lp;          
    }
    
    function _redeem_base(uint256 _redeem_amount) public {
        LEND(lend_platform).redeemUnderlying(_redeem_amount); 
    }

    function countLpPooled() public view returns(uint256){
        uint256 lpPooled = FARM(farm).userInfo(pid, address(this));
        return lpPooled;
    }
    
    
    function _withdrawLpRebalance(uint256 _amount) public {
        uint256 lpValue = balanceLp(); 
        uint256 lpUnpooled =  lp.balanceOf(address(this)); 
        uint256 lpPooled = countLpPooled();
        uint256 lpCount = lpUnpooled.add(lpPooled);
        uint256 lpReq = _amount.mul(lpCount).div(balanceLp()); 
        uint256 lpWithdraw;
        if (lpReq - lpUnpooled < lpPooled){
            lpWithdraw = lpReq - lpUnpooled;
        } else {
            lpWithdraw = lpPooled;
        }
        _withdrawSomeLp(lpWithdraw);
        _removeAllLp(); 
         _swap_base_for_short(_amount.div(2));
        _repay_debt(); 
    }
    
    function _withdrawLpRebalanceCollateral(uint256 _amount) public {
        uint256 lpValue = balanceLp(); 
        uint256 lpUnpooled =  lp.balanceOf(address(this)); 
        uint256 lpPooled = countLpPooled();
        uint256 lpCount = lpUnpooled.add(lpPooled);
        uint256 lpReq = _amount.mul(lpCount).div(balanceLp()); 
        uint256 lpWithdraw;
        if (lpReq - lpUnpooled < lpPooled){
            lpWithdraw = lpReq - lpUnpooled;
        } else {
            lpWithdraw = lpPooled;
        }
        _withdrawSomeLp(lpWithdraw);
        _removeAllLp(); 
        
        if (_amount.div(2) > base.balanceOf(address(this))){
            _lendBase(_amount.div(2));
        } else {
            _lendBase(base.balanceOf(address(this)));
        }
        _repay_debt(); 
    }
    
    
    function _add_to_LP(uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin) internal {
        base.approve(routerAddress, amountBDesired);
        short_token.approve(routerAddress, amountADesired);
        ROUTER(routerAddress).addLiquidity(address(short_token), address(base), amountADesired, amountBDesired, amountAMin, amountBMin, address(this), block.timestamp + 15); /// add liquidity 
    }
    
    function _depoistLp() internal {
        uint256 lp_balance = lp.balanceOf(address(this)); /// get number of LP tokens
        lp.approve(address(farm), lp_balance);
        FARM(farm).deposit(pid, lp_balance); /// deposit LP tokens to farm
        ///lpPooled += lp_balance; /// update balance for number of LP tokens in Farm 
    }

    function _withdrawSomeLp(uint256 _amount) public {
        require(_amount <= countLpPooled());
        FARM(farm).withdraw(pid, _amount);
        ///lpPooled -= _amount; 
    }
    
    function _removeAllLp() public {
        ///require(msg.sender == owner, 'only admin'); 
        uint256 _amount = lp.balanceOf(address(this));
        uint256 shortLP = _get_short_in_lp();
        uint256 baseLP = _get_base_in_lp();
        uint256 lpIssued = lp.totalSupply();
        /*
        uint256 amountAMin = _amount.mul(shortLP).mul(99).div(100).div(lpIssued);
        uint256 amountBMin = _amount.mul(baseLP).mul(99).div(100).div(lpIssued);
        */
        
        uint256 amountAMin = 1;
        uint256 amountBMin = 1;
        
        lp.approve(routerAddress, _amount);
        
        ROUTER(routerAddress).removeLiquidity(address(short_token), address(base), _amount, amountAMin, amountBMin,address(this), block.timestamp + 15);
    }
    
    
    function _withdrawAllPooled() public {
        ///require(msg.sender == owner, 'only admin'); 
        uint256 lpPooled = countLpPooled();
        FARM(farm).withdraw(pid, lpPooled);
    }
    
      
    

    
    function _sell_harvest_base() public returns (uint256) {
        address[] memory pathBase = new address[](3);
        pathBase[0] = address(harvest_token);
        pathBase[1] = address(short_token);
        pathBase[2] = address(base);
        
        uint256 harvestBalance = harvest_token.balanceOf(address(this)); 
        harvest_token.approve(routerAddress, harvestBalance);
        uint256 harvestLP_A = _get_harvest_in_harvest_lp();
        uint256 shortLP_A = _get_short_in_harvest_lp();
        uint256 shortLP_B = _get_short_in_lp();
        uint256 baseLP_B = _get_base_in_lp();
        
        uint256 amountOutMinamountOutShort = harvestBalance.mul(shortLP_A).div(harvestLP_A);
        uint256 amountOutMin = amountOutMinamountOutShort.mul(baseLP_B).div(shortLP_B).mul(99).div(100);
        EXCHANGE(routerAddress).swapExactTokensForTokens(harvestBalance, amountOutMin, pathBase, address(this), block.timestamp + 120);
        return (amountOutMin);
    }

    function _sell_harvest_short() public {
        address[] memory pathShort = new address[](2);
        pathShort[0] = address(harvest_token);
        pathShort[1] = address(short_token);


        uint256 harvestBalance = harvest_token.balanceOf(address(this)); 
        harvest_token.approve(routerAddress, harvestBalance);
        uint256 harvestLP = _get_harvest_in_harvest_lp();
        uint256 shortLP = _get_short_in_harvest_lp();
        uint256 amountOutMin = harvestBalance.mul(shortLP).div(harvestLP).mul(99).div(100);
        EXCHANGE(routerAddress).swapExactTokensForTokens(harvestBalance, amountOutMin, pathShort, address(this), block.timestamp + 120);
    }

    function _swap_base_for_short(uint256 _amount) public {
        
        address[] memory pathSwap = new address[](3);
        pathSwap[0] = address(base);
        ///pathSwap[1] = 0xAd84341756Bf337f5a0164515b1f6F993D194E1f;
        pathSwap[1] = address(short_token);
        base.approve(routerAddress, _amount);
        
        
        uint256 shortLP = _get_short_in_lp();
        uint256 baseLP = _get_base_in_lp();
        uint256 amountOutMin = _amount.mul(shortLP).div(baseLP).mul(99).div(100);
        EXCHANGE(routerAddress).swapExactTokensForTokens(_amount, amountOutMin, pathSwap, address(this), block.timestamp + 120);
        
    }
    
    function _swap_short_for_base(uint256 _amount) public {
        
        address[] memory pathSwap = new address[](2);
        
        pathSwap[0] = address(short_token);
        pathSwap[1] = address(base);
        
        short_token.approve(routerAddress, _amount);

        uint256 shortLP = _get_short_in_lp();
        uint256 baseLP = _get_base_in_lp();
        uint256 amountOutMin = _amount.mul(baseLP).div(shortLP).mul(99).div(100);
        EXCHANGE(routerAddress).swapExactTokensForTokens(_amount, amountOutMin, pathSwap, address(this), block.timestamp + 120);
        
    }
    
    
}

        