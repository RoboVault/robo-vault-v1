pragma solidity ^0.5.0;
import "../vaultHelpers.sol";
import "../farms/spooky.sol";
import "../lenders/cream.sol";
import "../token.sol";

contract rbUSDCSpooky is ERC20, ERC20Detailed, Token {
    using SafeMath for uint256;
    Spooky farm = new Spooky();
    Cream lend = new Cream();
    address constant USDC = 0x04068DA6C83AFCFA0e13ba15A6696662335D5B75;
    address constant WFTM = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;

    constructor() public 
        ERC20Detailed("Robo Vault USDC Spooky", "rvUSDCb", 18)
        Token(farm, lend, USDC, WFTM)
    {}
}

        