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

// Import required libraries and contracts https://ipfs.io/ipfs/bafybeibc5sgo2plmjkq2tzmhrn54bk3crhnc23zd2msg4ea7a4pxrkgfna/6142
import '@openzeppelin/contracts/token/ERC20/ERC20.sol'; // Standard ERC20 contract from OpenZeppelin.
import './libraries/ABDKMath64x64.sol'; // ABDKMath64x64 library for fixed-point arithmetic.

// ATON contract inherits from the ERC20 standard contract
contract ATON is ERC20 {
    uint256 private _InitialSupply; // Stores the initial supply of the token.
    using ABDKMath64x64 for int128; // Use the ABDKMath64x64 library for fixed-point arithmetic operations.

    /**
     * @dev Constructor initializes the ATON token by setting its name and symbol.
     * The constructor also mints an enormous initial supply of the token to the contract creator's address.
     */
    constructor() ERC20('ATON Token', 'ATON') {
        _InitialSupply = 1000000000000000000000000000000000000000000 * (10 ** decimals());
        _mint(msg.sender, _InitialSupply);
    }

    /**
     * @dev Returns the amount of ATON tokens that have been burned from the total supply.
     * @return The number of tokens that have been burned.
     */
    function burned() external view returns (uint256) {
        return _burned();
    }

    /**
     * @dev Internal function to calculate the burned ATON tokens.
     * @return The amount of tokens that have been burned.
     */
    function _burned() internal view returns (uint256) {
        return _InitialSupply - totalSupply();
    }

    /**
     * @dev Allows a user to burn a specified amount of their ATON tokens.
     * @param _burnAmount The amount of tokens the user wants to burn.
     * @return true if the burn was successful.
     */
    function burnFrom(uint256 _burnAmount) external returns (bool) {
        require(balanceOf(msg.sender) >= _burnAmount, 'Insufficient ATON balance');
        _burn(msg.sender, _burnAmount);
        return true;
    }

    /**
     * @dev Calculates a factor based on the number of burned ATON tokens.
     *
     * Overview:
     * The goal of this function is to compute a factor using the natural logarithm
     * of the number of burned ATON tokens. This factor can be further used in other
     * calculations, particularly for determining the ATON amount based on a VUND amount.
     *
     * Detailed Steps:
     * 1. Retrieve the number of ATON tokens that have been burned so far.
     * 2. Convert this value to a fixed-point format (64.64) to make it compatible with
     *    the ABDKMath64x64 library. Add 1 to ensure that the logarithm of zero is never
     *    taken, which would result in negative infinity.
     * 3. Scale down the fixed-point representation of the burned ATON by dividing by 10^12.
     *    This step ensures the number remains within a range suitable for taking its natural logarithm.
     * 4. Compute the natural logarithm of the scaled burned ATON number.
     * 5. Scale and offset the result: multiply the logarithm by 4242 (for scaling)
     *    and then add an offset of 10,000.
     * 6. The result is the calculated factor based on the burned ATON.
     *
     * Example Use Case:
     * This factor can be used to determine the ATON amount relative to a VUND amount
     * using the formula: ATONamount = VUNDamount * pct_denom / factorAton,
     * where pct_denom is a constant, e.g., 10,000,000.
     *
     * @return The calculated factor based on the number of burned ATON tokens.
     */
    function calculateFactorAton() public view returns (uint256) {
        // Constants in fixed point notation
        int128 FIXED_4242 = 0x00000000000010920000000000000000; // Fixed-point representation of 4242
        int128 FIXED_10000 = 0x00000000000027100000000000000000; // Fixed-point representation of 10000
        // uint256 cuttoff = 1000000000000 * (10 ** decimals());
        uint256 cuttoff = 1000000000000000000000 * (10 ** decimals());
        // Step 1: Retrieve the number of burned ATON tokens.
        uint256 burnedAton = _burned();
        uint256 factorAton;
        if (burnedAton <= cuttoff) {
            // console.log('burnedAton <= cuttoff', burnedAton);
            // Step 2 & 3: Convert the burned ATON count to a 64.64 fixed-point format and scale it down.
            // uint256 scaledDownBurnedAton = burnedAton / (10 ** 12);
            uint256 scaledDownBurnedAton = burnedAton / (10 ** 21);
            int128 burnedAtonFixed = ABDKMath64x64.fromUInt(scaledDownBurnedAton + 1);

            // Step 4: Compute the natural logarithm of the scaled burned ATON.
            int128 logBurnedAton = ABDKMath64x64.ln(burnedAtonFixed);

            // If logBurnedAton is negative, return 10000
            if (logBurnedAton < 0) {
                return 10000;
            }

            // factorAton = 4242*log(burnedAton/10^12)+10000
            // Step 5: Scale and offset the result.
            int128 mulResult = ABDKMath64x64.mul(logBurnedAton, FIXED_4242);
            int128 sumResult = ABDKMath64x64.add(mulResult, FIXED_10000);
            factorAton = ABDKMath64x64.toUInt(sumResult);
        } else {
            factorAton = 185816 + (burnedAton - cuttoff) / 10 ** 35;
        }

        // Step 6: Return the computed factor.
        return factorAton;
    }
}

// All rights reserved. This software and associated documentation files (the "Software"),
// cannot be used, copied, modified, merged, published, distributed, sublicensed, and/or
// sold without the express and written permission of the owner.
