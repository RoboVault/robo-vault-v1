// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "../vaultHelpers.sol";
import "../farms/spooky.sol";
import "../lenders/cream.sol";
import "../token.sol";

contract CreamUSDCFTM is Cream {
    function lendPlatform() public view override returns (address) {
        return 0x328A7b4d538A2b3942653a9983fdA3C12c571141;
    }
}

contract SpookyUSDCFTM is Spooky {
    function farmLP() public view override returns (address) {
        return 0x2b4C76d0dc16BE1C31D4C1DC53bF9B45987Fc75c;
    }
    function farmPid() public view override returns (uint256) {
        return 2;
    }
}
    
contract rbUSDCSpooky is ERC20, ERC20Detailed, CreamUSDCFTM, SpookyUSDCFTM, Token {
    using SafeMath for uint256;
    address constant USDC = 0x04068DA6C83AFCFA0e13ba15A6696662335D5B75;
    address constant WFTM = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;

    constructor() public 
        ERC20Detailed("Robo Vault USDC Spooky", "rvUSDCb", 18)
        Token(USDC, WFTM)
    {}
}