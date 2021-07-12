pragma solidity ^0.5.0;

import "./vault.sol";
import "./vaultHelpers.sol";
import "./farms/ifarm.sol";
import "./lenders/ilend.sol";


contract Token is ReentrancyGuard, Ownable, Vault {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    
    address public strategist = 0xD074CDae76496d81Fab83023fee4d8631898bBAf;
    address public keeper = 0x7642604866B546b8ab759FceFb0C5c24b296B925;
    /// default allocations, thresholds & fees
    uint256 public stratLendAllocation = 650000;
    uint256 public stratDebtAllocation = 350000; 
    uint256 public collatUpper = 600000; 
    uint256 public collatTarget = 530000;
    uint256 public collatLower = 450000;  
    uint256 public debtUpper = 1030000;
    uint256 public debtLower = 970000;
    uint256 public harvestFee = 50000;
    uint256 public withdrawalFee = 5000;
    uint256 public reserveAllocation = 50000;

    /// protocal limits & upper, target and lower thresholds for ratio of debt to collateral 
    uint256 constant collatLimit = 750000;
    /// upper limit for fees so owner cannot maliciously increase fees
    uint256 constant harvestFeeLimit = 50000;
    uint256 constant withdrawalFeeLimit = 5000; /// only applies when funds are removed from strat & not reserves
    uint256 constant reserveAllocationLimit =  50000; 

    event UpdatedStrategist(address newStrategist);
    event UpdatedKeeper(address newKeeper);
    
    constructor (address _base, address _short) public 
        Vault(_base, _short) 
    {
    }

    // modifiers 
    function _onlyAuthorized() internal view {
        require(msg.sender == strategist || msg.sender == owner());
    }

    function _onlyKeepers() internal view {
        require(
            msg.sender == keeper ||
            msg.sender == strategist || 
            msg.sender == owner()
        );
    }
    
    /// before withdrawing from strat check there is enough liquidity in lending protocal 
    function _liquidityCheck(uint256 _amount) internal view {
        uint256 lendBal = getBaseInLending();
        require(lendBal > _amount, "CREAM Currently has insufficent liquidity of base token to complete withdrawal.");
        
        
    }
    
    function approveContracts() external {
        _onlyAuthorized();
        base.safeApprove(lendPlatform(), uint256(-1));
        shortToken.safeApprove(borrowPlatform(), uint256(-1));
        base.safeApprove(routerAddress(), uint256(-1));
        shortToken.safeApprove(routerAddress(), uint256(-1));
        harvestToken.safeApprove(routerAddress(), uint256(-1));
        lp.safeApprove(routerAddress(), uint256(-1));
        lp.approve(farmAddress(), uint256(-1));
    }
        
    function resetApprovals( ) external {
        _onlyAuthorized();
        base.safeApprove(lendPlatform(), 0);
        shortToken.safeApprove(borrowPlatform(), 0);
        base.safeApprove(routerAddress(), 0);
        shortToken.safeApprove(routerAddress(), 0);
        harvestToken.safeApprove(routerAddress(), 0);
        lp.safeApprove(routerAddress(), 0);
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
        require(_lower < decimalAdj);
        require(_upper > decimalAdj);
        debtUpper = _upper;
        debtLower = _lower;
    }
    
    function setCollateralThresholds(uint256 _lower, uint256 _upper, uint256 _target) external {
        _onlyAuthorized();
        require(collatLimit > _upper);
        require(_upper > _target);
        require(_target > _lower);
        collatUpper = _upper; 
        collatTarget = _target ;
        collatLower = _lower;
    }
    
    function setFundingAllocations(uint256 _reserveAllocation, uint256 _lendAllocation) external {
        _onlyAuthorized();
        
        uint256 _debtAllocation = decimalAdj.sub(_lendAllocation); 
        uint256 impliedCollatRatio = _debtAllocation.mul(decimalAdj).div(_lendAllocation);
        
        require(_reserveAllocation < reserveAllocationLimit); 
        require(impliedCollatRatio < collatLimit);
        reserveAllocation = _reserveAllocation;
        stratLendAllocation = _lendAllocation;
        stratDebtAllocation = _debtAllocation; 
        
    }
    
    function setFees(uint256 _withdrawalFee, uint256 _harvestFee) external {
        _onlyAuthorized();
        require(_withdrawalFee < withdrawalFeeLimit);
        require(_harvestFee < harvestFeeLimit);
        harvestFee = _harvestFee;
        withdrawalFee = _withdrawalFee; 
    }
    /// this is the withdrawl fee when user withdrawal results in removal of funds from strategy (i.e. withdrawal in excess of reserves)
    function _calcWithdrawalFee(uint256 _r) internal view returns(uint256) {
        uint256 _fee = _r.mul(withdrawalFee).div(decimalAdj);
        return(_fee);
    }
    


    /// function to deploy funds when reserves exceed some threshold
    function deployStrat() external {
        _onlyKeepers();
        ///require(msg.sender == owner, 'only admin');
        uint256 bal = base.balanceOf(address(this)); 
        uint256 totalBal = calcPoolValueInToken();
        uint256 reserves = totalBal.mul(reserveAllocation).div(decimalAdj);
        if (bal > reserves){
            _deployCapital(bal.sub(reserves));
        }
        
    }
    /// deploy assets according to vault strategy    
    function _deployCapital(uint256 _amount) internal {
        ///require(msg.sender == owner, 'only admin');
        ///uint256 bal = base.balanceOf(address(this)); 
        uint256 lendDeposit = stratLendAllocation.mul(_amount).div(decimalAdj);
        _lendBase(lendDeposit); 
        uint256 borrowAmtBase = stratDebtAllocation.mul(_amount).div(decimalAdj); 
        uint256 borrowAmt = _borrowBaseEq(borrowAmtBase);
        _addToLP(borrowAmt);
        _depoistLp();
    }
    

    // user deposits token to vault in exchange for pool shares which can later be redeemed for assets + accumulated yield
    function deposit(uint256 _amount) external nonReentrant
    {
      require(_amount > 0, "deposit must be greater than 0");
      uint256 pool = calcPoolValueInToken();
    
      base.transferFrom(msg.sender, address(this), _amount);
    
      // Calculate pool shares
      uint256 shares = 0;
      if (totalSupply() == 0) {
        shares = _amount;
      } else {
        shares = (_amount.mul(totalSupply())).div(pool);
      }
      _mint(msg.sender, shares);
    }
    
    // No rebalance implementation for lower fees and faster swaps
    function withdraw(uint256 _shares) public nonReentrant
    {
      require(_shares > 0, "withdraw must be greater than 0");
      
      uint256 ibalance = balanceOf(msg.sender);
      require(_shares <= ibalance, "insufficient balance");
      uint256 pool = calcPoolValueInToken();
      // Calc to redeem before updating balances
      uint256 r = (pool.mul(_shares)).div(totalSupply());
      _burn(msg.sender, _shares);
    
      // Check balance
      uint256 b = IERC20(base).balanceOf(address(this));
      if (b < r) {
        /// take withdrawal fee for removing from strat 
        uint256 fee = _calcWithdrawalFee(r);
        r = r.sub(fee);
        _withdrawSome(r);
      }
    
      IERC20(base).safeTransfer(msg.sender, r);
    }
    
    function withdrawAll() public {
        uint256 ibalance = balanceOf(msg.sender);
        withdraw(ibalance);
        
    }

    /// function to remove funds from strategy when users withdraws funds in excess of reserves 
    function _withdrawSome(uint256 _amount) public {
        uint256 balTotal = calcPoolValueInToken();
        uint256 balunPooled = balTotal.sub(base.balanceOf(address(this)));
        uint256 amtFromStrat = _amount.sub(base.balanceOf(address(this)));
        
        
        require(_amount <= calcPoolValueInToken());
        uint256 stratPercent = amtFromStrat.mul(decimalAdj).div(balunPooled);
        uint256 lpPooled = countLpPooled();
        uint256 lpUnpooled =  lp.balanceOf(address(this)); 
        uint256 lpCount = lpUnpooled.add(lpPooled);
        uint256 lpReq = lpCount.mul(stratPercent).div(decimalAdj); 
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
        
        /// need to add a check for collateral ratio after redeeming 
        uint256 postRedeemCollateral = (balanceDebt()).mul(decimalAdj).div(balanceLend().sub(redeemAmount));
        if (postRedeemCollateral < collatLimit){
            _redeemBase(redeemAmount);
        }
        else {
            uint256 subAmt = collatUpper.mul(balanceLend().sub(redeemAmount));
            uint256 numerator = balanceDebt().mul(decimalAdj).sub(subAmt);
            uint256 denominator = decimalAdj.sub(collatUpper); 
            
            _swapBaseShortExact(numerator.div(denominator)); 
            _repayDebt();
            redeemAmount = _amount - base.balanceOf(address(this));
            _redeemBase(redeemAmount);
        }
        
        
    }

    

    /// below function will rebalance collateral to within target range
    function rebalanceCollateral() external {
        _onlyKeepers();
        uint256 shortPos = balanceDebt();
        uint256 lendPos = balanceLend();
        
        /// ratio of amount borrowed to collateral 
        uint256 collatRat = calcCollateral(); 
        
        if (collatRat > collatUpper) {
            uint256 adjAmount = (shortPos.sub(lendPos.mul(collatTarget).div(decimalAdj))).mul(decimalAdj).div(decimalAdj.add(collatTarget));
            /// remove some LP use 50% of withdrawn LP to repay debt and half to add to collateral 
            _withdrawLpRebalanceCollateral(adjAmount.mul(2));
            
        }
        
        if (collatRat < collatLower) {
            uint256 adjAmount = ((lendPos.mul(collatTarget).div(decimalAdj)).sub(shortPos)).mul(decimalAdj).div(decimalAdj.add(collatTarget));
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
            uint256 borrowAmtBase = lpPos.sub(shortPos.mul(2));
            uint256 borrowAmt = _borrowBaseEq(borrowAmtBase);
            _swapShortBase(borrowAmt.div(2));
            _addToLP(borrowAmt.div(2));
            _depoistLp();
    
    
      }
      
      if (calcDebtRatio() > debtUpper){
            /// amount of short token in LP is less than amount borrowed -> 
            /// action = remove some LP -> repay debt + add base token to collateral 
            uint256 baseValueAdj = (shortPos.mul(2)).sub(lpPos);
            _withdrawLpRebalance(baseValueAdj);
      }      
    }
    
    /// called by keeper to harvest rewards and either repay debt or add to reserves 
    function harvestStrat() external {
        
        /// harvest from farm & based on amt borrowed vs LP value either -> repay some debt or add to collateral
        _onlyKeepers();
        farmWithdraw(farmPid(), 0); /// for spooky swap call withdraw with amt = 0
        
        if (calcDebtRatio() < decimalAdj){
            /// more 
            uint256 lendAdd = _sellHarvestBase();
            uint256 fee = lendAdd.mul(harvestFee).div(decimalAdj);
            base.safeTransfer(strategist, fee);

            //_lendBase(lendAdd.sub(fee)); 
            
        } else {
            _sellHarvestShort(); 
            uint256 fee = shortToken.balanceOf(address(this)).mul(harvestFee).div(decimalAdj);
            shortToken.safeTransfer(strategist, fee);
            _repayDebt();
        }
        
    }
    
    function getPricePerFullShare() public view returns(uint256) {
        uint256 bal = calcPoolValueInToken();
        uint256 supply = totalSupply();
        return bal.mul(decimalAdj).div(supply);
    }
    

    // remove all of Vaults LP tokens and repay debt meaning vault only holds base token (in lending + reserves)
    function exitLeveragePosition() internal {
        _withdrawAllPooled();
        _removeAllLp();
        _repayDebt(); 
        
        if (getDebtShort() > 0){
            uint256 debtOutstanding = borrowBalanceStored(address(this));
            _swapBaseShortExact(debtOutstanding);
            _repayDebt();

        } else {
            if (shortToken.balanceOf(address(this)) > 0) {
            _swapShortBase(shortToken.balanceOf(address(this))); 
            }
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