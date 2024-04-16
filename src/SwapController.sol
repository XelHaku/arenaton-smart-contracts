//                     _.-'-._
//                  _.'       '-.
//              _.-'   _.   .    '-._
//           _.'   _.eEEE   EEe..    '-._
//       _.-'   _.eEE* EE   EE`*EEe._    '-.
//    _.'   _.eEEE'  . EE   EE .  `*EEe._   '-
//    |   eEEP*'_.eEE' EP   YE  Ee._ `'*EE.   |
//    |   EE  .eEEEE' AV  .. VA.'EEEEe.  EE   |
//    |   EE |EEEEP  AV  /  \ VA.'*E***--**---'._     .------------.    .----------._          /\       .------------.     _.--------._    .-----------._
//    |   EE |EEEP  EEe./    \eEE. E|   _  ___   '    '------------'    |  .......   .        /  \      '----.  .----'    |   ______   .   |   .......   .
//    |   EE |EEP AVVEE/  /\  \EEEA |  |_EE___|   )   .----------- .    |  |      |  |       / /\ \          |  |         |  |      |  |   |  |       |  |
//    |   EE |EP AV  `   /EE\  \ 'EA|            .    '------------'    |  |      |  |      / /  \ \         |  |         |  |      |  |   |  |       |  |
//    |   EE ' _AV   /  /EE|"   \ `E|  |-ee-\   \     .------------.    |  |      |  |     / /  --' \        |  |         |  '------'  .   |  |       |  |
//    |   EE.eEEP   /__/*EE|_____\  '--|.EE  '---'.   '------------'    '--'      '--'    /-/   -----\       '--'          '..........'    '--'       '--'
//    |   EEP            EEE          `'*EE   |
//    |   *   _.eEEEEEEEEEEEEEEEEEEE._   `*   |
//    |     <EEE<  .eeeeeeeeeeeee. `>EEE>     |
//    '-._   `*EEe. `'*EEEEEEE*' _.eEEP'   _.-'
//        `-._   `"Ee._ `*E*'_.eEEP'   _.-'
//            `-.   `*EEe._.eEE*'   _.'
//               `-._   `*V*'   _.-'
//                   '-_     _-'
//                      '-.-'

// SPDX-License-Identifier: LicenseRef-Proprietary

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IVAULT.sol";
import "./libraries/AStructs.sol";
import "./libraries/Tools.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol"; // Provides mechanisms for ownership control

/**
 * @title Swap Contract
 * @dev This contract facilitates the swapping of tokens based on the token data retrieved from an external VAULT contract.
 * It also calculates the swap outputs based on the token balances within the VAULT.
 * Inherits the ReentrancyGuard to prevent reentrancy attacks.
 */
