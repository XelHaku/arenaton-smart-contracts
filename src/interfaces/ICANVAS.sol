// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import '../libraries/AStructs.sol';

interface ICANVAS {
    function tokenPixelInfo(uint256 _tokenId) external view returns (AStructs.tokenPixelInfo memory);

    function playerCanvasInfo(address _player) external view returns (AStructs.playerCanvasInfo memory);

    function removePixels(uint256[3] memory _tokenIdsFuse) external returns (bool);

    function getPixelColor(uint256 _tokenId) external view returns (uint8);
}
