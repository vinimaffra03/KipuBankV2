// SPDX-License-Identifier: MIT
pragma solidity >0.8.22;

import {IOracle} from "./IOracle.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @author Martín Pielvitori
 * @title Oracle (Chainlink Price Feed Stub)
 * @dev A test implementation of a Chainlink price oracle for development and testing.
 * @notice This stub contract provides fixed ETH/USD price data for KipuBank testing.
 * @custom:warning Uses block.timestamp which is acceptable for testing but should be avoided in production.
 */
contract Oracle is IOracle, ERC20 {
    /// @notice Fixed ETH price in USD with 8 decimals ($4,117.88)
    int256 private constant ETH_PRICE_USD = 411788170000;
    
    /// @notice Oracle price feeds use 8 decimals (Chainlink standard)
    uint8 private constant ORACLE_DECIMALS = 8;

    /**
     * @dev Constructor that initializes the Oracle stub with ERC20 functionality.
     * @notice Creates an "Oracle" token with symbol "ORC" (not used in price functionality).
     */
    constructor() ERC20("Oracle", "ORC") {}

    /**
     * @dev Returns the latest ETH price in USD.
     * @return The fixed ETH price with 8 decimals ($4,117.88 = 411788170000).
     * @notice This function returns a constant price for testing purposes.
     */
    function latestAnswer() external pure returns(int256) {
        return ETH_PRICE_USD;
    }

    /**
     * @dev Returns comprehensive price round data compatible with Chainlink's AggregatorV3Interface.
     * @return roundId Always 0 (not relevant for stub).
     * @return answer The fixed ETH price with 8 decimals.
     * @return startedAt Always 0 (not relevant for stub).
     * @return updatedAt Current block timestamp (for freshness validation).
     * @return answeredInRound Always 0 (not relevant for stub).
     * @notice The updatedAt field uses block.timestamp to simulate real-time updates.
     */
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        return (0, ETH_PRICE_USD, 0, block.timestamp, 0);
    }

    /**
     * @dev Returns the number of decimal places in the price data.
     * @return The number of decimals (8, following Chainlink standard).
     * @notice Chainlink price feeds typically use 8 decimal places for USD prices.
     */
    function decimals() public pure override returns (uint8) {
        return ORACLE_DECIMALS;
    }
}