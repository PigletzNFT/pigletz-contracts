// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../pancakeswap/IPancakeRouter02.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IOracle.sol";

contract DexOracle is IOracle, Ownable {
    IPancakeRouter02 _router;
    address _base;
    uint16 _decimals;

    constructor(
        address routerAddress,
        address base,
        uint16 decimals
    ) {
        _router = IPancakeRouter02(routerAddress);
        _base = base;
        _decimals = decimals;
    }

    function setRouter(address routerAddress, address token) public onlyOwner {
        _router = IPancakeRouter02(routerAddress);
        _base = token;
    }

    function _getPathForToken(address token) private view returns (address[] memory) {
        address[] memory path = new address[](3);
        path[0] = token;
        path[1] = _router.WETH();
        path[2] = _base;

        return path;
    }

    function getNativeTokenPrice(uint256 balance) public view override returns (uint256) {
        if (balance == 0) return 0;

        address[] memory path = new address[](2);
        path[0] = _router.WETH();
        path[1] = _base;
        uint256[] memory amounts = _router.getAmountsOut(balance, path);
        return amounts[1] * (10**(18 - _decimals));
    }

    function getTokenUSDPrice(address token, uint256 balance) public view override returns (uint256) {
        if (balance == 0) return 0;

        try _router.getAmountsOut(balance, _getPathForToken(token)) returns (uint256[] memory amounts) {
            return amounts[2] * (10**(18 - _decimals));
        } catch {
            return 0;
        }
    }

    function getTokenPrice(address token, uint256 balance) public view override returns (uint256) {
        if (balance == 0) return 0;

        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = _router.WETH();
        uint256[] memory amounts = _router.getAmountsOut(balance, path);
        return amounts[1];
    }
}
