// SPDX-License-Identifier: LicenseRef-Proprietary

pragma solidity ^0.8.9;
import './AStructs.sol';

library EventsLib {
    /**
     * @title Staking and Event Management Events
     * @notice This section declares events related to staking and managing sports events.
     * These events provide external systems, like user interfaces, with a mechanism to track
     * and display on-chain actions performed by users in real-time.
     */

    /**
     * @dev This event is triggered when a user adds a stake to a sports event.
     *
     * @param eventIdIndexed - A indexed version of the event's unique identifier.
     * Useful for quick filtering in event queries.
     *
     * @param playerIndexed - A indexed version of the player's address who staked.
     * Allows for efficient filtering based on the player's address.
     *
     * @param eventId - The unique identifier of the sports event where the stake was placed.
     *
     * @param player - The address of the player who added the stake.
     *
     * @param amountVUND - The amount of VUND tokens that were staked.
     *
     * @param amountATON - The amount of ATON tokens that were staked.
     *
     * @param team - The team the player has chosen to stake on.
     * 0 represents Team A, and 1 represents Team B.
     */
    event StakeAdded(
        string indexed eventIdIndexed,
        address indexed playerIndexed,
        string eventId,
        address player,
        uint256 amountVUND,
        uint256 amountATON,
        uint8 team
    );

    /**
     * @dev This event is triggered when a user (typically an organizer or admin) adds a new sports event to the platform.
     *
     * @param eventIdIndexed - A indexed version of the newly added event's unique identifier.
     *
     * @param playerIndexed - A indexed version of the player's address who added the new event.
     *
     * @param eventId - The unique identifier of the newly added event.
     *
     * @param player - The address of the player who added the new event.
     *
     * @param sport - An integer identifier representing the type of sport of the event.
     *
     * @param startTime - The start time of the event represented in UNIX timestamp format.
     */
    event EventOpened(
        string indexed eventIdIndexed,
        address indexed playerIndexed,
        string eventId,
        address player,
        uint8 sport,
        uint64 startTime
    );

    /**
     * @dev This event is triggered when a user (typically an organizer or admin) decides to close an existing sports event.
     * Closing an event might typically mean that no further staking or modifications are allowed for that event.
     *
     * @param eventIdIndexed - A indexed version of the closed event's unique identifier.
     *
     * @param playerIndexed - A indexed version of the player's address who closed the event.
     *
     * @param eventId - The unique identifier of the event that was closed.
     *
     * @param player - The address of the player who closed the event.
     *
     * @param sport - An integer identifier representing the type of sport of the closed event.
     *
     * @param startTime - The start time of the closed event represented in UNIX timestamp format.
     */
    event EventClosed(
        string indexed eventIdIndexed,
        address indexed playerIndexed,
        string eventId,
        address player,
        uint8 sport,
        uint64 startTime
    );

    /**
     * @title Player Earnings and Actions Events
     * @notice This section declares events related to players' earnings, token swaps, and other related actions.
     * These events help track on-chain activities and can be used by external systems to notify or display relevant information.
     */

    /**
     * @dev Emitted when a player earns tokens from an event.
     *
     * @param eventIdIndexed - Indexed version of the event ID related to the earnings for efficient filtering.
     *
     * @param playerIndexed - Indexed address of the player who received earnings. Useful for quick lookups.
     *
     * @param eventId - The unique identifier of the event related to the earnings.
     *
     * @param player - The address of the player who earned the tokens.
     *
     * @param amountVUND - The amount of VUND tokens the player earned.
     *
     * @param amountATON - The amount of ATON tokens the player earned.
     *
     * @param category - A numeric identifier for the type of earnings. E.g., 0 for Lost Stake, 1 for Won Stake, etc.
     */
    event Earnings(
        string indexed eventIdIndexed,
        address indexed playerIndexed,
        string eventId,
        address player,
        uint256 amountVUND,
        uint256 amountATON,
        uint8 category
    );

    /**
     * @dev Emitted when a player swaps one token type for another.
     *
     * @param playerIndexed - Indexed address of the player performing the swap.
     *
     * @param player - The address of the player performing the swap.
     *
     * @param tokenIn - The token address that the player is providing.
     *
     * @param tokenOut - The token address that the player is receiving.
     *
     * @param amountIn - The amount of `tokenIn` tokens the player provided.
     *
     * @param amountOut - The amount of `tokenOut` tokens the player received.
     */
    event Swap(address indexed playerIndexed, address player, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    /**
     * @dev Emitted when the accumulated commission in VUND is updated.
     *
     * @param newCommissionVUND - The new amount added to the commission.
     *
     * @param accumulatedCommissionPerToken - The cumulative commission per token up to the current point.
     *
     * @param totalCommissionVUND - The total commission in VUND after the new addition.
     */
    event Accumulate(uint256 newCommissionVUND, uint256 accumulatedCommissionPerToken, uint256 totalCommissionVUND);
    event AccumulateNFT(
        uint256 newCommissionVUND,
        uint256 accumulatedCommissionPerTokenVUND,
        uint256 newCommissionATON,
        uint256 accumulatedCommissionPerTokenATON
    );

    /**
     * @dev Emitted when the contract's ATON address is updated.
     *
     * @param newATONAddress - The new address set for the ATON token.
     */
    event ATONAddressSet(address indexed newATONAddress);

    /**
     * @dev Emitted when two or more NFTs are fused into one.
     *
     * @param player - The address of the player performing the fusion.
     *
     * @param _tokenId0, _tokenId1, _tokenId3 - IDs of the NFTs being fused.
     *
     * @param _tokenIdFused - The ID of the newly created fused NFT.
     *
     * @param category - The category of the fused NFT.
     *
     * @param quality - The quality metric of the fused NFT.
     */
    event fusion(
        address player,
        uint256 _tokenId0,
        uint256 _tokenId1,
        uint256 _tokenId3,
        uint256 _tokenIdFused,
        uint8 category,
        uint16 quality
    );

    /**
     * @dev Emitted when a player increases the maximum size of their canvas.
     *
     * @param player - The address of the player increasing their canvas size.
     *
     * @param newMaxSize - The new maximum size of the player's canvas.
     */
    event CanvasSizeIncrease(address player, uint256 newMaxSize);

    /**
     * @dev Emitted when a player paints a pixel on their canvas.
     *
     * @param player - The address of the player painting the pixel.
     *
     * @param x, y - The coordinates of the painted pixel.
     *
     * @param _color - The color code of the painted pixel.
     */
    event PaintPixel(address player, uint128 x, uint128 y, uint8 _color);

    event ClaimPixel(uint256 _previousTokenId, uint256 _newTokenId, uint128 x, uint128 y, uint16 quality);

    // Events for logging important actions
    event NftRequested(uint256 indexed requestId, address requester);
    event NftMinted(AStructs.traitsShort, address minter);
}
/**
 * Copyright Notice
 *
 * All rights reserved. This software and associated documentation files (the "Software"),
 * cannot be used, copied, modified, merged, published, distributed, sublicensed, and/or
 * sold without the express and written permission of the owner.
 */
