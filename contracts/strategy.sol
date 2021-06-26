pragma solidity ^0.5.0;

import "./base_contract.sol";
/*
///import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
///import '@openzeppelin/contracts/utils/math/SafeMath.sol';
*/

contract Vault is vaultHelper {
    using SafeMath for uint256;
    uint256 lendAllocation = 60;
    uint256 borrowAllocation = 30; 
    uint256 lpAllocation = 60; 
    uint256 maxCollateral = 65; 
    uint256 targetCollateral = 50; 
    uint256 minCollateral = 35;
    ///address wftm = 0x21be370d5312f44cb42ce377bc9b8a0cef1a4c83

    constructor() internal {
        owner = msg.sender;
    }
    /// function to deploy initial capital in contract 
    function deploy_capital() external {
        require(msg.sender == owner, 'only admin');
        uint256 bal = base.balanceOf(address(this)); 
        uint256 lendDeposit = lendAllocation.mul(bal).div(100);
        ///lend.approve(address(usdc), lendDeposit);
        _lend_base(lendDeposit); 
        uint256 shortPrice = _get_short_price();
        uint256 borrowamount = borrowAllocation.mul(bal).div(100).div(shortPrice);
        _borrow(borrowamount); 
        /// _add_to_LP(borrowamount, borrowamount.mul(shortPrice).mul(1.01), borrowamount, borrowamount.mul(shortPrice).mul(.99)); 
        /// _depoistLp();         
    }

    function rebalance_collateral() external {
        require(msg.sender == owner, 'only admin');
        uint256 collateralRatio = _get_collateral_ratio(); 
        uint256 shortPrice = _get_short_price();
        /// scenario -> debt / collateral < low threshold = borrow more & add to LP 
        if (collateralRatio < minCollateral){
            uint256 adj = targetCollateral - collateralRatio;
            uint256 bal = get_total_balance();
            uint256 adjAmount =  bal.mul(adj).div(100).div(2); 
            uint256 exchangeRate = LEND(lend_platform).exchangeRateCurrent();
            LEND(lend_platform).redeem(adjAmount.mul(exchangeRate)); 
            uint256 borrowAmount = adjAmount.div(shortPrice);
            _borrow(borrowAmount);
            /// _add_to_LP(borrowAmount, borrowAmount.mul(shortPrice).mul(1.01), borrowAmount, borrowAmount.mul(shortPrice).mul(.99));
            /// _depoistLp();  
        }
        /// scenario -> debt / collateral > high threshold = remove some LP & 
        if (collateralRatio > minCollateral){
            uint256 adj =  collateralRatio - targetCollateral;
            uint256 bal = get_total_balance();
            uint256 adjAmount =  bal.mul(adj).div(100);
            uint256 lpValue = _get_lp_position(lpPooled); 
            /// uint256 lpRemove = lpPooled.mul(adjAmount).div(lpValue); 
            /// _withdrawSomeLp(lpRemove);
            /// _removeLp();
            /// _repay_debt();
            /// _lend_base(adjAmount.div(2));
            
        }

        // scenario -> debt ftm > in LP  ... (want to repay debt) a) -> use cash reserves b) remove collateral and repay some debt c)  
        // scenario -> debt ftm < in LP ... (want to borrow more) a) -> borrow + add to cash reserves b) borrow + add to LP 




    }

}


