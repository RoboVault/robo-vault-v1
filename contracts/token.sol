pragma solidity ^0.5.0;


import "./vaultFtm.sol";
import "./vaultHelpers.sol";


/*
interface IIEarnManager {
    function recommend(address _token) external view returns (
      string memory choice,
      uint256 capr,
      uint256 iapr,
      uint256 aapr,
      uint256 dapr
    );
}

contract Structs {
    struct Val {
        uint256 value;
    }

    enum ActionType {
        Deposit,   // supply tokens
        Withdraw  // borrow tokens
    }

    enum AssetDenomination {
        Wei // the amount is denominated in wei
    }

    enum AssetReference {
        Delta // the amount is given as a delta from the current value
    }

    struct AssetAmount {
        bool sign; // true if positive
        AssetDenomination denomination;
        AssetReference ref;
        uint256 value;
    }

    struct ActionArgs {
        ActionType actionType;
        uint256 accountId;
        AssetAmount amount;
        uint256 primaryMarketId;
        uint256 secondaryMarketId;
        address otherAddress;
        uint256 otherAccountId;
        bytes data;
    }

    struct Info {
        address owner;  // The address that owns the account
        uint256 number; // A nonce that allows a single address to control many accounts
    }

    struct Wei {
        bool sign; // true if positive
        uint256 value;
    }
}
*/


contract rvUSDC is ERC20, ERC20Detailed, ReentrancyGuard, Ownable, vault {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    
    uint256 public pool;
    
    uint256 lendAllocation = 70;
    uint256 borrowAllocation = 30; 
    
    /// free cash held in base currency as % for speedy withdrawals 
    uint256 freeCashAllocation = 5; 
    /// upper, target and lower bounds for ratio of debt to collateral 
    uint256 collatUpper = 50; 
    uint256 collatTarget = 42 ;
    uint256 collatLower = 35;  
    uint256 debtBuffer = 3; /// buffer of % difference between debt position and LP before rebalance
    
    
    constructor () public ERC20Detailed("vault USDC", "rvUSDC", 18) {
        address _owner = msg.sender;

    
    }
    
    function deploy_strat() public {
        ///require(msg.sender == owner, 'only admin');
        uint256 bal = base.balanceOf(address(this)); 
        uint256 totalBal = calcPoolValueInToken();
        uint256 freeCash = totalBal.mul(freeCashAllocation).div(100);
        if (bal > freeCash){
            _deploy_capital(bal.sub(freeCash));
        }
        
    }
        
    function _deploy_capital(uint256 _amount) internal {
        ///require(msg.sender == owner, 'only admin');
        ///uint256 bal = base.balanceOf(address(this)); 
        uint256 lendDeposit = lendAllocation.mul(_amount).div(100);
        _lendBase(lendDeposit); 
        uint256 borrow_amt_base = borrowAllocation.mul(_amount).div(100); 
        uint256 borrow_amt = _borrow_base_eq(borrow_amt_base);
        _add_to_LP(borrow_amt);
        depoistLp();
    }
    
    function approveBase(uint256 _amount) external {
        IERC20(base).approve(address(this), _amount);
    }

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
    function withdraw(uint256 _shares) external nonReentrant
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
        _withdrawSome(r);
      }
    
      IERC20(base).safeTransfer(msg.sender, r);
      pool = calcPoolValueInToken();
    }
    
    function _withdrawSome(uint256 _amount) public {
        require(_amount < calcPoolValueInToken());
        uint256 amt_from_lp = _amount.sub(base.balanceOf(address(this))).mul(borrowAllocation).div(50); 
        uint256 lpValue = balanceLp(); 
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
        _repay_debt(); 
        uint256 redeemAmount = _amount - base.balanceOf(address(this)); 
        _redeem_base(redeemAmount);
    }
    

    /// below function will rebalance collateral to within target range
    function rebalanceCollateral() public {
      
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
            uint256 borrow_amt = _borrow_base_eq(adjAmount);
            _redeem_base(adjAmount);
            _add_to_LP(borrow_amt);
            depoistLp();
        }

    }
    
    /// below function will rebalance debt vs amount of token borrowed in LP 
    function rebalanceDebt() public {
      uint256 shortPos = balanceDebt(); 
      uint256 lpPos = balanceLp();
      
      if (lpPos.div(2) > shortPos.mul(100 + debtBuffer).div(100)){
            /// amount of short token in LP is greater than amount borrowed -> 
            /// action = borrow more short token swap half for base token and add to LP + farm
            uint256 borrow_amt_base = lpPos - shortPos.mul(2);
            uint256 borrow_amt = _borrow_base_eq(borrow_amt_base);
            _swap_short_for_base(borrow_amt.div(2));
            _add_to_LP(borrow_amt.div(2));
            depoistLp();
    
    
      }
      
      if (lpPos.div(2) < shortPos.mul(100 - debtBuffer).div(100)){
            /// amount of short token in LP is less than amount borrowed -> 
            /// action = remove some LP -> repay debt + add base token to collateral 
            uint256 baseValueAdj = shortPos.mul(2) - lpPos;
            _withdrawLpRebalance(baseValueAdj);
    
      }
    
      
    }
    
    function getPricePerFullShare() public view returns(uint256) {
        uint256 bal = calcPoolValueInToken();
        uint256 supply = totalSupply();
        return bal.div(supply);
        
    }
    /*
    function removeShortPosition() internal {
          
        /// withdraws all LP from farm -> converts to tokens -> repays debt -> if still outstanding debt converts some of base token to short token & repays -> 
          
        _withdrawAllPooled();
        _removeAllLp();
        _repay_debt(); 
        
        if (balanceDebt() > 0){
            _swap_base_for_short(balanceDebt());
            _repay_debt();
            /// still some debt to repay afetr removing LP 
            
        } else {
            _swap_short_for_base(short_token.balanceOf(address(this))); 
        }
    }
    */
    

}