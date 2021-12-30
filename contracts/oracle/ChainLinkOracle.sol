// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@chainlink/contracts/src/v0.8/interfaces/FeedRegistryInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol";
import "@chainlink/contracts/src/v0.8/Denominations.sol";

import "./IOracle.sol";

contract ChainLinkOracle is IOracle {
    FeedRegistryInterface internal _registry;

    constructor(address registry) {
        _registry = FeedRegistryInterface(registry);
    }

    function getNativeTokenPrice(uint256 amount) public view override returns (uint256) {
        return getTokenUSDPrice(Denominations.ETH, amount);
    }

    function getTokenPrice(address token, uint256 amount) public view override returns (uint256) {
        (, int256 price, , , ) = _registry.latestRoundData(token, Denominations.ETH);
        return uint256(price) * amount;
    }

    function getTokenUSDPrice(address base, uint256 amount) public view override returns (uint256) {
        (, int256 price, , , ) = _registry.latestRoundData(base, Denominations.USD);
        uint8 decimals = _registry.decimals(base, Denominations.USD);

        // Normalize to 18 decimal places (aka converting to WEI)
        price = price * int256(10**(18 - decimals));

        // In wei
        price = price / (10**18);

        return uint256(price) * amount;
    }
}
