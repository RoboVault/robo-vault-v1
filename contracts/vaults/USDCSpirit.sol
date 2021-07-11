pragma solidity ^0.5.0;
import "../vaultHelpers.sol";
import "../farms/spirit.sol";
import "../lenders/cream.sol";
import "../token.sol";

contract rbUSDCSpirit is ERC20, ERC20Detailed, Token {
    address constant USDC = 0x04068DA6C83AFCFA0e13ba15A6696662335D5B75;
    address constant WFTM = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;

    constructor() public 
        ERC20Detailed("Robo Vault USDC Spirit", "rvUSDCa", 18)
        Token(new Spirit(), new Cream(), USDC, WFTM)
    {}
}

        