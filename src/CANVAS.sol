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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Importing required modules and interfaces from OpenZeppelin and Chainlink
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol"; // ERC721 token with URI storage capabilities
import "@openzeppelin/contracts/access/Ownable.sol"; // Access control mechanism for ownership
// import "@VRFConsumerBaseV2/";
import "lib/chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
// Chainlink VRF (Verifiable Random Function) for randomness
import "lib/chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol"; // Interface for interacting with Chainlink VRF Coordinator
import "./interfaces/IATON.sol"; // Interface for the ATON contract
import "./interfaces/IPVT.sol"; // Interface for the VAULT contract
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol"; // Security feature to prevent reentrancy attacks
import "./libraries/EventsLib.sol"; // Library for events
import "./libraries/NFTcategories.sol"; // Library for NFT categories

// PVT contract inherits from multiple contracts/interfaces to provide ERC721, VRF, ownership, and reentrancy guard functionalities
contract CANVAS is Ownable, ReentrancyGuard {
    // References to other contracts/interfaces
    IPVT internal PVT; // Reference to the VAULT contract

    // PVT Vars ######################################################################

    // CANVAS #########################################################################
    uint256 private canvasSize = 1; // Size of the canvas (not clear without context)
    uint256 private canvasPot; // Pot for the canvas (not clear without context)
    // TODO: Counter Total Rewards and Paints
    // Mappings related to the canvas feature

    // Canvas Token o Coordinates Info
    mapping(uint256 => uint256) private pixelsTokenId; // Mapping from encoded coordinate to token ID
    mapping(uint256 => uint256) private tokenIdCoordinates; // Mapping from token ID to encoded coordinate
    mapping(uint256 => uint8) private pixelsColor; // Mapping from coordinate to color
    mapping(uint256 => address) private lastPainter; // Mapping from coordinate to the address of the last painter
    mapping(uint256 => uint256) private lastTimePainted; //Mapping from coordinate to the last time that coordinate was painted

    // Canvas Player Info
    mapping(address => uint256) private dailyPaintCount; // Mapping from coordinate to the address of the last painter
    mapping(address => uint256) private currentPaintedPixels; // Mapping from address to number of painted pixels
    mapping(address => uint256) private totalPaintedPixels; // Mapping from address to number of painted pixels
    mapping(address => uint256) private dailyPaintTimestamp; //Mapping from coordinate to the address of the last painter

    // Constructor to initialize the contract with required addresses and Chainlink VRF parameters
    constructor(address _PVT) Ownable(msg.sender) {
        PVT = IPVT(_PVT);
    }

    // Allows a user to paint a pixel on the canvas with a specified color.
    // CANVAS
    function paintPixel(uint128 x, uint128 y, uint8 _color) external nonReentrant {
        uint256 coordinates = AStructs.encodeCoordinates(x, y);
        require(x <= canvasSize && y <= canvasSize && pixelsColor[coordinates] != _color, "paintPixel error");

        uint256 tokenId = pixelsTokenId[coordinates];
        uint256 oneVUNDinATON = _getVUNDtoATON(10 ** 18);
        address lastPainterAddress = lastPainter[coordinates];

        //get The owner of the land if exists
        address landOwner = tokenId > 0 ? PVT.ownerOf(tokenId) : address(0); // PVT

        // Pixel NFT payout
        if (landOwner != address(0)) {
            PVT.addEarningsToPlayerInAton(
                landOwner,
                (oneVUNDinATON * 1000000 * PVT.getQuality(tokenId)) / AStructs.pct_denom,
                uint8(AStructs.EarningCategory.PixelPaint)
            );
            PVT.setQuality(tokenId, _color);
        }

        if (lastTimePainted[coordinates] > 0) {
            uint256 timeDiff = block.timestamp - lastTimePainted[coordinates];

            uint256 rewards = (
                (10000 * oneVUNDinATON * timeDiff * AStructs.pct_denom) / (86400 * canvasSize * canvasSize)
            ) / AStructs.pct_denom;

            uint256 stealedAmount = (rewards * 100000 * dailyPaintCount[msg.sender]) / AStructs.pct_denom;

            PVT.addEarningsToPlayerInAton(msg.sender, stealedAmount, uint8(AStructs.EarningCategory.PixelSteal));

            PVT.addEarningsToPlayerInAton(
                lastPainterAddress, rewards - stealedAmount, uint8(AStructs.EarningCategory.PixelPaint)
            );
        }

        if (lastPainterAddress != address(0)) {
            currentPaintedPixels[lastPainterAddress] -= 1;
        }
        pixelsColor[coordinates] = _color;

        currentPaintedPixels[msg.sender] += 1;
        totalPaintedPixels[msg.sender] += 1;
        lastPainter[coordinates] = msg.sender;

        // Dailies

        if (
            dailyPaintTimestamp[msg.sender] < block.timestamp - 48 hours
                && dailyPaintTimestamp[msg.sender] > block.timestamp - 24 hours
        ) {
            dailyPaintCount[msg.sender] += 1; // until 21
            if (dailyPaintCount[msg.sender] > 21) dailyPaintCount[msg.sender] = 1;
            dailyPaintTimestamp[msg.sender] = block.timestamp;
        }

        if (dailyPaintTimestamp[msg.sender] > block.timestamp - 48 hours) {
            dailyPaintTimestamp[msg.sender] = block.timestamp;
            dailyPaintCount[msg.sender] = 0;
        }

        _growCanvas();
        emit EventsLib.PaintPixel(msg.sender, x, y, _color);
    }

    // Allows a user to claim a pixel on the canvas by associating it with a new token ID.
    function claimPixel(uint128 x, uint128 y, uint256 _newTokenId) external nonReentrant returns (bool) {
        uint256 coordinates = AStructs.encodeCoordinates(x, y); // Encode the x and y coordinates into a single uint.

        uint256 oldTokenId = pixelsTokenId[coordinates]; // Get the current token ID associated with the pixel.
        // If the pixel is unclaimed or the new token has higher quality, associate it with the new token ID.
        if (oldTokenId == 0 || PVT.getQuality(oldTokenId) < PVT.getQuality(_newTokenId)) {
            pixelsTokenId[coordinates] = _newTokenId; // Update the token ID associated with the pixel.
        } else {
            revert("Already Claimed"); // If the pixel is already claimed, revert the transaction.
        }
        tokenIdCoordinates[_newTokenId] = coordinates; // Update the coordinates associated with the new token ID.
        emit EventsLib.ClaimPixel(oldTokenId, _newTokenId, x, y, PVT.getQuality(_newTokenId)); // Emit an event for claiming a pixel.
        return true; // Return true to indicate successful execution.
    }

    // Retrieves the colors of pixels in a paginated manner.
    function getPixelColors(uint256 page, uint256 perPage) external view returns (AStructs.PixelDTO[] memory) {
        uint256 totalPixels = canvasSize * canvasSize; // Calculate the total number of pixels on the canvas.
        uint256 startIndex = (page - 1) * perPage; // Determine the starting index for the requested page.

        // Ensure the page and perPage parameters are valid and within the range of total pixels.
        require(perPage > 0 && page >= 1 && startIndex < totalPixels, " out of range");

        uint256 endIndex = page * perPage > totalPixels ? totalPixels : page * perPage; // Determine the ending index for the requested page.

        uint256 resultSize = endIndex - startIndex; // Calculate the number of pixels to be returned.
        AStructs.PixelDTO[] memory pixelArray = new AStructs.PixelDTO[](resultSize); // Initialize the array of pixel DTOs.

        uint256 resultIndex = 0; // Initialize the index for the result array.
        for (uint256 i = startIndex; i < endIndex; i++) {
            uint256 x = i / canvasSize; // Calculate the x coordinate.
            uint256 y = i % canvasSize; // Calculate the y coordinate.

            // Retrieve the color and token ID of the pixel at the calculated coordinates.
            uint8 color = pixelsColor[AStructs.encodeCoordinates(uint128(x), uint128(y))];
            AStructs.PixelDTO memory pixel = AStructs.PixelDTO({
                x: uint128(x),
                y: uint128(y),
                color: color,
                tokenId: pixelsTokenId[AStructs.encodeCoordinates(uint128(x), uint128(y))],
                painter: lastPainter[AStructs.encodeCoordinates(uint128(x), uint128(y))]
            });
            pixelArray[resultIndex] = pixel; // Add the pixel DTO to the result array.
            resultIndex++; // Increment the result index.
        }

        return pixelArray; // Return the array of pixel DTOs.
    }

    function _growCanvas() internal {
        canvasPot += 1; // Increment the canvas pot by 1 point.

        // Use an exponential growth model for the row requirement.
        // For example, rowRequirement = baseRequirement * growthFactor^canvasSize
        // where baseRequirement is the initial points needed to grow the canvas,
        // and growthFactor is a constant > 1 determining the growth rate.
        uint256 baseRequirement = 10; // Initial requirement for the first increase.
        uint256 growthFactor = 2; // Adjust this to control the growth speed.

        uint256 rowRequirement = baseRequirement * (growthFactor ** (canvasSize - 1));

        // Check if the canvas pot meets or exceeds the row requirement.
        if (canvasPot >= rowRequirement) {
            canvasPot = 0; // Reset the canvas pot.
            canvasSize++; // Increase the canvas size.

            // Optional: Mint a treasure chest as a reward for the canvas growth.
            // _mintTreasureChest();

            emit EventsLib.CanvasSizeIncrease(msg.sender, canvasSize); // Emit an event.
        }
    }

    function tokenPixelInfo(uint256 _tokenId) external view returns (AStructs.tokenPixelInfo memory) {
        return _tokenPixelInfo(_tokenId);
    }

    // Internal view function to get detailed information about a token.
    function _tokenPixelInfo(uint256 _tokenId) internal view returns (AStructs.tokenPixelInfo memory) {
        // Retrieve various attributes of the token using its ID.

        uint256 coordinates = tokenIdCoordinates[_tokenId];

        (uint128 x, uint128 y) = AStructs.decodeCoordinates(coordinates);

        // Construct and return the full traits of the token.
        return AStructs.tokenPixelInfo({
            tokenId: _tokenId,
            x: x,
            y: y,
            color: pixelsColor[coordinates],
            lastPainter: lastPainter[coordinates],
            lastTimePainted: lastTimePainted[coordinates]
        });
    }

    function playerCanvasInfo(address _player) external view returns (AStructs.playerCanvasInfo memory) {
        return _playerCanvasInfo(_player);
    }

    // Internal view function to get detailed information about a token.
    function _playerCanvasInfo(address _player) internal view returns (AStructs.playerCanvasInfo memory) {
        // Construct and return the full traits of the token.
        return AStructs.playerCanvasInfo({
            player: _player,
            canvasSize: canvasSize,
            canvasPot: canvasPot,
            dailyPaintCount: dailyPaintCount[_player],
            currentPaintedPixels: currentPaintedPixels[_player],
            totalPaintedPixels: totalPaintedPixels[_player],
            dailyPaintTimestamp: dailyPaintTimestamp[_player]
        });
    }

    // Internal view function to convert VUND tokens to ATON tokens.
    // PVT and Canvas
    function _getVUNDtoATON(uint256 _amountVUND) internal view returns (uint256) {
        // Calculate the ATON equivalent of the VUND amount using a conversion factor.

        return PVT.getVUNDtoATON(_amountVUND);
    }

    modifier onlyPVT() {
        require(msg.sender == address(PVT), "Not authorized: caller is not the PVT");
        _;
    }

    function removePixels(uint256[3] memory _tokenIdsFuse) external nonReentrant onlyPVT returns (bool) {
        for (uint256 i = 0; i < 3; i++) {
            // If the category is Pixel, update the mappings accordingly
            uint256 encodedCoordinate = tokenIdCoordinates[_tokenIdsFuse[i]];
            pixelsTokenId[encodedCoordinate] = 0;
            tokenIdCoordinates[_tokenIdsFuse[i]] = 0;
        }

        return true;
    }

    function getPixelColor(uint256 _tokenId) external view returns (uint8) {
        return pixelsColor[_tokenId];
    }
}
// All rights reserved. This software and associated documentation files (the "Software"),
// cannot be used, copied, modified, merged, published, distributed, sublicensed, and/or
// sold without the express and written permission of the owner.
