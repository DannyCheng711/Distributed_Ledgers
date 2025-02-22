// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// solhint-disable-next-line interface-starts-with-i
interface AggregatorV3Interface {
  // This function returns the number of decimal places used by the price feed
  function decimals() external view returns (uint8);

  // This function returns a string that describes the data source or the feed. It might include information like “ETH/USD” or “BTC/USD”. 
  function description() external view returns (string memory);

  // This function returns the version of the price feed.
  function version() external view returns (uint256);

  // This function provides the data for a specific round in the price feed history. 
  // Each price feed is associated with multiple “rounds”, and this function can fetch the details of a given round based on its ID.
	// The response includes the round ID, the price answer, the timestamp when the round started, the timestamp when the round was updated, and the round ID in which the answer was finalized.
  function getRoundData(
    uint80 _roundId
  ) external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

  // This function returns the most recent round’s data. It provides the latest price from the feed along with the round ID, timestamps for when the round started and updated, and the round in which the answer was finalized.
  function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}
