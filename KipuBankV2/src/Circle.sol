// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @author Martín Pielvitori
 * @title Circle (Fake USDC)
 * @dev A test implementation of USDC for development and testing purposes.
 * @notice This is a stub contract that mimics USDC functionality for KipuBank testing.
 * @custom:reference Real USDC Ethereum Sepolia: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
 */
contract Circle is ERC20 {
    /// @notice USDC has 6 decimals (same as real USDC)
    uint8 private constant USDC_DECIMALS = 6;

    /**
     * @dev Constructor that initializes the fake USDC token.
     * @notice Sets the token name to "Circle" and symbol to "USDC" to mimic real USDC.
     */
    constructor() ERC20("Circle", "USDC") {}

    /**
     * @dev Mints new USDC tokens to a specified address.
     * @notice This function is public for testing purposes only. Real USDC has restricted minting.
     * @param to Address to receive the minted tokens.
     * @param amount Amount of tokens to mint (with 6 decimals).
     */
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    /**
     * @dev Returns the number of decimal places for the token.
     * @return The number of decimals (6, same as real USDC).
     * @notice USDC uses 6 decimal places, unlike ETH which uses 18.
     */
    function decimals() public pure override returns (uint8) {
        return USDC_DECIMALS;
    }
}