contract SwapController is AccessControl, ReentrancyGuard, Ownable {
    IVAULT internal VAULT; // Interface to interact with the VAULT contract.
    uint256 public N_COINS; // Number of supported coins.
    // Define a constant amplification factor.
    uint256 public A = 10;
    // Premium percentages to apply based on the pool momentum swap.
    uint256 private constant premiumPositive = 1000; //0.01%
    uint256 private constant premiumNegative = 5000; //0.05%
    uint256 constant pct_denom = 10000000; // Denominator to handle percentages with precision.

    AStructs.Coin[] private coinList; // List of supported coins.
    uint256 public initial_A = A;
    uint256 public future_A = A;
    uint256 public initial_A_time;
    uint256 public future_A_time;

    uint256 constant MIN_RAMP_TIME = 86400; // Define the value of MIN_RAMP_TIME
    uint256 constant MAX_A = 10 ** 6; // Define the value of MAX_A
    uint256 constant MAX_A_CHANGE = 10; // Define the value of MAX_A_CHANGE

    /**
     * @dev Constructor initializes the VAULT/VUND contract reference and coin list.
     * @param _VAULT The address of the VAULT/VUND contract.
     */
    constructor(address _VAULT) Ownable(msg.sender) {
        VAULT = IVAULT(_VAULT); // Initializing the VAULT interface.

        // Initializing the coinList with coins from VAULT.
        AStructs.Coin[] memory coins = VAULT.getCoinList();
        for (uint8 i = 0; i < coins.length; i++) {
            coinList.push(coins[i]);
        }
        N_COINS = coinList.length - 1;
    }

    /**
     * @notice Calculate the output amount for a given swap.
     * @dev It's a wrapper for the internal function _getAmountsOut.
     * @param _inputAmount The amount of tokens the user wants to swap.
     * @param tokenIn Address of the input token.
     * @param tokenOut Address of the output token.
     * @return Output amount, input amount, and direction of momentum (premium).
     */
    function getAmountsOut(uint256 _inputAmount, address tokenIn, address tokenOut)
        external
        view
        returns (uint256, uint256, uint256)
    {
        return _getAmountsOut(_inputAmount, tokenIn, tokenOut);
    }

    function _getCoinIndexes(address tokenIn, address tokenOut)
        internal
        view
        returns (uint8, uint8, AStructs.Coin memory, AStructs.Coin memory)
    {
        uint8 inputCoinIndex;
        uint8 outputCoinIndex;

        AStructs.Coin memory coinIn;
        AStructs.Coin memory coinOut;

        for (uint8 i = 0; i < coinList.length; i++) {
            if (coinList[i].token == tokenIn) {
                coinIn = coinList[i];

                inputCoinIndex = (tokenIn != address(VAULT)) ? i - 1 : 0;
                // inputCoinIndex = i;
            } else if (coinList[i].token == tokenOut) {
                coinOut = coinList[i];

                outputCoinIndex = (tokenOut != address(VAULT)) ? i - 1 : 0;
                // outputCoinIndex = i;
            }
        }
        return (inputCoinIndex, outputCoinIndex, coinIn, coinOut);
    }

    /**
     * @dev Internal function that determines the swap output.
     * @param _inputAmount The amount of tokens to be swapped.
     * @param tokenIn Address of the input token.
     * @param tokenOut Address of the output token.
     * @return Output amount, input amount, and direction of momentum (premium).
     */
    function _getAmountsOut(uint256 _inputAmount, address tokenIn, address tokenOut)
        internal
        view
        returns (uint256, uint256, uint256)
    {
        // Ensure that the input and output tokens are not the same.
        require(tokenIn != tokenOut, "Input and output coins are the same");

        // Retrieve indices and details of the input and output tokens.
        (uint8 inputCoinIndex, uint8 outputCoinIndex, AStructs.Coin memory coinIn, AStructs.Coin memory coinOut) =
            _getCoinIndexes(tokenIn, tokenOut);

        // Check if the input token is the vault's native token.
        if (tokenIn == address(VAULT)) {
            // Convert the vault's native token to the output coin.
            (uint256 outputAmount, uint256 balance) = Tools.convertVUNDToCoin(_inputAmount, coinOut);

            // Ensure there's enough balance of the output token in the vault.
            require(
                IERC20(coinList[outputCoinIndex + 1].token).balanceOf(address(VAULT))
                    + 10 ** coinList[outputCoinIndex + 1].decimals > outputAmount,
                "Not enough _tokenOut Balance"
            );
            return (outputAmount, balance, 0);
        } else if (tokenOut == address(VAULT)) {
            // Revert the transaction if the output token is the vault's native token.
            revert("VUND cannot be swapped out");
        }

        // Get the current balances of all tokens in the vault's native token (VUND) equivalent.
        uint256[] memory oldBalancesInVUND = _getBalancesInVUND();

        // Calculate the output amount of the token swap in the output token's units.
        uint256 outputAmountInCoin =
            _calculateOutputAmount(oldBalancesInVUND, _inputAmount, coinIn, inputCoinIndex, outputCoinIndex);

        // Convert the input amount and output amount to the vault's native token (VUND) equivalent.
        (uint256 inputAmountInVUND,) = Tools.convertCoinToVUND(_inputAmount, coinIn);
        (uint256 outAmountInVUND,) = Tools.convertCoinToVUND(outputAmountInCoin, coinOut);

        // Calculate the premium based on the change in balances before and after the swap.
        uint256 premium = (
            _calculateDifference(oldBalancesInVUND[inputCoinIndex], oldBalancesInVUND[outputCoinIndex])
                > _calculateDifference(
                    oldBalancesInVUND[inputCoinIndex] + inputAmountInVUND,
                    oldBalancesInVUND[outputCoinIndex] - outAmountInVUND
                )
        ) ? premiumPositive : premiumNegative;

        // Return the calculated output amount in coin, input amount, and premium.
        return (outputAmountInCoin, _inputAmount, premium);
    }

    function _getBalancesInVUND() internal view returns (uint256[] memory balances) {
        balances = new uint256[](N_COINS);
        for (uint8 i = 1; i < coinList.length; i++) {
            uint256 balance = IERC20(coinList[i].token).balanceOf(address(VAULT));
            (balances[i - 1],) = Tools.convertCoinToVUND(balance, coinList[i]);
        }
    }

    function _calculateDifference(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a > b) ? a - b : b - a;
    }

    /**
     * @dev Calculates the output amount of a token swap based on the input amount and other pool parameters.
     *
     * It computes the invariant before and after a proposed swap to determine the effect on the pool.
     * It ensures that the pool's overall value remains consistent before and after the swap.
     * The function also accounts for potential slippage and ensures that the output amount doesn't exceed certain bounds.
     *
     * @param oldBalancesInVUND An array representing the previous balances of tokens in VUND.
     * @param _inputAmount The amount of the input token for the swap.
     * @param coinIn The details of the input token.
     * @param inputCoinIndex The index of the input token in the pool.
     * @param outputCoinIndex The index of the output token in the pool.
     * @return The calculated output amount of the token swap.
     */
    function _calculateOutputAmount(
        uint256[] memory oldBalancesInVUND,
        uint256 _inputAmount,
        AStructs.Coin memory coinIn,
        uint8 inputCoinIndex,
        uint8 outputCoinIndex
    ) internal view returns (uint256) {
        // Calculate the pool's invariant before the proposed swap.
        uint256 D_before = _getDWithBalances(oldBalancesInVUND, A);

        // Ensure the invariant is not zero before the swap.
        require(D_before > 0, "Invariant D_before cannot be zero");

        // Convert the input amount to its equivalent in VUND.
        (uint256 inputAmountInVUND,) = Tools.convertCoinToVUND(_inputAmount, coinIn);

        // Copy old balances into a new array to simulate the proposed swap.
        uint256[] memory newBalancesInVUND = new uint256[](oldBalancesInVUND.length);
        for (uint256 i = 0; i < oldBalancesInVUND.length; i++) {
            newBalancesInVUND[i] = oldBalancesInVUND[i];
        }

        // Increment the balance of the input token by the input amount.
        newBalancesInVUND[inputCoinIndex] += inputAmountInVUND;

        // Calculate the pool's invariant after the proposed swap.
        uint256 D_after = _getDWithBalances(newBalancesInVUND, A);

        // If the invariant after the swap is not greater than the initial one, return 0 (no swap).
        if (D_after < D_before + 1) {
            return 0;
        }

        // Calculate the output amount in VUND (subtracting 1 to account for rounding).
        uint256 outputAmountVUND = D_after - D_before - 1;

        // Set a cap on the output amount to protect against large slippage.

        uint256 maxAllowedOutput = inputAmountInVUND + (inputAmountInVUND * premiumPositive) / pct_denom; // This represents 100.01% of the input
        if (outputAmountVUND > maxAllowedOutput) {
            outputAmountVUND = maxAllowedOutput;
        }

        // Ensure the pool has enough liquidity for the output token. With a minimum of 1 VUND.
        if (newBalancesInVUND[outputCoinIndex] < outputAmountVUND + 1000000) {
            return 0;
        }

        // Convert the output amount from VUND to the desired output token.
        (uint256 outputAmountInCoin,) = Tools.convertVUNDToCoin(outputAmountVUND, coinList[outputCoinIndex + 1]);

        // Return the output amount for the token swap.
        return outputAmountInCoin;
    }

    /**
     * @dev Computes the invariant D for a given set of balances.
     *
     * The invariant represents the total liquidity (value) of the pool. It ensures that the value remains consistent
     * regardless of the distribution of the balances. This is typical for stablecoin pools where the goal is to have
     * minimal slippage between assets that are supposed to have the same value.
     * The function uses an iterative approach to compute the invariant D.
     *
     * @param _balances Array of token balances, typically representing stablecoins.
     * @param amp Amplification coefficient used to boost liquidity in certain ranges.
     * @return The computed invariant D.
     */
    function _getDWithBalances(uint256[] memory _balances, uint256 amp) internal view returns (uint256) {
        // Initializing the sum of all balances to 0.
        uint256 S = 0;

        // Summing up the balances of all tokens.
        for (uint256 i = 0; i < N_COINS; i++) {
            S += _balances[i];
        }

        // If the total balance is zero, the invariant D is also zero.
        if (S == 0) {
            return 0;
        }

        // Initialize previous value of D and set the current D as the sum of balances.
        uint256 Dprev = 0;
        uint256 D = S;

        // Compute the amplified number of coins.
        uint256 Ann = amp * N_COINS;

        // Iterative approach to converge on the value of D.
        for (uint256 j = 0; j < 255; j++) {
            // Initializing D_P with the current value of D.
            uint256 D_P = D;

            // Adjusting D_P based on the distribution of individual token balances.
            for (uint256 k = 0; k < N_COINS; k++) {
                D_P = (D_P * D) / (_balances[k] * N_COINS); // If division by 0, it will revert
            }

            // Storing the previous value of D for comparison in the next iteration.
            Dprev = D;

            // Calculating the next value of D based on current D and D_P.
            D = ((Ann * S + D_P * N_COINS) * D) / ((Ann - 1) * D + (N_COINS + 1) * D_P);

            // Breaking out of the loop if the change in D value between iterations is less than or equal to 1.
            if (D > Dprev) {
                if (D - Dprev <= 1) {
                    break;
                }
            } else {
                if (Dprev - D <= 1) {
                    break;
                }
            }
        }

        // Returning the computed invariant D.
        return D;
    }

    /**
     * @dev This function handles the execution of a token swap.
     *
     * - It calculates the output amount based on the input amount, considering any commissions.
     * - Commission percentages adjust based on the swap's impact on the balance of the underlying assets.
     * - Swaps that work towards balancing the pool get a better commission rate; otherwise, they face a higher rate.
     * - After executing the swap, the commission is distributed to the sender.
     *
     * @param _inputAmount The quantity of the input token for the swap.
     * @param _tokenIn Address of the input token.
     * @param _tokenOut Address of the output token.
     * @param _slippageTolerance The percentage of slippage the user is willing to tolerate. If set to 0, no slippage is tolerated.
     * @return Returns true if the swap operation is successful, otherwise it will revert.
     */
    function SwapExecution(uint256 _inputAmount, address _tokenIn, address _tokenOut, uint256 _slippageTolerance)
        external
        nonReentrant
        returns (bool)
    {
        A = _A();
        // Get the expected output amount, input amount after commissions, and the commission percentage.
        (uint256 outputAmount, uint256 inputAmount, uint256 comissionPct) =
            _getAmountsOut(_inputAmount, _tokenIn, _tokenOut);

        // Ensure there's enough balance in the pool for the desired output token.
        require(outputAmount > 0, "outputAmount is 0,error");

        // If user cares about slippage (i.e., _slippageTolerance > 0), check and ensure the swap doesn't exceed the user's specified tolerance.
        if (_slippageTolerance > 0) {
            (,, AStructs.Coin memory coinIn, AStructs.Coin memory coinOut) = _getCoinIndexes(_tokenIn, _tokenOut);
            (uint256 outputAmountInVUND,) = Tools.convertCoinToVUND(outputAmount, coinOut);
            (uint256 inputAmountInVUND,) = Tools.convertCoinToVUND(inputAmount, coinIn);

            require(
                outputAmountInVUND
                    >= inputAmountInVUND - ((_slippageTolerance + comissionPct) * inputAmountInVUND) / pct_denom,
                "Slippage tolerance exceeded"
            );
        }

        // Perform the token swap and adjust balances.
        VAULT.swap(msg.sender, _tokenIn, _tokenOut, inputAmount, outputAmount, comissionPct);

        return true;
    }

    /**
     * @notice Calculate the current value of amplification coefficient `A`.
     * This function uses linear interpolation between initial_A and future_A based on the timestamps.
     * @dev Handles ramping `A` up or down.
     * @return The current value of `A`.
     */
    function _A() internal view returns (uint256) {
        uint256 t1 = future_A_time;
        uint256 A1 = future_A;

        // Check if the current time is before the future timestamp
        if (block.timestamp < t1) {
            uint256 A0 = initial_A;
            uint256 t0 = initial_A_time;

            // If future_A is greater than initial_A, interpolate by increasing value
            if (A1 > A0) {
                return A0 + ((A1 - A0) * (block.timestamp - t0)) / (t1 - t0);
            }
            // Otherwise interpolate by decreasing value
            else {
                return A0 - ((A0 - A1) * (block.timestamp - t0)) / (t1 - t0);
            }
        }
        // If the future timestamp has passed, simply return future_A
        else {
            return A1;
        }
    }

    /**
     * @notice Set a new future amplification coefficient `A` and its target timestamp.
     * @dev Only accessible by the admin role. The change rate is also checked to ensure it's within limits.
     * @param _future_A The target value of `A` in the future.
     * @param _future_time The target timestamp when `A` should reach `_future_A`.
     */
    function ramp_A(uint256 _future_A, uint256 _future_time) external onlyOwner {
        require(block.timestamp >= initial_A_time + MIN_RAMP_TIME, "Minimum ramp time not met");
        require(_future_time >= block.timestamp + MIN_RAMP_TIME, "insufficient time");

        uint256 _initial_A = _A();

        // Check for valid boundaries of the new future A value
        require(_future_A > 0 && _future_A < MAX_A, "Invalid future A value");

        // Check that the change rate is within the allowed limits
        require(
            (_future_A >= _initial_A && _future_A <= _initial_A * MAX_A_CHANGE)
                || (_future_A < _initial_A && _future_A * MAX_A_CHANGE >= _initial_A),
            "Invalid A change rate"
        );

        // Set new values for the amplification coefficient and its timestamps
        initial_A = _initial_A;
        future_A = _future_A;
        initial_A_time = block.timestamp;
        future_A_time = _future_time;

        // Emit an event for the A ramp (uncomment if needed)
        // emit RampA(_initial_A, _future_A, block.timestamp, _future_time);
    }

    /**
     * @notice Stop the ongoing ramp of `A` and fix its current value.
     * @dev Only accessible by the admin role.
     */
    function stop_ramp_A() external onlyOwner {
        uint256 current_A = _A();

        // Set the values to stop any future change in A
        initial_A = current_A;
        future_A = current_A;
        initial_A_time = block.timestamp;
        future_A_time = block.timestamp;

        // Emit an event for stopping the A ramp (uncomment if needed)
        // emit StopRampA(current_A, block.timestamp);
    }
}
// All rights reserved. This software and associated documentation files (the "Software"),
// cannot be used, copied, modified, merged, published, distributed, sublicensed, and/or
// sold without the express and written permission of the owner.
