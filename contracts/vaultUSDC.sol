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
    function pendingSpirit(uint256 _pid, address _user) external view returns (uint256);
}

interface EXCHANGE {
    /// placeholder -> where to exchange tokens 
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external; 
    function swapTokensForExactTokens(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline) external;
}

contract vault is ERC20, ERC20Detailed {

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    uint256 decimalAdj = 1000000; /// variable used when calculating (equivant to 1 / 100% for float like operations )
    uint256 slippageAdj = 990000;
    uint256 slippageAdjHigh = 1010000;
    
    
    /// base token specific info
    address  USDC = 0x04068DA6C83AFCFA0e13ba15A6696662335D5B75;
    address  lendPlatform = 0x328A7b4d538A2b3942653a9983fdA3C12c571141; // platform for addding base token as collateral
    address  LP = 0xe7E90f5a767406efF87Fdad7EB07ef407922EC1D; /// LP contract for base & short token
    uint256  pid  =  4; 
    IERC20 base = IERC20(USDC);
    
    address  WFTM = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;
    address  borrow_platform = 0xd528697008aC67A21818751A5e3c58C8daE54696;
    address  comptrollerAddress = 0x4250A6D3BD57455d7C6821eECb6206F507576cD2; /// Cream Comptroller 
    address  SpiritRouter = 0x16327E3FbDaCA3bcF7E38F5Af2599D2DDc33aE52;
    address  SpiritMaster = 0x9083EA3756BDE6Ee6f27a6e996806FBD37F6F093;
    address  routerAddress = SpiritRouter; 
    address  farm = SpiritMaster; /// spirit masterchef 
    address  Spirit = 0x5Cc61A78F164885776AA610fb0FE1257df78E59B; 
    address  SpiritLP = 0x30748322B6E34545DBe0788C421886AEB5297789;
    
    IERC20 shortToken = IERC20(WFTM);
    IERC20 lp = IERC20(LP);
    IERC20 lp_harvestToken = IERC20(SpiritLP); 
    IERC20 harvestToken = IERC20(Spirit);
    IERC20 lend_tokens = IERC20(lendPlatform);

    
    constructor() public  {
        Icomptroller comptroller = Icomptroller(comptrollerAddress);
        address[] memory cTokens = new address[](1);
        cTokens[0] = 0x328A7b4d538A2b3942653a9983fdA3C12c571141; 
        comptroller.enterMarkets(cTokens);
        
    }
    

    /// calculate total value of vault assets 
    function calcPoolValueInToken() public view returns(uint256){

        uint256 lpvalue = balanceLp();
        uint256 collateral = balanceLend();
        uint256 baseInWallet = balanceBase();
        uint256 debtShort = balanceDebt();
        uint256 shortInWallet = balanceShortBaseEq(); 
        uint256 pendingRewards = balancePendingHarvest();

        return (baseInWallet + collateral +  lpvalue - debtShort + shortInWallet + pendingRewards) ; 

    }
    // debt ratio - used to trigger rebalancing of debt 
    function calcDebtRatio() public view returns(uint256){
        uint256 debtShort = balanceDebt();
        uint256 lpvalue = balanceLp();
        uint256 debtRatio = debtShort.mul(decimalAdj).mul(2).div(lpvalue); 
        return (debtRatio);
    }
    // calculate debt / collateral - used to trigger rebalancing of debt & collateral 
    function calcCollateral() public view returns(uint256){
        uint256 debtShort = balanceDebt();
        uint256 collateral = balanceLend();
        uint256 collatRatio = debtShort.mul(decimalAdj).div(collateral); 
        return (collatRatio);
    }

    // current % of vault assets held in reserve - used to trigger deployment of assets into strategy
    function calcFreeCash() public view returns(uint256){
        uint256 bal = base.balanceOf(address(this)); 
        uint256 totalBal = calcPoolValueInToken();
        uint256 freeCashRatio = bal.mul(decimalAdj).div(totalBal);
        return (freeCashRatio); 
    }

    /// get value of all LP in base currency
    function balanceLp() public view returns(uint256) {
        uint256 baseLP = getBaseInLp();
        uint256 lpIssued = lp.totalSupply();
        uint256 lpPooled = countLpPooled();
        uint256 totalLP = lpPooled + lp.balanceOf(address(this));
        uint256 lpvalue = totalLP.mul(baseLP).div(lpIssued).mul(2);
        return(lpvalue);
    }
    // value of borrowed tokens in value of base tokens
    function balanceDebt() public view returns(uint256) {
        uint256 shortLP = _getShortInLp();
        uint256 baseLP = getBaseInLp();
        uint256 debtShort = BORROW(borrow_platform).borrowBalanceStored(address(this));
        return (debtShort.mul(baseLP).div(shortLP));
        
    }
    
    function balancePendingHarvest() public view returns(uint256){
        uint256 rewardsPending = FARM(farm).pendingSpirit(pid, address(this));
        uint256 harvestLP_A = _getHarvestInHarvestLp();
        uint256 shortLP_A = _getShortInHarvestLp();
        uint256 shortLP_B = _getShortInLp();
        uint256 baseLP_B = getBaseInLp();
        uint256 balShort = rewardsPending.mul(shortLP_A).div(harvestLP_A);
        uint256 balRewards = balShort.mul(baseLP_B).div(shortLP_B);
        return (balRewards);
        
    }
    
    // reserves 
    function balanceBase() public view returns(uint256){
        return (base.balanceOf(address(this)));
    }
    
    function balanceShort() public view returns(uint256){
        return (shortToken.balanceOf(address(this)));
    }
    
    function balanceShortBaseEq() public view returns(uint256){
        uint256 shortLP = _getShortInLp();
        uint256 baseLP = getBaseInLp();
        return (shortToken.balanceOf(address(this)).mul(baseLP).div(shortLP));
    }
    
    function balanceLend() public view returns(uint256){
        uint256 b = lend_tokens.balanceOf(address(this));
        return (b.mul(LEND(lendPlatform).exchangeRateStored()).div(1e18));
    }
    // lend base tokens to lending platform 
    function _lendBase(uint256 amount) public {
        LEND(lendPlatform).mint(amount);
        /// baselent += amount;
    }
    
    

    
    // borrow tokens woth _amount of base tokens 
    function _borrowBaseEq(uint256 _amount) public returns(uint256) {
        ///uint256 bal = base.balanceOf(address(this));
        uint256 shortLP = _getShortInLp();
        uint256 baseLP = getBaseInLp();
        uint256 borrowamount = _amount.mul(shortLP).div(baseLP);
        _borrow(borrowamount);
        return (borrowamount);
        
    }


    function _borrow(uint256 borrowAmount) public {
        BORROW(borrow_platform).borrow(borrowAmount);

    }
    
    // automatically repays debt using any short tokens held in wallet up to total debt value
    function _repayDebt() public {
        uint256 _bal = shortToken.balanceOf(address(this)); 
        uint256 _debt =  BORROW(borrow_platform).borrowBalanceStored(address(this)); 
        if (_bal < _debt){
            BORROW(borrow_platform).repayBorrow(_bal);
        }
        else {
            BORROW(borrow_platform).repayBorrow(_debt);
        }
    }
    
    function calcBorrowAllocation() public view returns (uint256){
        uint256 balLend = balanceLend();
        uint256 balLp = balanceLp(); 
        uint256 borrowAllocation = balLp.mul(decimalAdj).div(balLend.add(balLp.div(2))).div(2);
        return (borrowAllocation);
        
    }
    
    function _getShortInLp() public view returns (uint256) {
        uint256 short_lp = shortToken.balanceOf(address(lp)) ; 
        return (short_lp);          
    }
    
    function getBaseInLending() public view returns (uint256) {
        uint256 bal = base.balanceOf(address(lendPlatform));
        return(bal);
    }
    
    function getBaseInLp() public view returns (uint256) {
        uint256 base_lp = base.balanceOf(address(lp)) ;
        return (base_lp);
    }
    
    function _getHarvestInHarvestLp() public view returns(uint256) {
        uint256 harvest_lp = harvestToken.balanceOf(address(lp_harvestToken)); 
        return harvest_lp;          
    }
    
    function _getShortInHarvestLp() public view returns(uint256) {
        uint256 shortToken_lp = shortToken.balanceOf(address(lp_harvestToken)); 
        return shortToken_lp;          
    }
    
    function _redeemBase(uint256 _redeem_amount) public {
        LEND(lendPlatform).redeemUnderlying(_redeem_amount); 
    }

    function countLpPooled() public view returns(uint256){
        uint256 lpPooled = FARM(farm).userInfo(pid, address(this));
        return lpPooled;
    }
    
    // withdraws some LP worth _amount, converts all withdrawn LP to short token to repay debt 
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
        if (_amount.div(2) <= base.balanceOf(address(this))){
            _swapBaseShort(_amount.div(2));
        } else {
            _swapBaseShort(base.balanceOf(address(this)));
        }
         
        _repayDebt(); 
    }
    
    //  withdraws some LP worth _amount, uses withdrawn LP to add to collateral & repay debt 
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
        
        if (_amount.div(2) <= base.balanceOf(address(this))){
            _lendBase(_amount.div(2));
        } else {
            _lendBase(base.balanceOf(address(this)));
        }
        _repayDebt(); 
    }
    
    
    function _addToLpFull(uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin) internal {
        ROUTER(routerAddress).addLiquidity(address(shortToken), address(base), amountADesired, amountBDesired, amountAMin, amountBMin, address(this), block.timestamp + 15); /// add liquidity 
    }
    
    function _addToLP(uint256 _amountShort) public {
        uint256 shortLP = _getShortInLp();
        uint256 baseLP = getBaseInLp();
        uint256 _amountBase = _amountShort.mul(baseLP).div(shortLP);
        _addToLpFull(_amountShort, _amountBase, _amountShort, _amountBase.mul(slippageAdj).div(decimalAdj));
        
    }
    
    function _depoistLp() public {
        uint256 lpBalance = lp.balanceOf(address(this)); /// get number of LP tokens
        FARM(farm).deposit(pid, lpBalance); /// deposit LP tokens to farm
    }

    function _withdrawSomeLp(uint256 _amount) public {
        require(_amount <= countLpPooled());
        FARM(farm).withdraw(pid, _amount);
    }
    
    // all LP currently not in Farm is removed 
    function _removeAllLp() public {
        ///require(msg.sender == owner, 'only admin'); 
        uint256 _amount = lp.balanceOf(address(this));
        uint256 shortLP = _getShortInLp();
        uint256 baseLP = getBaseInLp();
        uint256 lpIssued = lp.totalSupply();

        uint256 amountAMin = _amount.mul(shortLP).div(lpIssued).mul(slippageAdj).div(decimalAdj);
        uint256 amountBMin = _amount.mul(baseLP).div(lpIssued).mul(slippageAdj).div(decimalAdj);
        
        
        
        ROUTER(routerAddress).removeLiquidity(address(shortToken), address(base), _amount, amountAMin, amountBMin,address(this), block.timestamp + 15);
    }
    
    
    function _withdrawAllPooled() public {
        ///require(msg.sender == owner, 'only admin'); 
        uint256 lpPooled = countLpPooled();
        FARM(farm).withdraw(pid, lpPooled);
    }
    
      
    // below functions interact with AMM converting Harvest Rewards & Swapping between base & short token as required for rebalancing 
    
    function _sellHarvestBase() public returns (uint256) {
        address[] memory pathBase = new address[](3);
        pathBase[0] = address(harvestToken);
        pathBase[1] = address(shortToken);
        pathBase[2] = address(base);
        
        uint256 harvestBalance = harvestToken.balanceOf(address(this)); 
        uint256 harvestLP_A = _getHarvestInHarvestLp();
        uint256 shortLP_A = _getShortInHarvestLp();
        uint256 shortLP_B = _getShortInLp();
        uint256 baseLP_B = getBaseInLp();
        
        uint256 amountOutMinamountOutShort = harvestBalance.mul(shortLP_A).div(harvestLP_A);
        uint256 amountOutMin = amountOutMinamountOutShort.mul(baseLP_B).div(shortLP_B).mul(slippageAdj).div(decimalAdj);
        EXCHANGE(routerAddress).swapExactTokensForTokens(harvestBalance, amountOutMin, pathBase, address(this), block.timestamp + 120);
        return (amountOutMin);
    }

    function _sellHarvestShort() public {
        address[] memory pathShort = new address[](2);
        pathShort[0] = address(harvestToken);
        pathShort[1] = address(shortToken);


        uint256 harvestBalance = harvestToken.balanceOf(address(this)); 
        uint256 harvestLP = _getHarvestInHarvestLp();
        uint256 shortLP = _getShortInHarvestLp();
        uint256 amountOutMin = harvestBalance.mul(shortLP).mul(slippageAdj).div(harvestLP).div(decimalAdj);
        EXCHANGE(routerAddress).swapExactTokensForTokens(harvestBalance, amountOutMin, pathShort, address(this), block.timestamp + 120);
    }

    function _swapBaseShort(uint256 _amount) public {
        
        address[] memory pathSwap = new address[](2);
        pathSwap[0] = address(base);
        ///pathSwap[1] = 0xAd84341756Bf337f5a0164515b1f6F993D194E1f;
        pathSwap[1] = address(shortToken);

        
        uint256 shortLP = _getShortInLp();
        uint256 baseLP = getBaseInLp();
        uint256 amountOutMin = _amount.mul(shortLP).mul(slippageAdj).div(baseLP).div(decimalAdj);
        EXCHANGE(routerAddress).swapExactTokensForTokens(_amount, amountOutMin, pathSwap, address(this), block.timestamp + 120);
        
    }
    
    function _swapShortBase(uint256 _amount) public {
        
        address[] memory pathSwap = new address[](2);
        
        pathSwap[0] = address(shortToken);
        pathSwap[1] = address(base);
        

        uint256 shortLP = _getShortInLp();
        uint256 baseLP = getBaseInLp();
        uint256 amountOutMin = _amount.mul(baseLP).mul(slippageAdj).div(decimalAdj).div(shortLP);
        EXCHANGE(routerAddress).swapExactTokensForTokens(_amount, amountOutMin, pathSwap, address(this), block.timestamp + 120);
        
    }
    
    function _swapBaseShortExact(uint256 _amountOut) public {
        
        address[] memory pathSwap = new address[](2);
        pathSwap[0] = address(base);
        pathSwap[1] = address(shortToken);
        
        
        uint256 shortLP = _getShortInLp();
        uint256 baseLP = getBaseInLp();
        uint256 amountInMax = _amountOut.mul(baseLP).mul(slippageAdjHigh).div(decimalAdj).div(shortLP);
        EXCHANGE(routerAddress).swapExactTokensForTokens(_amountOut, amountInMax, pathSwap, address(this), block.timestamp + 120);
        
    }
    
    
}
