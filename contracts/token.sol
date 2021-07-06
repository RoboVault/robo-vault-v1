pragma solidity ^0.5.0;


import "./vaultUSDC.sol";
import "./vaultHelpers.sol";



contract rvUSDC is ERC20, ERC20Detailed, ReentrancyGuard, Ownable, vault {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    
    address public strategist;
    address public keeper;
    
    
    uint256 public pool;
    
    
    uint256 lendAllocation = 70;
    uint256 borrowAllocation = 30; 
    
    /// free cash held in base currency as % for speedy withdrawals 
    uint256 freeCashAllocation = 5; 
    /// upper, target and lower bounds for ratio of debt to collateral 
    uint256 collatUpper = 50; 
    uint256 collatTarget = 42 ;
    uint256 collatLower = 35;  
    uint256 debtUpper = 103;
    uint256 debtLower = 97; 
    uint256 harvestFee = 5;

    event UpdatedStrategist(address newStrategist);
    event UpdatedKeeper(address newKeeper);

    // modifiers 
    function _onlyAuthorized() internal {
        require(msg.sender == strategist || msg.sender == owner());
    }

    function _onlyKeepers() internal {
        require(
            msg.sender == keeper ||
                msg.sender == strategist || 
                msg.sender == owner()
        );
    }
    
    /// before withdrawing from strat check there is enough liquidity in lending protocal 
    function _liquidityCheck(uint256 _amount) internal {
        uint256 lendBal = getBaseInLending();
        require(lendBal > _amount, "CREAM Currently has insufficent liquidity of base token to complete withdrawal.");
        
        
    }
    
    /// update strategist -> this is the address that receives fees + can complete rebalancing and update strategy thresholds
    /// strategist can also exit leveraged position i.e. withdraw all pooled LP and repay outstanding debt 
    function setStrategist(address _strategist) external {
        _onlyAuthorized();
        require(_strategist != address(0));
        strategist = _strategist;
        emit UpdatedStrategist(_strategist);
    }
    /// keeper has ability to copmlete rebalancing functions & also deploy capital to strategy once reserves exceed some threshold
    function setKeeper(address _keeper) external {
        _onlyAuthorized();
        require(_keeper != address(0));
        keeper = _keeper;
        emit UpdatedKeeper(_keeper);
    }
    
    function setDebtThresholds(uint256 _lower, uint256 _upper) external {
        _onlyAuthorized();
        require(_lower < 100);
        require(_upper > 100);
        debtUpper = _upper;
        debtLower = _lower;
    }
    
    function setCollateralThresholds(uint256 _lower, uint256 _upper, uint256 _target) external {
        _onlyAuthorized();
        require(75 > _upper);
        require(_upper > _target);
        require(_target > _lower);
        collatUpper = _upper; 
        collatTarget = _target ;
        collatLower = _lower;
    }
    

    
    constructor () public ERC20Detailed("vault USDC", "rvUSDC", 18) {

   
    }
    /// this is the withdrawl fee when user withdrawal results in removal of funds from strategy (i.e. withdrawal in excess of reserves)
    function _calcWithdrawalFee(uint256 _r) internal returns(uint256) {
        uint256 fee = _r.mul(5).div(1000);
        return (fee);
        
    }
    


    /// function to deploy funds when reserves exceed some threshold
    function deployStrat() external {
        _onlyKeepers();
        ///require(msg.sender == owner, 'only admin');
        uint256 bal = base.balanceOf(address(this)); 
        uint256 totalBal = calcPoolValueInToken();
        uint256 freeCash = totalBal.mul(freeCashAllocation).div(100);
        if (bal > freeCash){
            _deployCapital(bal.sub(freeCash));
        }
        
    }
    /// deploy assets according to vault strategy    
    function _deployCapital(uint256 _amount) internal {
        ///require(msg.sender == owner, 'only admin');
        ///uint256 bal = base.balanceOf(address(this)); 
        uint256 lendDeposit = lendAllocation.mul(_amount).div(100);
        _lendBase(lendDeposit); 
        uint256 borrowAmtBase = borrowAllocation.mul(_amount).div(100); 
        uint256 borrowAmt = _borrowBaseEq(borrowAmtBase);
        //_addToLP(borrowAmt);
        //_depoistLp();
    }
    

    // user deposits token to vault in exchange for pool shares which can later be redeemed for assets + accumulated yield
    function deposit(uint256 _amount) external nonReentrant
    {
      require(_amount > 0, "deposit must be greater than 0");
      pool = calcPoolValueInToken();
    
      base.transferFrom(msg.sender, address(this), _amount);
    
      // Calculate pool shares
      uint256 shares = 0;
      if (pool == 0) {
        shares = _amount.div(100);
        pool = _amount;
      } else {
        shares = (_amount.mul(totalSupply())).div(pool);
      }
      pool = calcPoolValueInToken();
      _mint(msg.sender, shares);
    }
    
    // No rebalance implementation for lower fees and faster swaps
    function withdraw(uint256 _shares) public nonReentrant
    {
      require(_shares > 0, "withdraw must be greater than 0");
      
      uint256 ibalance = balanceOf(msg.sender);
      require(_shares <= ibalance, "insufficient balance");
    
      // Could have over value from cTokens
      pool = calcPoolValueInToken();
      // Calc to redeem before updating balances
      uint256 r = (pool.mul(_shares)).div(totalSupply());
      _burn(msg.sender, _shares);
    
      // Check balance
      uint256 b = IERC20(base).balanceOf(address(this));
      if (b < r) {
        /// take withdrawal fee for removing from strat 
        uint256 fee = _calcWithdrawalFee(r);
        r = r.sub(fee);
        _withdrawSome(r.sub(b));
      }
    
      IERC20(base).safeTransfer(msg.sender, r);
      pool = calcPoolValueInToken();
    }
    
    function withdrawAll() public {
        uint256 ibalance = balanceOf(msg.sender);
        withdraw(ibalance);
        
    }

    /// function to remove funds from strategy when users withdraws funds in excess of reserves 
    function _withdrawSome(uint256 _amount) internal {
        require(_amount < calcPoolValueInToken());
        uint256 amt_from_lp = _amount.mul(calcBorrowAllocation()).div(50); 
        uint256 amt_from_lend = _amount.sub(amt_from_lp);
        _liquidityCheck(amt_from_lend);
        uint256 lpValue = balanceLp(); 
        uint256 lpPooled = countLpPooled();
        uint256 lpUnpooled =  lp.balanceOf(address(this)); 
        uint256 lpCount = lpUnpooled.add(lpPooled);
        uint256 lpReq = amt_from_lp.mul(lpCount).div(balanceLp()); 
        uint256 lpWithdraw;
        if (lpReq - lpUnpooled < lpPooled){
            lpWithdraw = lpReq - lpUnpooled;
        } else {
            lpWithdraw = lpPooled;
        }
        _withdrawSomeLp(lpWithdraw);
        _removeAllLp(); 
        _repayDebt(); 
        uint256 redeemAmount = _amount - base.balanceOf(address(this)); 
        _redeemBase(redeemAmount);
    }

    

    /// below function will rebalance collateral to within target range
    function rebalanceCollateral() external {
        _onlyKeepers();      
        uint256 shortPos = balanceDebt(); 
        uint256 lendPos = balanceLend(); 
        uint256 totalBal = calcPoolValueInToken(); 
        uint256 lpBal = balanceLp(); 
        
        /// ratio of amount borrowed to collateral 
        uint256 collatRat = shortPos.div(lendPos).mul(100); 
        
        if (collatRat > collatUpper) {
            uint256 adjAmount = (shortPos.sub(lendPos.mul(collatTarget).div(100))).div(100+collatTarget).mul(100);
            /// remove some LP use 50% of withdrawn LP to repay debt and half to add to collateral 
            _withdrawLpRebalanceCollateral(adjAmount.mul(2));
            
        }
        
        if (collatRat < collatLower) {
            uint256 adjAmount = (lendPos.mul(collatTarget).div(100).sub(shortPos)).div(100+collatTarget).mul(100);
            uint256 borrowAmt = _borrowBaseEq(adjAmount);
            _redeemBase(adjAmount);
            _addToLP(borrowAmt);
            _depoistLp();
        }

    }
    
    /// below function will rebalance debt vs amount of token borrowed in LP 
    function rebalanceDebt() external {
      _onlyKeepers();
      uint256 shortPos = balanceDebt(); 
      uint256 lpPos = balanceLp();
      
      if (calcDebtRatio() < debtLower){
            /// amount of short token in LP is greater than amount borrowed -> 
            /// action = borrow more short token swap half for base token and add to LP + farm
            uint256 borrowAmtBase = lpPos - shortPos.mul(2);
            uint256 borrowAmt = _borrowBaseEq(borrowAmtBase);
            _swapShortBase(borrowAmt.div(2));
            _addToLP(borrowAmt.div(2));
            _depoistLp();
    
    
      }
      
      if (calcDebtRatio() > debtUpper){
            /// amount of short token in LP is less than amount borrowed -> 
            /// action = remove some LP -> repay debt + add base token to collateral 
            uint256 baseValueAdj = shortPos.mul(2) - lpPos;
            _withdrawLpRebalance(baseValueAdj);
    
      }
    
      
    }
    
    /// called by keeper to harvest rewards and either repay debt or add to reserves 
    function harvest_strat() external {
        
        /// harvest from farm & based on amt borrowed vs LP value either -> repay some debt or add to collateral
        _onlyKeepers();
        FARM(farm).deposit(pid, 0);
        uint256 shortPos = balanceDebt();
        
        if (calcDebtRatio() < 100){
            /// more 
            uint256 lendAdd = _sellHarvestBase();
            uint256 fee = lendAdd.mul(harvestFee).div(100);
            base.safeTransfer(strategist, fee);

            //_lendBase(lendAdd.sub(fee)); 
            
        } else {
            _sellHarvestShort(); 
            uint256 fee = shortToken.balanceOf(address(this)).mul(harvestFee).div(100);
            shortToken.safeTransfer(strategist, fee);
            _repayDebt();
        }
        
    }
    
    function getPricePerFullShare() public view returns(uint256) {
        uint256 bal = calcPoolValueInToken();
        uint256 supply = totalSupply();
        return bal.div(supply);
    }

    

    // remove all of Vaults LP tokens and repay debt meaning vault only holds base token (in lending + reserves)
    function exitLeveragePosition() internal {
        _withdrawAllPooled();
        _removeAllLp();
        _repayDebt(); 
        
        if (balanceDebt() > 0){
            uint256 debtOutstanding = BORROW(borrow_platform).borrowBalanceStored(address(this));
            _swapBaseShortExact(debtOutstanding);
            _repayDebt();

        } else {
            _swapShortBase(shortToken.balanceOf(address(this))); 
        }
    }
    // exits all positions so vault only holds base token
    function exitPositionsAll() external {
        _onlyAuthorized();
        exitLeveragePosition();
        _redeemBase(balanceLend());
    }
    
    // exits leverage position and moves all funds to lending protocal
    function exitPositionsLP() external {
        _onlyAuthorized();
        exitLeveragePosition();
        _lendBase(base.balanceOf(address(this)));
    }
    

}