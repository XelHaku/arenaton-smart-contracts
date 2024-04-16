// SPDX-License-Identifier: LicenseRef-Proprietary

pragma solidity ^0.8.9;
import './AStructs.sol';

library Tools {
    /**
     * @dev Converts an amount of DAI, USDC, or USDT to its equivalent VUND amount.
     * @param _amountCoinIn The amount of the coin being converted.
     * @param _coin The coin details.
     * @return vundAmount The equivalent VUND amount.
     * @return adjustedCoinAmount The adjusted amount of the input coin without loss of precision.
     */
    function convertCoinToVUND(
        uint256 _amountCoinIn,
        AStructs.Coin memory _coin
    ) internal pure returns (uint256 vundAmount, uint256 adjustedCoinAmount) {
        if (_coin.decimals == 18) {
            return (_amountCoinIn, _amountCoinIn);
        } else if (_coin.decimals > 18) {
            vundAmount = _amountCoinIn / (10 ** (_coin.decimals - 18));
            adjustedCoinAmount = vundAmount * (10 ** (_coin.decimals - 18)); // Get back the exact coin amount that results in vundAmount without any rounding errors.
            return (vundAmount, adjustedCoinAmount);
        } else {
            vundAmount = _amountCoinIn * (10 ** (18 - _coin.decimals));
            return (vundAmount, _amountCoinIn);
        }
    }

    /**
     * @dev Converts an amount of VUND to its equivalent DAI, USDC, or USDT amount.
     * Also returns the adjusted VUND amount in case of precision loss.
     * @param _vundAmount The amount of VUND being converted.
     * @param _coin The coin details.
     * @return coinAmount The equivalent coin amount.
     * @return adjustedVundAmount The VUND amount after adjusting for precision loss.
     */
    function convertVUNDToCoin(
        uint256 _vundAmount,
        AStructs.Coin memory _coin
    ) internal pure returns (uint256 coinAmount, uint256 adjustedVundAmount) {
        adjustedVundAmount = _vundAmount;

        if (_coin.decimals == 18) {
            return (_vundAmount, adjustedVundAmount); // If the coin already has 18 decimals, no conversion is needed
        } else if (_coin.decimals > 18) {
            coinAmount = _vundAmount * (10 ** (_coin.decimals - 18)); // If the coin has more than 18 decimals, multiply to adjust
            adjustedVundAmount = coinAmount / (10 ** (_coin.decimals - 18));
        } else {
            coinAmount = _vundAmount / (10 ** (18 - _coin.decimals)); // If the coin has fewer than 18 decimals, divide to adjust
            adjustedVundAmount = coinAmount * (10 ** (18 - _coin.decimals));
        }

        return (coinAmount, adjustedVundAmount);
    }

    /**
     * @dev Converts a string to a bytes8 value.
     * @param source The input string to be converted.
     * @return result The bytes8 representation of the input string.
     * Internal function, not meant to be called directly.
     */
    function _stringToBytes8(string memory source) internal pure returns (bytes8 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            result := mload(add(source, 32))
        }
    }

    /**
     * @dev Converts a bytes8 value to a string.
     * @param x The input bytes8 value to be converted.
     * @return string The string representation of the input bytes8 value.
     * Internal function, not meant to be called directly.
     */
    function _bytes8ToString(bytes8 x) internal pure returns (string memory) {
        bytes memory bytesString = new bytes(8);
        for (uint256 i = 0; i < 8; i++) {
            bytesString[i] = x[i];
        }
        return string(bytesString);
    }

    function _convertToInt256(int _winner) internal pure returns (uint256 convertedValue) {
        require(_winner >= 0, "Negative value can't be converted to uint256");
        convertedValue = uint256(_winner);
    }
}
// All rights reserved. This software and associated documentation files (the "Software"),
// cannot be used, copied, modified, merged, published, distributed, sublicensed, and/or
// sold without the express and written permission of the owner.
