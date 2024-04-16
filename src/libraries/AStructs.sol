// SPDX-License-Identifier: LicenseRef-Proprietary

pragma solidity ^0.8.9;

library AStructs {
    // EarningCategory defines various types of earnings within the platform. This enum enhances code readability by replacing numeric codes with descriptive names, making the contract logic clearer and easier to understand.
    enum EarningCategory {
        LossStake, // Earnings categorized from a lost stake.
        WonStake, // Earnings from a won stake.
        TieStake, // Earnings from a tie stake.
        CancelledEvent, // Earnings returned from a cancelled event.
        OpenEventReward, // Rewards for opening an event.
        CloseEventReward, // Rewards for closing an event.
        Commission, // Commission earnings.
        MaxVUNDStake, // Earnings from maximum VUND stake.
        SingularStake, // Earnings from a singular stake.
        AtonTicket, // Earnings from Aton tickets.
        VaultFee, // Fees collected from the vault.
        PixelPaint, // Earnings from painting pixels.
        PixelLand, // Earnings from land transactions in Pixel.
        PixelSteal, // Earnings from stealing pixels.
        CanvasSize, // Earnings based on canvas size.
        CommissionPower // Earnings from commission power.
    }

    // EventState defines the various states an event can be in throughout its lifecycle. This enum facilitates state management by providing descriptive status labels instead of using plain numbers.
    enum EventState {
        NotInitialized, // Event has not been initialized yet.
        OpenRequest, // Event is in the request phase to be opened.
        StakingOn, // Staking is currently allowed for the event.
        Live, // Event is currently live.
        Ended, // Event has ended.
        CloseRequest, // Request phase for closing the event.
        RewardsPending, // Rewards are being calculated and pending distribution.
        Closed // Event is closed and finalized.
    }

    // Percentage denominator for calculations, set to 10 million for precision.
    uint256 public constant pct_denom = 10000000;

    // Constants to distinguish between raw and effective values.
    bool public constant Raw = true;
    bool public constant Effective = false;

    // Constants to identify various stake types and teams, enhancing code clarity and reducing magic numbers.
    uint8 public constant WholeRawVUND = 0;
    uint8 public constant TeamARawVUND = 1;
    uint8 public constant TeamBRawVUND = 2;
    uint8 public constant WholeEffectiveVUND = 3;
    uint8 public constant TeamAEffectiveVUND = 4;
    uint8 public constant TeamBEffectiveVUND = 5;

    // Team identifiers for clarity in team-related logic.
    uint8 public constant TEAM_A = 1;
    uint8 public constant TEAM_B = 2;

    // Constants defining percentages for various events and stake scenarios, enhancing readability and ease of maintenance.
    uint256 public constant OPEN_EVENT_PCT = 500000; // Opening an event costs 5%.
    uint256 public constant WON_EVENT_PCT = 10000; // Winning an event yields a 0.10% reward.
    uint256 public constant LOST_EVENT_PCT = 50000; // Losing an event costs 0.50%.
    uint256 public constant DRAW_EVENT_PCT = 20000; // Drawing an event yields a 0.20% reward.
    uint256 public constant MAX_STAKE_PCT = 200000; // Maximum stake limited to 2%.
    uint256 public constant MAX_SQUARE_STAKE_PCT = 500000; // Maximum stake for a square event limited to 5%.
    uint256 public constant SINGULAR_STAKE_PCT = 100000; // Singular stake limited to 1%.

    // Role identifier for oracles, using a hash of the string 'ORACLE_ROLE' to ensure uniqueness and security.
    bytes32 constant ORACLE_ROLE = keccak256('ORACLE_ROLE');

    // Structure representing a player's stake in an event
    struct Stake {
        uint256 amountVUND; // Amount of VUND staked
        uint256 amountATON; // Amount of ATON staked
        uint8 team; // 0 = A team, 1 = B team
    }
    // Data transfer object for a player's stake
    struct StakeDTO {
        uint256 stakeVUND; // Amount of VUND staked
        uint256 stakeATON; // Amount of ATON staked
        uint8 team; // 1 = A team, 2 = B team
        uint256 effectivePlayerVUND; // Effective amount of VUND
    }
    // Structure for requesting to open an oracle (event) for betting
    struct OracleOpenRequest {
        bytes8 eventIdBytes; // Unique identifier for the event
        address requester; // Player who makes the request to open or close the event
        uint256 amountCoin; // Amount of COIN in player’s wallet
        address coinAddress; // Address of the COIN token contract
        uint256 amountATON; // Amount of ATON in player’s wallet
        uint8 team; // 0 = A team, 1 = B team
        uint256 time; // Time of the request
    }

    // Structure for requesting to close an oracle (event)
    struct OracleCloseRequest {
        bytes8 eventIdBytes; // Unique identifier for the event
        address requester; // Player who makes the request to open or close the event
        uint256 time; // Time of the request
    }

    // Data transfer object for OracleOpenRequest
    struct OracleOpenRequestDTO {
        string eventId; // Unique identifier for the event
        bool active; // Is the event active?
        uint64 startDate; // Start date of the event
        uint256 time; // Time of the request
    }
    // Data transfer object for OracleCloseRequest
    struct OracleCloseRequestDTO {
        string eventId; // Unique identifier for the event
        bool active; // Is the event active?
        uint64 startDate; // Start date of the event
        uint256 time; // Time of the request
    }

    // Structure representing an event for betting
    struct Event {
        bytes8 eventIdBytes; // Unique identifier for the event
        uint64 startDate; // Start date of the event
        mapping(address => Stake) stakes; // Stakes made by players (keyed by player address)
        mapping(address => bool) stakeFinalized; // Whether player has closed and cashed out earnings
        address[] players; // List of players
        uint256 stakeCount; // Total number of stakes for this event
        uint256 maxStakeVUND; // Maximum stake in VUND from any player
        uint256[2] totalVUND; // Total stakes in VUND (index 0 for team A, index 1 for team B)
        uint256[2] totalATON; // Total stakes in ATON (index 0 for team A, index 1 for team B)
        bool active; // Is the event active?
        uint256 factorATON; // Factor calculated using the parameterized SQRT function of ATON supply
        uint8 scoreA; // Team A's score
        uint8 scoreB; // Team B's score
        int8 winner; // 0 = Team A won, 1 = Team B won, -2 = Tie, -1 = No result yet, -3 = Event Canceled
        uint8 sport; // ID: 1 (assumed for a specific sport)
        bool overtime;
        mapping(address => bool) isOpenEvent; //wheter the player opened the event
    }

    // Data transfer object for an event
    struct EventDTO {
        string eventId; // Unique identifier for the event
        uint64 startDate; // Start date of the event
        uint8 sport; // ID of the sport
        uint256 totalVUND_A; // Total stakes in VUND for team A
        uint256 totalVUND_B; // Total stakes in VUND for team B
        uint256 totalATON_A; // Total stakes in ATON for team A
        uint256 totalATON_B; // Total stakes in ATON for team B
        uint256 maxStakeVUND; // Maximum stake in VUND
        bool active; // Is the event scheduled or finished?
        uint8 scoreA; // Team A's score
        uint8 scoreB; // Team B's score
        int8 winner; // 1 = Team A won, 2 = Team B won, -2 = Tie, -1 = No result yet, 3 = Event Canceled
        uint256 factorATON; // Factor calculated using the parameterized SQRT function of ATON supply
        uint8 eventState; // 0 ,1,2,3=Live ,4,5,6,7
        bool overtime;
    }

    // Structure representing a player's data
    struct Player {
        bytes8[] activeEvents; // Array of active event IDs in which the player is currently participating
        bytes8[] closedEvents; // Array of event IDs for events in which the player has participated and that are now closed
        uint256 level; // The player's current level, representing their experience or skill
        mapping(uint8 => uint256) totalCount; // Maps event category to the total number of events the player has participated in
        mapping(uint8 => uint256) winCount; // Maps event category to the number of events the player has won
        mapping(uint8 => uint256) lossCount; // Maps event category to the number of events the player has lost
        mapping(uint8 => uint256) drawCount; // Maps event category to the number of events that resulted in a draw for the player
        mapping(uint8 => uint256) openCount; // Maps event category to the number of events the player has opened
        mapping(uint8 => uint256) openWinCount; // Maps event category to the number of opened events in which the player also selected the winning team
    }

    // Structure representing a player's coin data
    struct Coin {
        address token; // Address of the coin/token contract
        uint8 decimals; // Number of decimals for the coin/token
        uint256 balance; // Balance of the coin/token held by the player
        uint256 balanceVUND; // Balance of VUND held by the player
        bool active; // Whether the coin/token is active for the player
        string symbol; // Symbol of the coin/token
        uint256 allowance; // Allowance of the coin/token for the player
    }
    struct PixelDTO {
        uint128 x; // X coordinate of the pixel
        uint128 y; // Y coordinate of the pixel
        uint8 color; // 0 = A team, 1 = B team
        uint256 tokenId; // ID of the NFT token representing the pixel
        address painter; // Address of the player who painted the pixel
    }

    struct InEarningsDTO {
        uint256 playerCount; // Amount of VUND staked
        int8 winner; // 1 = A team, 2 = B team
        AStructs.StakeDTO stakeDTO;
        uint256 playerSharePercentage;
        uint256 bonusNFT;
        AStructs.StakeDTO _quoteStakeDTO;
        bytes8 _eventIdBytes;
        uint256 bonusATON;
    }

    struct OutEarningsDTO {
        uint256 earningsVUND;
        uint256 earningsATON;
        uint8 earningCategory;
        bool isVaultFee;
        uint256 bonusATON;
    }

    function getContex(uint8 team, bool raw) internal pure returns (uint8) {
        if (raw) {
            if (team == TEAM_A) {
                return TeamARawVUND;
            } else {
                return TeamBRawVUND;
            }
        } else {
            if (team == TEAM_A) {
                return TeamAEffectiveVUND;
            } else {
                return TeamBEffectiveVUND;
            }
        }
    }

    function populateEvent(Event storage e, bytes8 _eventIdBytes, uint64 _startDate, uint8 _sport) internal {
        e.eventIdBytes = _eventIdBytes;
        e.startDate = _startDate;
        e.stakeCount = 0;
        e.active = true;
        e.winner = -1;
        e.sport = _sport;
        e.factorATON = 0;
        e.overtime = (block.timestamp >= _startDate - 10 minutes);
    }

    struct traitsShort {
        uint8 category; // Category of the NFT trait (0-255)
        uint16 quality; // Quality of the NFT trait (1-65535)
    }

    struct rng {
        uint8 rnd1; // Random Number #1
        uint16 rnd2; // Random Number #2
    }

    struct traitsUpload {
        string uri; // URI of the NFT trait
        uint8 category; // Category of the NFT trait (0-255)
        uint16 quality; // Quality of the NFT trait (1-65535)
        bool staked; // Whether the NFT trait is staked
        bool charged; // Whether the NFT trait is charged
        uint8 color;
    }

    struct traitsFull {
        uint256 tokenId; // ID of the NFT token representing the trait
        uint8 category; // Category of the NFT trait (0-255)
        uint16 quality; // Quality of the NFT trait (1-65535)
        bool staked; // Whether the NFT trait is staked
        bool charged; // Whether the NFT trait is charged
        string uri; // URI of the NFT trait
    }

    struct tokenPixelInfo {
        uint256 tokenId; // ID of the NFT token representing the trait
        uint128 x; // Category of the NFT trait (0-255)
        uint128 y; // Quality of the NFT trait (1-65535)
        uint8 color; // Whether the NFT trait is staked
        address lastPainter; // Whether the NFT trait is charged
        uint256 lastTimePainted; // Maximum quality of the NFT trait (1-65535)
    }

    struct playerCanvasInfo {
        address player;
        uint256 canvasSize; // Size of the canvas (not clear without context)
        uint256 canvasPot;
        uint256 dailyPaintCount;
        uint256 currentPaintedPixels; // Whether the NFT trait is charged
        uint256 totalPaintedPixels; // Whether the NFT trait is charged
        uint256 dailyPaintTimestamp; // Maximum quality of the NFT trait (1-65535)
    }

    struct PvtSummary {
        uint256 tokenCounter; // 0 1 2 3 4 2 13 100
        uint256 chestCount; //true false
        uint256 chestPrice; //true false
        uint256 regularPrice; //true false
        // Power
        uint256 playerPower; //Power Supply from Player NFTs
        uint256 totalPowerSupply; // Total Power Supply from All NFTs
        uint256 unclaimedCommissionVUND;
        uint256 unclaimedCommissionATON;
        uint256 totalCommissionVUND;
        uint256 totalCommissionATON;
        uint256 luck;
        uint256 stakedNftLevel;
        bool claimNFT; // If there is a rolled dice from ChainLink to mint new NFT
        uint256 stakedAtovixCount;
    }

    struct nftData {
        uint256 tokenId;
        traitsFull trait; // 0 1 2 3 4 2 13 100
    }

    function encodeTrait(uint8 category, uint16 quality, bool staked, bool powered, uint8 color) internal pure returns (uint64) {
        // Check to ensure category, quality, and color values are in valid range
        require(category <= 0xFF, 'Category value is too large'); // 8 bits
        require(quality <= 0xFFFF, 'Quality value is too large'); // 16 bits
        require(color <= 0xFF, 'Color value is too large'); // 8 bits

        uint64 stakedBit = staked ? uint64(1) << 63 : 0; // Setting the most significant bit if staked is true
        uint64 poweredBit = powered ? uint64(1) << 47 : 0; // Setting bit 48 if powered is true

        // Encoding category, quality, and color into the uint64
        uint64 encodedCategory = uint64(category) << 40; // Allocating bits 41-48 for category
        uint64 encodedQuality = uint64(quality); // Allocating bits 1-16 for quality
        uint64 encodedColor = uint64(color) << 32; // Allocating bits 33-40 for color

        return stakedBit | poweredBit | encodedCategory | encodedQuality | encodedColor;
    }

    function encodeCoordinates(uint128 x, uint128 y) internal pure returns (uint256) {
        return (uint256(x) << 128) | uint256(y);
    }

    function decodeCoordinates(uint256 encoded) internal pure returns (uint128 x, uint128 y) {
        x = uint128(encoded >> 128); // Shift right by 128 bits to retrieve x
        y = uint128(encoded); // Cast to uint128 to retrieve y (lower 128 bits)
    }
}
// All rights reserved. This software and associated documentation files (the "Software"),
// cannot be used, copied, modified, merged, published, distributed, sublicensed, and/or
// sold without the express and written permission of the owner.
