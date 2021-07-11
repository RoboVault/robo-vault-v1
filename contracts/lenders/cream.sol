pragma solidity ^0.5.0;
import "../vaultHelpers.sol";

interface BORROW {
    /// interface for borrowing from CREAM
    function borrow(uint256 borrowAmount) external returns (uint256); 
    function borrowBalanceStored(address account) external view returns (uint);
    function repayBorrow(uint repayAmount) external ; /// borrowAmount: The amount of the underlying borrowed asset to be repaid. A value of -1 (i.e. 2^256 - 1) can be used to repay the full amount.
}

contract Lend {
    using SafeMath for uint256;
    
    /// base token specific info
    // address WBTC = 0x321162Cd933E2Be498Cd2267a90534A804051b11;
    // address lendPlatform = 0x20CA53E2395FA571798623F1cFBD11Fe2C114c24; // platform for addding base token as collateral
    // address LP = 0x279b2c897737a50405ED2091694F225D83F2D3bA; /// LP contract for wbtc & wftm 
    // uint256 pid  =  2; 
    // IERC20 base = IERC20(WBTC);
    
    // address WFTM = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;
    address borrow_platform = 0xd528697008aC67A21818751A5e3c58C8daE54696;
    // address comptrollerAddress = 0x4250A6D3BD57455d7C6821eECb6206F507576cD2; /// Cream Comptroller 
    // address SpiritRouter = 0x16327E3FbDaCA3bcF7E38F5Af2599D2DDc33aE52;
    // address SpiritMaster = 0x9083EA3756BDE6Ee6f27a6e996806FBD37F6F093;
    // address routerAddress = SpiritRouter; 
    // address farm = SpiritMaster; /// spirit masterchef 
    // address Spirit = 0x5Cc61A78F164885776AA610fb0FE1257df78E59B; 
    // address SpiritLP = 0x30748322B6E34545DBe0788C421886AEB5297789;
    
    // IERC20 shortToken = IERC20(WFTM);
    // IERC20 lp = IERC20(LP);
    // IERC20 lp_harvestToken = IERC20(SpiritLP); 
    // IERC20 harvestToken = IERC20(Spirit);
    // IERC20 lend_tokens = IERC20(lendPlatform);
    // function borrowBalanceStored(address account) external view returns (uint)

    
}

        