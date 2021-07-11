pragma solidity ^0.5.0;
import "../vaultHelpers.sol";
import "../farms/spirit.sol";
import "../lenders/cream.sol";
import "../token.sol";

contract rbUSDCSpirit is ERC20, ERC20Detailed, Token {
    using SafeMath for uint256;
    IFarm farm = new Spirit();
    ILend lend = new Cream();
    address constant WBTC = 0x321162Cd933E2Be498Cd2267a90534A804051b11;
    address constant WFTM = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;

    constructor(ERC20Detailed obj) public 
        ERC20Detailed("Robo Vault BTC Spirit", "rvBTCa", 18)
        Token(farm, lend, WBTC, WFTM)
    {}
}

        