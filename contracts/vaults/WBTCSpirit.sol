// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "../vaultHelpers.sol";
import "../farms/spirit.sol";
import "../lenders/cream.sol";
import "../token.sol";
    
contract CreamWBTCFTM is Cream {
    function lendPlatform() public view override returns (address) {
        return 0x20CA53E2395FA571798623F1cFBD11Fe2C114c24;
    }
}

contract SpiritWBTCFTM is Spirit {
    function farmLP() public view override returns (address) {
        return 0x279b2c897737a50405ED2091694F225D83F2D3bA;
    }
    function farmPid() public view override returns (uint256) {
        return 2;
    }
}

contract rbWBTCSpirit is ERC20, ERC20Detailed, CreamWBTCFTM, SpiritWBTCFTM, RoboController {
    using SafeMath for uint256;
    address constant WBTC = 0x321162Cd933E2Be498Cd2267a90534A804051b11;
    address constant WFTM = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;

    constructor() public 
        ERC20Detailed("Robo Vault WBTC Spirit", "rvWBTCa", 18)
        Token(WBTC, WFTM)
    {}
}