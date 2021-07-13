// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "../vaultHelpers.sol";
import "../farms/spirit.sol";
import "../lenders/cream.sol";
import "../token.sol";

contract CreamUSDCFTM is Cream {
    function lendPlatform() public view override returns (address) {
        return 0x328A7b4d538A2b3942653a9983fdA3C12c571141;
    }
}

contract SpiritUSDCFTM is Spirit {
    function farmLP() public view override returns (address) {
        return 0xe7E90f5a767406efF87Fdad7EB07ef407922EC1D;
    }
    function farmPid() public view override returns (uint256) {
        return 4;
    }
}
    
contract rbUSDCSpirit is ERC20, ERC20Detailed, CreamUSDCFTM, SpiritUSDCFTM, RoboController {
    using SafeMath for uint256;
    address constant USDC = 0x04068DA6C83AFCFA0e13ba15A6696662335D5B75;
    address constant WFTM = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;

    constructor() public 
        ERC20Detailed("Robo Vault USDC Spirit", "rvUSDCa", 18)
        Token(USDC, WFTM)
    {}
}