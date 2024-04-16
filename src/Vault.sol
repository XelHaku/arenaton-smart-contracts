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

import "./interfaces/IATON.sol";
import "./libraries/AStructs.sol";
import "./libraries/Tools.sol";
import "./libraries/EventsLib.sol";
import "./libraries/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol"; // Provides mechanisms for ownership control
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Vault Contract
 * @dev The Vault contract provides a secure and efficient way to manage staking and rewards within the ecosystem.
 * Players can stake their tokens, participate in events, and receive rewards based on their participation.
 * This contract ensures proper access control and protection against reentrancy attacks.
 */
contract Vault is AccessControl, ReentrancyGuard, ERC20, Ownable {
    using AStructs for AStructs.Event;
    // Define constants and state variables

    // Denominator used for percentage calculations to accommodate decimals
    uint256 constant pct_denom = 10000000;

    // Role identifier for ARENATON_ROLE
    bytes32 private constant ARENATON_ROLE = keccak256("ARENATON_ROLE");
    // Role identifier for SWAP_ROLE
    bytes32 private constant SWAP_ROLE = keccak256("SWAP_ROLE");

    // Mapping to store the last accumulated commission per token for each player
    mapping(address => uint256) private lastAccumulatedCommissionPerTokenForPlayer;

    // Represents the total accumulated commission per token
    uint256 public accumulatedCommissionPerToken;

    // Stores the total commission in VUND
    uint256 public totalCommissionVUND;

    // Reference to the ATON token contract
    IATON private ATON;

    // Address of the contract owner/deployer

    AStructs.Coin[] private coinList;
    mapping(address => uint256) private coinIndex;

    // Stores information about each Event using its unique event ID.
    mapping(bytes8 => AStructs.Event) private events;

    // Maintains a count of the total Events stored within the contract.
    uint256 public eventCount;

    // Stores information about each player based on their Ethereum address.
    mapping(address => AStructs.Player) players;

    // Contains the event IDs of currently active events.
    bytes8[] private activeEvents;

    //  Commision sharing
    /**
     * @dev Constructor to initialize the contract with supported coins and ATON token.
     * @param _coins An array of addresses representing supported coins.
     * @param _ATON Address of the ATON token contract.
     */
    constructor(address[] memory _coins, address _ATON) ERC20("Vault Unity Dollar", "VUND") Ownable(msg.sender) {
        // Initialize the ATON token contract reference
        ATON = IATON(_ATON);

        emit EventsLib.ATONAddressSet(_ATON);

        _addCoin(address(this));

        // Iterate through provided coins and add them to the supported list
        for (uint256 i = 0; i < _coins.length; i++) {
            _addCoin(_coins[i]);
        }
    }

    /**
     * @dev Get the address of the ATON token contract.
     * @return The address of the ATON token contract.
     */
    function ATONtoken() public view returns (address) {
        return address(ATON);
    }

    /**
     * @dev Get the address of the ATON token contract.
     * @return The address of the ATON token contract.
     */
    function getARENATON_ROLE() public pure returns (bytes32) {
        return ARENATON_ROLE;
    }

    /**
     * @dev Get the address of the ATON token contract.
     * @return The address of the ATON token contract.
     */
    function getSport(bytes8 _eventIdBytes) external view returns (uint8) {
        return events[_eventIdBytes].sport;
    }

    /**
     * @dev Internal function to add a coin to the supported list.
     * @param _coinAddress Address of the coin to be added.
     */
    function _addCoin(address _coinAddress) internal {
        // Variables to hold the coin's symbol and decimals
        string memory _symbol;
        uint8 _decimals;
        ERC20 token = ERC20(_coinAddress);

        // If the coin is this contract (VUND), fetch the symbol and decimals directly
        if (_coinAddress == address(this)) {
            _symbol = symbol();
            _decimals = decimals();
        } else {
            // If the coin is another ERC20 token, fetch the symbol and decimals from the token contract
            _symbol = token.symbol();
            _decimals = token.decimals();
        }

        // Add the coin to the list
        coinList.push(
            AStructs.Coin({
                token: _coinAddress,
                decimals: _decimals,
                balance: 0,
                balanceVUND: 0,
                active: true,
                symbol: _symbol,
                allowance: 0
            })
        );

        // Update the index mapping for the coin
        coinIndex[_coinAddress] = coinList.length - 1;
    }

    /**
     * @notice Toggles the active status of a specified coin.
     * If the coin is active, it will be made inactive and vice-versa.
     *
     * Requirements:
     * - The caller must have DEFAULT_ADMIN_ROLE.
     *
     * @param _coinAddress The address of the coin/token whose active status is to be toggled.
     */
    function toggleCoinActiveStatus(address _coinAddress) external onlyOwner {
        // Get the index of the specified coin in the coinList array.
        uint256 coinIdx = coinIndex[_coinAddress];

        // Toggle the active status of the coin.
        coinList[coinIdx].active = !coinList[coinIdx].active;
    }

    /**
     * @dev Grants the ARENATON_ROLE to a specified address, allowing it to perform specific functions.
     * @param authorizedAddress The address to be granted the ARENATON_ROLE.
     * @param role The role to be granted.
     */
    function addAuthorizedAddress(address authorizedAddress, string memory role) external onlyOwner {
        _grantRole(keccak256(abi.encodePacked(role)), authorizedAddress);
    }

    /**
     * @dev Revokes the ARENATON_ROLE from a specified address.
     * @param authorizedAddress The address to have the ARENATON_ROLE revoked.
     */
    function removeAuthorizedAddress(address authorizedAddress, string memory role) external onlyOwner {
        _revokeRole(keccak256(abi.encodePacked(role)), authorizedAddress);
    }

    /**
     * @dev Converts a given amount of a specific coin to its equivalent in VUND.
     * This is a public interface for the internal `Tools.convertCoinToVUND` function.
     * @param _coinAddress Address of the coin to be converted.
     * @param _amountCoinIn Amount of coin to be converted.
     * @return vundAmount Equivalent amount of VUND.
     * @return adjustedCoinAmount Adjusted amount of input coin after conversion (if any adjustments needed).
     */
    function convertCoinToVUND(address _coinAddress, uint256 _amountCoinIn)
        external
        view
        returns (uint256 vundAmount, uint256 adjustedCoinAmount)
    {
        AStructs.Coin memory coin = coinList[coinIndex[_coinAddress]];
        return Tools.convertCoinToVUND(_amountCoinIn, coin);
    }

    /**
     * @dev Converts a given amount of VUND to its equivalent in a specific coin.
     * This is a public interface for the internal `_convertVUNDToCoin` function.
     * @param _coinAddress Address of the target coin for the conversion.
     * @param _vundAmount Amount of VUND to be converted.
     * @return vundAmount Equivalent amount of the target coin.
     * @return adjustedCoinAmount Adjusted amount of VUND after conversion (if any adjustments needed).
     */
    function convertVUNDToCoin(address _coinAddress, uint256 _vundAmount)
        external
        view
        returns (uint256 vundAmount, uint256 adjustedCoinAmount)
    {
        AStructs.Coin memory coin = coinList[coinIndex[_coinAddress]];

        return Tools.convertVUNDToCoin(_vundAmount, coin);
    }

    /**
     * @dev Retrieves a specified amount of COIN tokens from a player's wallet.
     * @param _player Address of the player.
     * @param _amountCoin Amount of COIN tokens to retrieve.
     * @param _token Address of the COIN token contract.
     * @param _amountBurn Amount to burn
     */
    function retrieveCoin(address _player, uint256 _amountCoin, address _token, uint256 _amountBurn)
        external
        onlyRole(ARENATON_ROLE)
        nonReentrant
    {
        // Ensure the contract is authorized to retrieve the specified amount of COIN.

        // Transfer the COIN tokens from the player to this contract.
        if (_token == address(this)) {
            _transfer(_player, address(this), _amountCoin);
        } else {
            ERC20 token = ERC20(_token);
            require(token.allowance(_player, address(this)) >= _amountCoin, "allowance COIN");
            require(token.transferFrom(_player, address(this), _amountCoin));
        }

        if (_token == address(ATON)) {
            // Burn the specified amount of ATON tokens from the contract's account
            require(ATON.burnFrom(_amountBurn));
        }
    }

    // Internal function to check if an event with the given event ID exists
    function _ifEventExists(bytes8 _eventIdBytes) internal view returns (bool) {
        // Check if the stakeCount property of the event is greater than zero
        // If it is, then the event exists; otherwise, it does not exist
        return (events[_eventIdBytes].stakeCount > 0);
    }

    /**
     * @dev Allows the contract manager to add a new sports event.
     *
     * This function is responsible for:
     * - Distributing the accumulated commission to the contract (intended for the owner later).
     * - Validating the provided inputs for the new event.
     * - Creating and initializing a new event.
     * - Incrementing the event count.
     * - Registering the event in the active events list.
     * - Emitting an event signaling the creation of the new event.
     *
     * @param _eventIdBytes - Unique byte identifier for the event.
     * @param _startDate - Timestamp indicating the start date of the event.
     * @param _sport - ID that corresponds to the specific sport of the event.
     */
    function addEvent(bytes8 _eventIdBytes, uint64 _startDate, uint8 _sport, address _player)
        external
        onlyRole(ARENATON_ROLE)
        nonReentrant
    {
        // Distribute the accumulated commission to the contract. This ensures that the owner
        // can later claim their rewards.

        // Validate the inputs:

        require(
            _startDate > block.timestamp && !events[_eventIdBytes].active && !_ifEventExists(_eventIdBytes),
            "Invalid event setup"
        );

        // Create a new event and initialize its properties:
        events[_eventIdBytes].populateEvent(_eventIdBytes, _startDate, _sport);
        eventCount += 1;

        // Register the new event in the active events list.
        activeEvents.push(_eventIdBytes);
        players[_player].level += 1;

        // Emit an event signaling the creation of the new event.
        emit EventsLib.EventOpened(
            Tools._bytes8ToString(_eventIdBytes), // Convert the bytes8 event ID to string
            msg.sender, // Address of the entity adding the event
            Tools._bytes8ToString(_eventIdBytes), // Convert the bytes8 event ID to string (redundant and can be optimized)
            msg.sender, // Address of the entity adding the event (redundant and can be optimized)
            _sport, // The associated sport's ID
            _startDate // The event's start date
        );
    }

    // Function to retrieve Event details in a DTO (Data Transfer Object) format
    // This function allows external callers to get the details of an event in a structured format.
    // It takes an `_eventIdBytes` parameter, which is the identifier of the event.
    // The function returns an EventDTO containing important event details.
    function getEventDTO(bytes8 _eventIdBytes) external view returns (AStructs.EventDTO memory) {
        return (_getEventDTO(_eventIdBytes));
    }

    // Internal function to retrieve Event details in a DTO (Data Transfer Object) format
    // This function is used internally to fetch event details in a structured format.
    // It takes an `_eventIdBytes` parameter, which is the identifier of the event.
    // The function returns an EventDTO containing important event details.
    function _getEventDTO(bytes8 _eventIdBytes) internal view returns (AStructs.EventDTO memory) {
        // Construct an EventDTO by extracting details from the 'events' mapping
        return (
            AStructs.EventDTO(
                Tools._bytes8ToString(events[_eventIdBytes].eventIdBytes), // Convert bytes8 to string
                events[_eventIdBytes].startDate, // Start date of the event
                events[_eventIdBytes].sport, // Sport associated with the event
                events[_eventIdBytes].totalVUND[0], // Total VUND staked for Team A
                events[_eventIdBytes].totalVUND[1], // Total VUND staked for Team B
                events[_eventIdBytes].totalATON[0], // Total ATON staked for Team A
                events[_eventIdBytes].totalATON[1], // Total ATON staked for Team B
                events[_eventIdBytes].maxStakeVUND, // Factor for ATON rewards calculation
                events[_eventIdBytes].active, // Indicates if the event is active
                events[_eventIdBytes].scoreA, // Score of Team A
                events[_eventIdBytes].scoreB, // Score of Team B
                events[_eventIdBytes].winner, // Winner of the event
                events[_eventIdBytes].factorATON, // Factor for ATON rewards calculation
                0, //eventState
                false
            )
        );
    }

    /**
     * @notice Fetches the list of EventDTOs based on provided eventIds.
     * @param eventIds An array of eventIds for which to fetch the EventDTOs.
     * @return eventDTOs An array of EventDTOs corresponding to the provided eventIds.
     */
    function getEventDTOList(bytes8[] memory eventIds) external view returns (AStructs.EventDTO[] memory) {
        // Determine the length of the provided eventIds
        uint256 length = eventIds.length;

        // Initialize a new memory array to hold the results
        AStructs.EventDTO[] memory eventDTOs = new AStructs.EventDTO[](length);

        // Iterate through each eventId and fetch the corresponding EventDTO
        for (uint256 i = 0; i < length; i++) {
            eventDTOs[i] = _getEventDTO(eventIds[i]);
        }

        // Return the array of EventDTOs
        return eventDTOs;
    }

    /**
     * @notice Fetch active sports events. If `_sport` is less than 0, fetches all active events.
     * @param _sport The sport identifier. If negative, returns all sports events.
     * @return activeEventsDTO A list of DTOs representing the active events.
     */
    function getActiveEvents(int8 _sport) external view returns (AStructs.EventDTO[] memory) {
        // Use a dynamic array for matched events
        AStructs.EventDTO[] memory tempActiveEventsDTO = new AStructs.EventDTO[](activeEvents.length);
        uint256 count = 0;

        for (uint256 i = 0; i < activeEvents.length; i++) {
            AStructs.EventDTO memory currentEvent = _getEventDTO(activeEvents[i]);
            if (currentEvent.sport == uint8(_sport) || _sport < 0) {
                tempActiveEventsDTO[count] = currentEvent;
                count++;
            }
        }

        // Convert the dynamic array to a fixed-size array
        AStructs.EventDTO[] memory finalActiveEventsDTO = new AStructs.EventDTO[](count);
        for (uint256 i = 0; i < count; i++) {
            finalActiveEventsDTO[i] = tempActiveEventsDTO[i];
        }

        return finalActiveEventsDTO;
    }

    /**
     * @dev Get the list of players who participated in a specific Event.
     * @param _eventIdBytes The Event ID for which to retrieve the list of players.
     * @return An array of addresses representing the players who participated in the Event.
     */
    function EventPlayers(bytes8 _eventIdBytes) public view returns (address[] memory) {
        return events[_eventIdBytes].players;
    }

    /**
     * @dev Get the list of active Events in which a player has participated.
     * @param _player The address of the player whose active Events are being queried.
     * @return An array of Event IDs representing the active Events for the player.
     */
    function getPlayerActiveEvents(address _player) external view returns (AStructs.EventDTO[] memory) {
        // Use a dynamic array for matched events
        AStructs.EventDTO[] memory tempActiveEventsDTO = new AStructs.EventDTO[](players[_player].activeEvents.length);
        uint256 count = 0;

        for (uint256 i = 0; i < activeEvents.length; i++) {
            AStructs.EventDTO memory currentEvent = _getEventDTO(activeEvents[i]);
            tempActiveEventsDTO[count] = currentEvent;
            count++;
        }

        // Convert the dynamic array to a fixed-size array
        AStructs.EventDTO[] memory finalActiveEventsDTO = new AStructs.EventDTO[](count);
        for (uint256 i = 0; i < count; i++) {
            finalActiveEventsDTO[i] = tempActiveEventsDTO[i];
        }

        return finalActiveEventsDTO;
    }

    /**
     * @dev Get the list of closed Events in which a player has participated.
     * @param _player The address of the player whose closed Events are being queried.
     * @return An array of Event IDs representing the closed Events for the player.
     */
    function getPlayerClosedEvents(address _player) external view returns (bytes8[] memory) {
        return players[_player].closedEvents;
    }

    /**
     * @notice Retrieves the level of a specific player.
     * @dev Fetches the level of a player using their Ethereum address. This function is `view` type,
     * meaning it only reads data from the blockchain and does not modify any state.
     * @param _player The Ethereum address of the player whose level is being queried.
     * @return uint256 The level of the player associated with the provided Ethereum address.
     */
    function getPlayerLevel(address _player) external view returns (uint256) {
        return players[_player].level;
    }

    /**
     * @dev Get the length of the active events array.
     * @return The length of the active events array.
     */
    function ActiveEventsLength() public view returns (uint256) {
        return activeEvents.length;
    }

    /**
     * @dev Add a stake to a specific Event for a player and team.
     * @param _eventIdBytes The Event ID for which the stake is being added.
     * @param _coinAddress The amount of VUND being staked.
     * @param _amountCoinIn The amount of VUND being staked.
     * @param _amountATON The amount of ATON being staked.
     * @param _team The team for which the stake is being placed (0 for Team A, 1 for Team B).
     * @param _player The address of the player adding the stake.
     */
    function addStake(
        bytes8 _eventIdBytes,
        address _coinAddress, //VUND, USDT , USDC, DAI
        uint256 _amountCoinIn,
        uint256 _amountATON,
        uint8 _team,
        address _player,
        bool _isOpenEvent
    ) external onlyRole(ARENATON_ROLE) nonReentrant {
        AStructs.Coin memory coin = coinList[coinIndex[_coinAddress]];
        (uint256 amountVUND,) = Tools.convertCoinToVUND(_amountCoinIn, coin);

        if (_coinAddress != address(this)) {
            _mint(address(this), amountVUND);
        }

        // Reference for the event
        AStructs.Event storage currentEvent = events[_eventIdBytes];
        // Ensure the Event's start date is in the future, the Event is active and coin is active
        require(coin.active && currentEvent.startDate > block.timestamp && currentEvent.active, "add Stake failed");

        // Reference for the stake
        AStructs.Stake storage playerStake = currentEvent.stakes[_player];

        // Update the stake values
        if (playerStake.amountATON == 0 && playerStake.amountVUND == 0) {
            playerStake.amountVUND = amountVUND;
            playerStake.amountATON = _amountATON;
            playerStake.team = _team;
        } else if (playerStake.team == _team) {
            playerStake.amountVUND += amountVUND;
            playerStake.amountATON += _amountATON;
        } else {
            revert("Wrong team");
        }
        // Update total stakes for the event
        currentEvent.totalVUND[_team - 1] += amountVUND;
        currentEvent.totalATON[_team - 1] += _amountATON;

        // Check and add the event to player's active events if not added
        if (!_isEventAddedToPlayer(_player, _eventIdBytes)) {
            players[_player].activeEvents.push(_eventIdBytes);
            currentEvent.players.push(_player);
        }

        // Check max stake for the event
        if (amountVUND > currentEvent.maxStakeVUND) {
            currentEvent.maxStakeVUND = amountVUND;
            players[_player].level += 1;
        }

        // Increment the stake count for the Event
        events[_eventIdBytes].stakeCount++;
        if (!events[_eventIdBytes].isOpenEvent[_player]) {
            events[_eventIdBytes].isOpenEvent[_player] = _isOpenEvent;
        }

        emit EventsLib.StakeAdded(
            Tools._bytes8ToString(_eventIdBytes),
            _player,
            Tools._bytes8ToString(_eventIdBytes),
            _player,
            amountVUND,
            _amountATON,
            _team
        );
    }

    // Helper function to check if an event is added to the player's active events
    function _isEventAddedToPlayer(address _player, bytes8 _eventIdBytes) internal view returns (bool) {
        for (uint256 i = 0; i < players[_player].activeEvents.length; i++) {
            if (players[_player].activeEvents[i] == _eventIdBytes) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Closes an active sports event, updates the final results, and removes it from the list of active events.
     * @param _eventIdBytes The unique identifier for the event.
     * @param _winner The result of the event (-1 for tie, 0 for Team A, 1 for Team B).
     * @param _scoreA The final score for Team A.
     * @param _scoreB The final score for Team B.
     * @param _player The address initiating the event closure, typically the event manager or a similar role.
     */
    function closeEvent(bytes8 _eventIdBytes, int8 _winner, uint8 _scoreA, uint8 _scoreB, address _player)
        external
        onlyRole(ARENATON_ROLE)
    {
        // Distribute the accumulated commission to the contract address.
        // This helps to ensure that the owner can later claim their rewards.

        // Ensure the event is currently active and has not been previously closed.
        require(events[_eventIdBytes].active && events[_eventIdBytes].winner == -1, "Event closed");

        // Close the event and update its final result and scores.
        // Deactivate the event.
        events[_eventIdBytes].active = false;

        // Set the winner of the event.
        events[_eventIdBytes].winner = _winner;

        // Update the scores for both teams.
        events[_eventIdBytes].scoreA = _scoreA;
        events[_eventIdBytes].scoreB = _scoreB;

        // Calculate and store the ATON factor related to this event.
        // The factor is sourced from another contract and may be used for rewards calculation or other purposes.
        events[_eventIdBytes].factorATON = ATON.calculateFactorAton();

        // Remove this event from the list of active events to indicate it has been concluded.
        _removeEventFromActiveEvents(_eventIdBytes);

        // Emit an event indicating that this sports event has been closed.
        // This provides an on-chain record of the event's conclusion and the final scores.
        emit EventsLib.EventClosed(
            Tools._bytes8ToString(_eventIdBytes), // Convert the byte identifier to string for better readability.
            _player, // Address that initiated the event closure.
            Tools._bytes8ToString(_eventIdBytes), // Reiteration of the event ID as a string.
            _player, // Reiteration of the initiating address.
            events[_eventIdBytes].sport, // ID indicating the type of sport for the event.
            events[_eventIdBytes].startDate // Timestamp indicating when the event started.
        );

        players[_player].level += 1;
    }

    // Function to remove a Event from the active events list
    function _removeEventFromActiveEvents(bytes8 _eventIdBytes) internal {
        // Check if the Event is active
        // require(events[_eventId].active, 'Event is not active');
        // bytes8 _eventIdBytes = stringToBytes8(_eventId);

        // Find the index of the Event in the activeEvents array
        uint256 indexToRemove = activeEvents.length;
        for (uint256 i = 0; i < activeEvents.length; i++) {
            if (activeEvents[i] == _eventIdBytes) {
                indexToRemove = i;
                break;
            }
        }

        // If the Event is found in the activeEvents array, remove it
        require(indexToRemove < activeEvents.length, "Not found activeEvents");

        // Swap the Event to remove with the last Event in the array and then pop (remove) the last element
        activeEvents[indexToRemove] = activeEvents[activeEvents.length - 1];
        activeEvents.pop();

        // Update the Event's active status and decrement the activeEventsCount
        events[_eventIdBytes].active = false;
    }

    /**
     * @dev Get the VUND based on the Event ID and context (team or overall, effective or raw).
     * @param _eventIdBytes The Event ID.
     * @param _context Can be WholeRawVUND, TeamARawVUND, TeamBRawVUND, WholeEffectiveVUND, TeamAEffectiveVUND, or TeamBEffectiveVUND.
     * @return VUND based on the given context.
     */
    function getEventStakedVUND(bytes8 _eventIdBytes, uint8 _context) external view returns (uint256) {
        if (_context == AStructs.WholeRawVUND) {
            return events[_eventIdBytes].totalVUND[AStructs.TEAM_A - 1]
                + events[_eventIdBytes].totalVUND[AStructs.TEAM_B - 1];
        } else if (_context == AStructs.TeamARawVUND) {
            return events[_eventIdBytes].totalVUND[AStructs.TEAM_A - 1];
        } else if (_context == AStructs.TeamBRawVUND) {
            return events[_eventIdBytes].totalVUND[AStructs.TEAM_B - 1];
        } else {
            uint256 factorATON = events[_eventIdBytes].factorATON;
            if (factorATON == 0) {
                factorATON = ATON.calculateFactorAton();
            }

            if (_context == AStructs.WholeEffectiveVUND) {
                uint256 effectiveEventVUND;
                for (uint256 i = 0; i < events[_eventIdBytes].totalVUND.length; i++) {
                    effectiveEventVUND += (
                        events[_eventIdBytes].totalVUND[i]
                            + (events[_eventIdBytes].totalATON[i] * factorATON) / pct_denom
                    );
                }
                return effectiveEventVUND;
            } else if (_context == AStructs.TeamAEffectiveVUND) {
                return events[_eventIdBytes].totalVUND[AStructs.TEAM_A - 1]
                    + (events[_eventIdBytes].totalATON[AStructs.TEAM_A - 1] * factorATON) / pct_denom;
            } else if (_context == AStructs.TeamBEffectiveVUND) {
                return events[_eventIdBytes].totalVUND[AStructs.TEAM_B - 1]
                    + (events[_eventIdBytes].totalATON[AStructs.TEAM_B - 1] * factorATON) / pct_denom;
            }
        }

        revert("Invalid context provided.");
    }

    /**
     * @dev Get the list of players who participated in a specific Event.
     * @param _eventIdBytes The Event ID for which the players are being retrieved.
     * @return An array of addresses representing the participants of the Event.
     */
    function getEventPlayers(bytes8 _eventIdBytes) external view returns (address[] memory) {
        return events[_eventIdBytes].players;
    }

    /**
     * @dev Retrieve a player's stake details for a specific Event.
     * @param _eventIdBytes The Event ID.
     * @param _player Player's address.
     * @return Stake details for the specified player and Event.
     */
    function getPlayerStake(bytes8 _eventIdBytes, address _player) external view returns (AStructs.StakeDTO memory) {
        return _getPlayerStake(_eventIdBytes, _player);
    }

    /**
     * @dev Internal function to fetch a player's stake details for a specific Event.
     * @param _eventIdBytes The Event ID.
     * @param _player Player's address.
     * @return Stake details for the specified player and Event.
     */
    function _getPlayerStake(bytes8 _eventIdBytes, address _player) internal view returns (AStructs.StakeDTO memory) {
        uint256 factorATON = events[_eventIdBytes].factorATON;

        if (factorATON == 0) {
            factorATON = ATON.calculateFactorAton();
        }

        AStructs.Stake memory stake = events[_eventIdBytes].stakes[_player];
        uint256 effectivePlayerStake = stake.amountVUND + (stake.amountATON * factorATON) / pct_denom;

        uint8 team = stake.team;

        if (effectivePlayerStake == 0) {
            team = 0;
        }

        return AStructs.StakeDTO(stake.amountVUND, stake.amountATON, team, effectivePlayerStake);
    }

    /**
     * @dev Check if a player's stake for a given Event has been finalized.
     * @param _eventIdBytes The Event ID.
     * @param _player Player's address.
     * @return True if the stake has been finalized, false otherwise.
     */
    function isPlayerFinalizedEvent(bytes8 _eventIdBytes, address _player) external view returns (bool) {
        return events[_eventIdBytes].stakeFinalized[_player];
    }

    /**
     * @dev Finalize a player's stake for a specific Event.
     * @param _eventIdBytes The Event ID.
     * @param _player Player's address.
     * @return True on successful finalization, false otherwise.
     */
    function setPlayerFinalizedEvent(bytes8 _eventIdBytes, address _player)
        external
        onlyRole(ARENATON_ROLE)
        returns (bool)
    {
        // Make sure Player has participated in the event
        if (events[_eventIdBytes].stakes[_player].amountVUND > 0) {
            // Set the player's stake as finalized
            events[_eventIdBytes].stakeFinalized[_player] = true;
            // Remove event form Active List
            _removePlayerActiveEvent(_eventIdBytes, _player);
            // Add to closed list
            players[_player].closedEvents.push(_eventIdBytes);

            if (events[_eventIdBytes].winner == int8(events[_eventIdBytes].stakes[_player].team)) {
                players[_player].winCount[0] += 1;
                players[_player].winCount[events[_eventIdBytes].sport] += 1;
                players[_player].level += 3;

                if (events[_eventIdBytes].isOpenEvent[_player]) {
                    players[_player].openWinCount[0] += 1;
                    players[_player].openWinCount[events[_eventIdBytes].sport] += 1;
                }
            } else if (events[_eventIdBytes].winner == -2 || events[_eventIdBytes].winner == -3) {
                players[_player].level += 2;
                players[_player].lossCount[0] += 1;
                players[_player].lossCount[events[_eventIdBytes].sport] += 1;
            } else {
                players[_player].level += 1;
            }

            players[_player].totalCount[0] += 1;
            players[_player].totalCount[events[_eventIdBytes].sport] += 1;
        }
        return true;
    }

    /**
     * @dev Add earnings to a player's balances for a specific Event and category.
     * @param _player The address of the player whose earnings are being added.
     */
    function eventOpenWinCount(address _player, uint8 _sport) external view returns (uint256) {
        return players[_player].openWinCount[_sport];
    }

    /**
     * @dev Add earnings to a player's balances for a specific Event and category.
     * @param _player The address of the player whose earnings are being added.
     */
    function eventWinCount(address _player, uint8 _sport) external view returns (uint256) {
        return players[_player].winCount[_sport];
    }

    /**
     * @dev Add earnings to a player's balances for a specific Event and category.
     * @param _player The address of the player whose earnings are being added.
     * @param _amountVUND The amount of VUND earnings to be added.
     * @param _amountATON The amount of ATON earnings to be added.
     * @param _eventIdBytes The Event ID for which earnings are being added.
     * @param _category The category of earnings being added (0: Loss Stake, 1: Won Stake, etc.).
     */
    function addEarningsToPlayer(
        address _player,
        uint256 _amountVUND,
        uint256 _amountATON,
        bytes8 _eventIdBytes,
        uint8 _category
    ) external onlyRole(ARENATON_ROLE) {
        _addEarningsToPlayer(_player, _amountVUND, _amountATON, _eventIdBytes, _category);
    }

    /**
     * @dev Internal function to add earnings to a player's balances.
     * @param _player The address of the player whose earnings are being added.
     * @param _amountVUND The amount of VUND earnings to be added.
     * @param _amountATON The amount of ATON earnings to be added.
     * @param _eventIdBytes The Event ID for which earnings are being added.
     * @param _category The category of earnings being added (0: Loss Stake, 1: Won Stake, etc.).
     */
    function _addEarningsToPlayer(
        address _player,
        uint256 _amountVUND,
        uint256 _amountATON,
        bytes8 _eventIdBytes,
        uint8 _category // 0 Loss Stake, 1 Won Stake, 2 Tie Stake, 3 Cancelled Event, 4 Open Event Reward, 5 Close Event Reward, 6 Referral ,7 Max VUND stake,10 Vault Fee
    ) internal {
        // Update player balances before any external interaction.
        address recipient;
        if (_player == address(this)) {
            recipient = owner();
        } else {
            recipient = _player;
        }

        ATON.transfer(recipient, _amountATON);

        if (_amountVUND > 0) {
            if (uint8(AStructs.EarningCategory.VaultFee) == _category) {
                _accumulateCommission(_amountVUND);
            } else {
                _transfer(address(this), recipient, _amountVUND);
            }
        }

        emit EventsLib.Earnings(
            Tools._bytes8ToString(_eventIdBytes),
            _player,
            Tools._bytes8ToString(_eventIdBytes),
            _player,
            _amountVUND, // Amount of VUND earn
            _amountATON, // Amount of ATON earn
            _category // 0 Loss Stake, 1 Won Stake, 2 Tie Stake, 3 Cancelled Event, 4 Open Event Reward, 5 Close Event Reward, 6 Referral ,7 Max VUND stake,8 Singular Stake Return,10 Vault Fee
        );
    }

    /**
     * @dev Removes a specific event from the list of active events of a player.
     * @param _eventIdBytes The ID of the event to be removed.
     * @param _player The address of the player whose active events list is being modified.
     * Internal function, not meant to be called directly.
     */
    function _removePlayerActiveEvent(bytes8 _eventIdBytes, address _player) internal {
        bytes8[] storage playerActiveEvents = players[_player].activeEvents; // Renamed variable
        uint256 length = playerActiveEvents.length;

        // Early exit if no active events
        if (length == 0) {
            revert("Event not found");
        }

        // Find index of the event to remove
        uint256 indexToRemove = length; // Set to length as a sentinel value
        for (uint256 i = 0; i < length; i++) {
            if (playerActiveEvents[i] == _eventIdBytes) {
                indexToRemove = i;
                break;
            }
        }

        // Check if the event was found
        require(indexToRemove < length, "Event not found");

        // Swap the found event with the last event, then remove the last event
        playerActiveEvents[indexToRemove] = playerActiveEvents[length - 1];
        playerActiveEvents.pop();
    }

    /**
     * @dev Converts a bytes8 value to a string.
     * Internal function, not meant to be called directly.
     */
    function getEventPlayerCount(bytes8 eventIdbytes) external view returns (uint256) {
        return events[eventIdbytes].players.length;
    }

    /**
     * @dev Fetches detailed information for each coin held by the contract.
     * @return coinInfos Returns an array containing details for each coin.
     */
    function getCoinList() external view returns (AStructs.Coin[] memory) {
        // Initialize an array with the size equal to the number of coins.
        AStructs.Coin[] memory coinInfos = new AStructs.Coin[](coinList.length);

        // Iterate over all the coins to populate their detailed information.
        for (uint256 i = 0; i < coinList.length; i++) {
            coinInfos[i] = coinList[i];

            uint256 balance;
            uint256 balanceVUND;

            // Special handling if the coin in the list is this contract itself.
            if (coinList[i].token == address(this)) {
                balance = balanceOf(address(this)); // Get the balance of this contract.
                balanceVUND = balance; // If it's this contract, the balance in VUND is equal to its own balance.
            } else {
                // Fetch the balance of current coin for this contract.
                ERC20 token = ERC20(coinList[i].token);
                balance = token.balanceOf(address(this));

                // Convert the current coin's balance to its equivalent in VUND.

                (balanceVUND,) = Tools.convertCoinToVUND(balance, coinList[i]);
            }

            // Populate the balance details for the current coin.
            coinInfos[i].balance = balance;
            coinInfos[i].balanceVUND = balanceVUND;
        }

        // Return the array populated with each coin's detailed information.
        return coinInfos;
    }

    /**
     * @dev This function facilitates the token swapping process. A player provides one type of token and receives another in return, with a commission being taken.
     * @param _player Address of the player initiating the swap.
     * @param _tokenIn Address of the token the player is providing.
     * @param _amountIn Amount of _tokenIn to be swapped.
     * @param _tokenOut Address of the token the player wishes to receive.
     * @param _CommissionPct Commission percentage for the swap.
     * @return bool Returns true if the swap was successful, otherwise false.
     */
    function swap(
        address _player,
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _amountOut,
        uint256 _CommissionPct
    ) external nonReentrant onlyRole(SWAP_ROLE) returns (bool) {
        // Fetch token details using a mapping.
        AStructs.Coin memory coinIn = coinList[coinIndex[_tokenIn]];
        AStructs.Coin memory coinOut = coinList[coinIndex[_tokenOut]];

        require(coinIn.active, "Input token not active for swapping.");

        // Interact with ERC20 tokens.
        ERC20 tokenIn = ERC20(coinIn.token);
        ERC20 tokenOut = ERC20(coinOut.token);

        // Ensure player and contract have enough tokens for the swap.
        require(tokenIn.balanceOf(_player) >= _amountIn, "Insufficient input token balance.");
        (uint256 oneVUND,) = Tools.convertVUNDToCoin(10 ** decimals(), coinOut); // Calculate minimun balance in VUND

        require(tokenOut.balanceOf(address(this)) >= _amountOut + oneVUND, "IB OUT token");

        // Calculate the commission.
        (uint256 CommissionVUND,) = Tools.convertCoinToVUND((_amountOut * _CommissionPct) / pct_denom, coinOut);
        _accumulateCommission(CommissionVUND);

        // Transfer input tokens from player and output tokens to player.
        if (coinIn.token == address(this)) {
            _transfer(_player, address(this), _amountIn);
        } else {
            require(tokenIn.transferFrom(_player, address(this), _amountIn));
        }

        _amountOut = _amountOut - (_amountOut * _CommissionPct) / pct_denom;
        require(tokenOut.transfer(_player, _amountOut));

        emit EventsLib.Swap(_player, _player, coinIn.token, coinOut.token, _amountIn, _amountOut);

        // Handle token balance adjustments.
        require(_mintToRebalance(), "Rebalancing tokens failed.");
        return true;
    }

    /**
     * @dev Ensures the VUND token's supply matches the stable value within the contract.
     * This function recalibrates the VUND supply to match the stable value either by minting or burning VUND tokens.
     * @return bool Returns true if the minting or burning action was successful.
     */
    function _mintToRebalance() internal returns (bool) {
        uint256 totalSupplyStable = 0;

        // Iterate through the coinList to compute the total stable value equivalent in VUND.
        for (uint256 i = 1; i < coinList.length; i++) {
            ERC20 token = ERC20(coinList[i].token);
            // Convert the balance of each coin to its VUND equivalent.
            (uint256 balanceInVUND,) = Tools.convertCoinToVUND(token.balanceOf(address(this)), coinList[i]);
            totalSupplyStable += balanceInVUND;
        }

        uint256 totalSupplyVUND = totalSupply();
        int256 difference = int256(totalSupplyStable) - int256(totalSupplyVUND);

        if (difference > 0) {
            _mint(address(this), uint256(difference));
        } else if (difference < 0) {
            _burn(address(this), uint256(-difference));
        }

        return true;
    }

    /**
     * @dev This function accumulates commission generated from swaps. Commissions are stored as VUND tokens.
     * @param newCommissionVUND The commission amount in VUND tokens.
     */
    function _accumulateCommission(uint256 newCommissionVUND) internal {
        // Calculate commission per token and update total commission.
        accumulatedCommissionPerToken += (newCommissionVUND * (10 ** decimals())) / totalSupply();

        totalCommissionVUND += newCommissionVUND;
        emit EventsLib.Accumulate(newCommissionVUND, accumulatedCommissionPerToken, totalCommissionVUND);
    }

    /**
     * @dev Distributes accumulated commission to a specified player based on their VUND token holdings. The distribution ensures players get their share of profits from commission.
     * @param player Address of the player receiving the commission.
     */
    function _distributeCommission(address player) internal {
        uint256 unclaimedCommission = _playerCommission(player);
        //('unclaimedCommission', unclaimedCommission);
        //
        if (unclaimedCommission > 0) {
            _safeTransfer(address(this), player == address(this) ? owner() : player, unclaimedCommission);
            lastAccumulatedCommissionPerTokenForPlayer[player] = accumulatedCommissionPerToken;
            emit EventsLib.Earnings(
                "", player, "", player, unclaimedCommission, 0, uint8(AStructs.EarningCategory.Commission)
            );
        }
    }

    /**
     * /**
     * @dev Provides an external view for unclaimed commission for a specified player based on their VUND token holdings.
     * @param player Address of the player.
     * @return unclaimedCommission The amount of VUND tokens player can claim as commission.
     */
    function playerCommission(address player) external view returns (uint256 unclaimedCommission) {
        return _playerCommission(player);
    }

    /**
     * @dev Computes the unclaimed commission for a specified player based on their VUND token holdings. This helps in determining the amount of VUND tokens the player is entitled to from the total commission.
     * @param player Address of the player.
     * @return unclaimedCommission The amount of VUND tokens player can claim as commission.
     */
    function _playerCommission(address player) internal view returns (uint256 unclaimedCommission) {
        uint256 owedPerToken = accumulatedCommissionPerToken - lastAccumulatedCommissionPerTokenForPlayer[player];

        if (owedPerToken > 0) {
            unclaimedCommission = (balanceOf(player) * owedPerToken) / (10 ** decimals());

            return unclaimedCommission;
        } else {
            return 0;
        }
    }

    /**
     * @dev Overrides the standard transfer function to ensure commission distribution occurs during transfers. This ensures that both the sender and receiver get their respective commissions before any transfer happens.
     * @param sender Address of the sender.
     * @param recipient Address of the recipient.
     * @param amount Amount of tokens to transfer.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal override {
        _distributeCommission(sender);
        _distributeCommission(recipient);

        super._transfer(sender, recipient, amount);
    }

    /**
     * @dev A safe variant of the standard transfer function, ensuring the sender has enough balance. This prevents unwanted exceptions due to balance checks.
     * @param from Address of the sender.
     * @param to Address of the recipient.
     * @param amount Amount of tokens to transfer.
     */
    function _safeTransfer(address from, address to, uint256 amount) internal {
        if (balanceOf(from) >= amount) {
            super._transfer(from, to, amount);
        }
    }

    function donateVUND(uint256 _amount) external {
        _transfer(msg.sender, address(this), _amount);
        _accumulateCommission(_amount);

        emit EventsLib.Earnings(
            "", address(this), "", address(this), _amount, 0, uint8(AStructs.EarningCategory.Commission)
        );
    }

    // TODO: Donate ATON
    function playerSummary() external {}
}
// All rights reserved. This software and associated documentation files (the "Software"),
// cannot be used, copied, modified, merged, published, distributed, sublicensed, and/or
// sold without the express and written permission of the owner.
