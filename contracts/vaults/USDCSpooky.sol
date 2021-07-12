// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
import "../vaultHelpers.sol";
import "../farms/spirit.sol";
import "../lenders/cream.sol";
import "../token.sol";

contract CreamUSDCFTM is Cream {
    function borrowPlatform() public view override returns (address) {
        return 0xd528697008aC67A21818751A5e3c58C8daE54696;
    }
    function lendPlatform() public view override returns (address) {
        return 0x328A7b4d538A2b3942653a9983fdA3C12c571141;
    }
    function comptrollerAddress() public view override returns (address) {
        return 0x4250A6D3BD57455d7C6821eECb6206F507576cD2;
    }
}

contract SpiritUSDCFTM is Spirit {
    function farmAddress() public view override returns (address) {
        return 0x9083EA3756BDE6Ee6f27a6e996806FBD37F6F093;
    }
    function routerAddress() public view override returns (address) {
        return 0x16327E3FbDaCA3bcF7E38F5Af2599D2DDc33aE52;
    }
    function farmToken() public view override returns (address) {
        return 0x5Cc61A78F164885776AA610fb0FE1257df78E59B;
    }
    function farmTokenLp() public view override returns (address) {
        return 0x30748322B6E34545DBe0788C421886AEB5297789;
    }
    function farmLP() public view override returns (address) {
        return 0xe7E90f5a767406efF87Fdad7EB07ef407922EC1D;
    }
    function farmPid() public view override returns (uint256) {
        return 4;
    }
}
    
contract rbUSDCSpirit is ERC20, ERC20Detailed, CreamUSDCFTM, SpiritUSDCFTM, Token {
    using SafeMath for uint256;
    address constant USDC = 0x04068DA6C83AFCFA0e13ba15A6696662335D5B75;
    address constant WFTM = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;

    constructor() public 
        ERC20Detailed("Robo Vault USDC Spirit", "rvUSDCa", 18)
        Token(USDC, WFTM)
    {}
}