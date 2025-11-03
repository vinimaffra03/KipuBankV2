// SPDX-License-Identifier: MIT
pragma solidity >0.8.22;

/**
 * @author Martín Pielvitori
 * @title IOracle
 * @dev Interface for price oracle functionality compatible with Chainlink.
 * @notice This interface defines the standard methods for retrieving price data from oracles.
 * @custom:reference Chainlink ETH/USD Sepolia: 0x694AA1769357215DE4FAC081bf1f309aDC325306
 */
interface IOracle {
    /**
     * @dev Returns the latest price from the oracle.
     * @return The latest price with 8 decimal places.
     * @notice This is a simplified version of Chainlink's latestAnswer function.
     */
    function latestAnswer() external view returns(int256);
    
    /**
     * @dev Returns comprehensive data about the latest price round.
     * @return roundId The round ID of the price update.
     * @return answer The price with 8 decimal places.
     * @return startedAt Timestamp when the round started.
     * @return updatedAt Timestamp when the round was last updated.
     * @return answeredInRound The round ID in which the answer was computed.
     * @notice This matches Chainlink's AggregatorV3Interface.latestRoundData format.
     */
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
}
