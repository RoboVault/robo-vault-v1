// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "./vaultHelpers.sol";
import "./farms/ifarm.sol";
import "./lenders/ilend.sol";

interface Icomptroller {
  function enterMarkets(address[] calldata cTokens) external returns (uint[] memory);
}

abstract contract RoboVault is ERC20, ERC20Detailed, ILend, IFarm {
    /// functionality allowing Robo Vault vaults to interaction with other contracts such as lending, creating LP & harvesting rewards  
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    uint256 constant decimalAdj = 1000000; // variable used when calculating (equivant to 1 / 100% for float like operations )
    uint256 constant slippageAdj = 990000;
    uint256 constant slippageAdjHigh = 1010000;

    IERC20 base;
    IERC20 shortToken;
    IERC20 lp = IERC20(farmLP());
    IERC20 lp_harvestToken = IERC20(farmTokenLp());
    IERC20 harvestToken = IERC20(farmToken());
    IERC20 lend_tokens = IERC20(lendPlatform());

    constructor(address _baseToken, address _shortToken) public {
        base = IERC20(_baseToken);
        shortToken = IERC20(_shortToken);

        Icomptroller comptroller = Icomptroller(comptrollerAddress());
        address[] memory cTokens = new address[](1);
        cTokens[0] = lendPlatform();
        comptroller.enterMarkets(cTokens);
    }
    
    /// calculate total value of vault assets 
    function calcPoolValueInToken() public view returns(uint256){
        uint256 lpvalue = balanceLp();
        uint256 collateral = balanceLend();
        uint256 reserves = balanceReserves();
        uint256 debt = balanceDebt();
        uint256 shortInWallet = balanceShortBaseEq(); 
        uint256 pendingRewards = balancePendingHarvest();
        return (reserves + collateral +  lpvalue - debt + shortInWallet + pendingRewards) ; 
    }

    // debt ratio - used to trigger rebalancing of debt 
    function calcDebtRatio() public view returns(uint256){
        uint256 debt = balanceDebt();
        uint256 lpvalue = balanceLp();
        uint256 debtRatio = debt.mul(decimalAdj).mul(2).div(lpvalue); 
        return (debtRatio);
    }

    // calculate debt / collateral - used to trigger rebalancing of debt & collateral 
    function calcCollateral() public view returns(uint256){
        uint256 debt = balanceDebt();
        uint256 collateral = balanceLend();
        uint256 collatRatio = debt.mul(decimalAdj).div(collateral); 
        return (collatRatio);
    }

    // current % of vault assets held in reserve - used to trigger deployment of assets into strategy
    function calcReserves() public view returns(uint256){
        uint256 bal = base.balanceOf(address(this)); 
        uint256 totalBal = calcPoolValueInToken();
        uint256 reservesRatio = bal.mul(decimalAdj).div(totalBal);
        return (reservesRatio); 
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
        uint256 debt = borrowBalanceStored(address(this));
        return (debt.mul(baseLP).div(shortLP));
    }
    
    function balancePendingHarvest() public view returns(uint256){
        uint256 rewardsPending = farmPendingRewards(farmPid(), address(this));
        uint256 harvestLP_A = _getHarvestInHarvestLp();
        uint256 shortLP_A = _getShortInHarvestLp();
        uint256 shortLP_B = _getShortInLp();
        uint256 baseLP_B = getBaseInLp();
        uint256 balShort = rewardsPending.mul(shortLP_A).div(harvestLP_A);
        uint256 balRewards = balShort.mul(baseLP_B).div(shortLP_B);
        return (balRewards);
    }
    
    // reserves 
    function balanceReserves() public view returns(uint256){
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
        return (b.mul(lendExchangeRateStored()).div(1e18));
    }

    // lend base tokens to lending platform 
    function _lendBase(uint256 amount) internal {
        lendMint(amount);
    }
    
    // borrow tokens woth _amount of base tokens 
    function _borrowBaseEq(uint256 _amount) internal returns(uint256) {
        uint256 shortLP = _getShortInLp();
        uint256 baseLP = getBaseInLp();
        uint256 borrowamount = _amount.mul(shortLP).div(baseLP);
        _borrow(borrowamount);
        return (borrowamount);
    }

    function _borrow(uint256 borrowAmount) internal {
        borrow(borrowAmount);
    }
    
    // automatically repays debt using any short tokens held in wallet up to total debt value
    function _repayDebt() internal {
        uint256 _bal = shortToken.balanceOf(address(this)); 
        uint256 _debt =  borrowBalanceStored(address(this)); 
        if (_bal < _debt){
            borrowRepay(_bal);
        }
        else {
            borrowRepay(_debt);
        }
    }
    
    function calcBorrowAllocation() public view returns (uint256){
        uint256 balLend = balanceLend();
        uint256 balLp = balanceLp(); 
        uint256 borrowAllocation = balLp.mul(decimalAdj).div(balLend.add(balLp.div(2))).div(2);
        return (borrowAllocation);
        
    }
    
    function getDebtShort() public view returns(uint256) {
        uint256 _debt =  borrowBalanceStored(address(this)); 
        return(_debt);
    }
    
    function _getShortInLp() internal view returns (uint256) {
        uint256 short_lp = shortToken.balanceOf(address(lp)) ; 
        return (short_lp);          
    }
    
    function getBaseInLending() public view returns (uint256) {
        uint256 bal = base.balanceOf(lendPlatform());
        return(bal);
    }
    
    function getBaseInLp() public view returns (uint256) {
        uint256 base_lp = base.balanceOf(address(lp)) ;
        return (base_lp);
    }
    
    function _getHarvestInHarvestLp() internal view returns(uint256) {
        uint256 harvest_lp = harvestToken.balanceOf(farmTokenLp());
        return harvest_lp;          
    }
    
    function _getShortInHarvestLp() internal view returns(uint256) {
        uint256 shortToken_lp = shortToken.balanceOf(farmTokenLp());
        return shortToken_lp;          
    }
    
    function _redeemBase(uint256 _redeem_amount) internal {
        lendRedeemUnderlying(_redeem_amount); 
    }

    function countLpPooled() public view returns(uint256){
        uint256 lpPooled = farmUserInfo(farmPid(), address(this));
        return lpPooled;
    }
    
    // withdraws some LP worth _amount, converts all withdrawn LP to short token to repay debt 
    function _withdrawLpRebalance(uint256 _amount) public {
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
    function _withdrawLpRebalanceCollateral(uint256 _amount) internal {
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
        farmAddLiquidity(address(shortToken), address(base), amountADesired, amountBDesired, amountAMin, amountBMin, address(this), block.timestamp + 15); /// add liquidity 
    }
    
    function _addToLP(uint256 _amountShort) internal {
        uint256 shortLP = _getShortInLp();
        uint256 baseLP = getBaseInLp();
        uint256 _amountBase = _amountShort.mul(baseLP).div(shortLP);
        _addToLpFull(_amountShort, _amountBase, _amountShort, _amountBase.mul(slippageAdj).div(decimalAdj));
    }
    
    function _depoistLp() internal {
        uint256 lpBalance = lp.balanceOf(address(this)); /// get number of LP tokens
        farmDeposit(farmPid(), lpBalance); /// deposit LP tokens to farm
    }

    function _withdrawSomeLp(uint256 _amount) internal {
        require(_amount <= countLpPooled());
        farmWithdraw(farmPid(), _amount);
    }
    
    // all LP currently not in Farm is removed 
    function _removeAllLp() internal {
        ///require(msg.sender == owner, 'only admin'); 
        uint256 _amount = lp.balanceOf(address(this));
        uint256 shortLP = _getShortInLp();
        uint256 baseLP = getBaseInLp();
        uint256 lpIssued = lp.totalSupply();

        uint256 amountAMin = _amount.mul(shortLP).div(lpIssued).mul(slippageAdj).div(decimalAdj);
        uint256 amountBMin = _amount.mul(baseLP).div(lpIssued).mul(slippageAdj).div(decimalAdj);
        farmRemoveLiquidity(address(shortToken), address(base), _amount, amountAMin, amountBMin,address(this), block.timestamp + 15);
    }
    
    function _withdrawAllPooled() internal {
        ///require(msg.sender == owner, 'only admin'); 
        uint256 lpPooled = countLpPooled();
        farmWithdraw(farmPid(), lpPooled);
    }
    
    // below functions interact with AMM converting Harvest Rewards & Swapping between base & short token as required for rebalancing 
    function _sellHarvestBase() internal returns (uint256) {
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
        farmSwapExactTokensForTokens(harvestBalance, amountOutMin, pathBase, address(this), block.timestamp + 120);
        return (amountOutMin);
    }

    function _sellHarvestShort() internal {
        address[] memory pathShort = new address[](2);
        pathShort[0] = address(harvestToken);
        pathShort[1] = address(shortToken);

        uint256 harvestBalance = harvestToken.balanceOf(address(this)); 
        uint256 harvestLP = _getHarvestInHarvestLp();
        uint256 shortLP = _getShortInHarvestLp();
        uint256 amountOutMin = harvestBalance.mul(shortLP).mul(slippageAdj).div(harvestLP).div(decimalAdj);
        farmSwapExactTokensForTokens(harvestBalance, amountOutMin, pathShort, address(this), block.timestamp + 120);
    }

    function _swapBaseShort(uint256 _amount) internal {
        address[] memory pathSwap = new address[](2);
        pathSwap[0] = address(base);
        pathSwap[1] = address(shortToken);

        uint256 shortLP = _getShortInLp();
        uint256 baseLP = getBaseInLp();
        uint256 amountOutMin = _amount.mul(shortLP).mul(slippageAdj).div(baseLP).div(decimalAdj);
        farmSwapExactTokensForTokens(_amount, amountOutMin, pathSwap, address(this), block.timestamp + 120);
    }
    
    function _swapShortBase(uint256 _amount) internal {
        address[] memory pathSwap = new address[](2);
        pathSwap[0] = address(shortToken);
        pathSwap[1] = address(base);

        uint256 shortLP = _getShortInLp();
        uint256 baseLP = getBaseInLp();
        uint256 amountOutMin = _amount.mul(baseLP).mul(slippageAdj).div(decimalAdj).div(shortLP);
        farmSwapExactTokensForTokens(_amount, amountOutMin, pathSwap, address(this), block.timestamp + 120);
    }
    
    function _swapBaseShortExact(uint256 _amountOut) internal {
        address[] memory pathSwap = new address[](2);
        pathSwap[0] = address(base);
        pathSwap[1] = address(shortToken);
        
        uint256 shortLP = _getShortInLp();
        uint256 baseLP = getBaseInLp();
        uint256 amountInMax = _amountOut.mul(baseLP).mul(slippageAdjHigh).div(decimalAdj).div(shortLP);
        farmSwapExactTokensForTokens(_amountOut, amountInMax, pathSwap, address(this), block.timestamp + 120);
    }
}

