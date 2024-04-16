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

// OpenZeppelin Contracts
import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; // ERC20 standard token implementation.
import "@openzeppelin/contracts/access/AccessControl.sol"; // Role-based access control.
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol"; // Protection against reentrancy attacks.
import "@openzeppelin/contracts/access/Ownable.sol"; // Ownership control mechanisms.

// PRBMath Library

// Custom Interfaces and Libraries
import "./interfaces/IATON.sol"; // Interface for the ATON contract.
import "./interfaces/IVAULT.sol"; // Interface for the VAULT contract.
import "./interfaces/IPVT.sol"; // Interface for the PVT contract.
import "./libraries/AStructs.sol"; // Struct definitions used across the contract.
import "./libraries/Tools.sol"; // Utility functions.
import "./libraries/NFTcategories.sol"; // Definitions related to NFT categories.

// Contract definition for Arenaton.
contract Arenaton is AccessControl, ReentrancyGuard, Ownable {
    // Reference variables for interacting with external contracts.
    IVAULT internal VAULT;
    IATON internal ATON;

    // Address of the NFT Collection contract.
    address public PVT;

    // Arrays to manage oracle requests.
    AStructs.OracleOpenRequest[] public oracleOpenRequests;
    AStructs.OracleCloseRequest[] public oracleCloseRequests;

    // Premium percentage, set to 2%. Represented with precision for calculations.
    uint256 public constant premium = 200000; // TODO: Create a getter and setter for this variable with a modifier for the owner.
    uint256 private minimumStake = 10 ** 18; // TODO: Create a getter and setter for this variable with a modifier for the owner.

    // Constructor for initializing the Arenaton contract with given addresses.
    constructor(address _VAULT, address _ATON) Ownable(msg.sender) {
        VAULT = IVAULT(_VAULT); // Set the VAULT contract address.
        ATON = IATON(_ATON); // Set the ATON contract address.

        // Assign DEFAULT_ADMIN_ROLE to the deployer of the contract.
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Sets the new minimum stake amount.
     * @param _newMinimumStake The new minimum stake amount to be set.
     * This function is only callable by an account with the owner role.
     */
    function setMinimumStake(uint256 _newMinimumStake) public onlyOwner {
        minimumStake = _newMinimumStake;
    }

    /**
     * @dev Adds an oracle address and grants it the ORACLE_ROLE.
     * @param authorizedAddress The address to be given ORACLE_ROLE.
     * This function is only callable by an account with DEFAULT_ADMIN_ROLE.
     */
    function addAuthorizedOracleAddress(address authorizedAddress) public onlyOwner {
        _grantRole(AStructs.ORACLE_ROLE, authorizedAddress);
    }

    /**
     * @dev Removes an oracle address by revoking its ORACLE_ROLE.
     * @param authorizedAddress The address to have ORACLE_ROLE revoked.
     * This function is only callable by an account with DEFAULT_ADMIN_ROLE.
     */
    function removeAuthorizedAddress(address authorizedAddress) public onlyOwner {
        _revokeRole(AStructs.ORACLE_ROLE, authorizedAddress);
    }

    /**
     * @dev Retrieves active events for a given sport.
     * @param _sport The sport for which active events are requested.
     * @return An array of EventDTO structs representing active events.
     */
    function getActiveEvents(int8 _sport) external view returns (AStructs.EventDTO[] memory) {
        AStructs.EventDTO[] memory list = VAULT.getActiveEvents(_sport);
        for (uint256 i = 0; i < list.length; i++) {
            list[i].eventState = _calculateEventState(Tools._stringToBytes8(list[i].eventId), list[i]);
        }

        return list;
    }

    /**
     * @notice Sets the address for the PVT.
     * @dev Allows an administrator to set or update the PVT's address.
     * The caller of this function must have the `DEFAULT_ADMIN_ROLE` role.
     * @param _PVT The Ethereum address representing the new PVT contract.
     */
    function setPVT(address _PVT) external onlyOwner {
        PVT = _PVT;
    }

    /**
     * Retrieves Oracle open requests along with associated event details.
     *
     * @dev This function fetches open requests from the Oracle and combines them with corresponding event details.
     *      It constructs an array of OracleOpenRequestDTO structures, including information such as event ID, active status,
     *      start date, and request time. This provides a comprehensive view of all open Oracle requests and their related event data.
     *
     * @return An array of OracleOpenRequestDTO structs representing open requests and associated event information.
     *
     * The function iterates over the `oracleOpenRequests` array, extracting event details for each request from the VAULT.
     * For each open request, it constructs an OracleOpenRequestDTO, comprising the event's string ID, active status, start date,
     * and the time of the Oracle request. This array of DTOs offers a detailed snapshot of all open Oracle requests,
     * facilitating tracking and management of these requests in the context of their respective events.
     */
    function getOracleOpenRequests() external view returns (AStructs.OracleOpenRequestDTO[] memory) {
        // Array to store the DTOs (Data Transfer Objects) for open Oracle requests.
        AStructs.OracleOpenRequestDTO[] memory requestsDTO =
            new AStructs.OracleOpenRequestDTO[](oracleOpenRequests.length);

        // Iterate through each open request and populate the DTO array with detailed information.
        for (uint256 i = 0; i < oracleOpenRequests.length; i++) {
            // Retrieve detailed event information from the VAULT using the event ID.
            AStructs.EventDTO memory eventDTO = VAULT.getEventDTO(oracleOpenRequests[i].eventIdBytes);

            // Construct an OracleOpenRequestDTO for each request with relevant details.
            AStructs.OracleOpenRequestDTO memory request = AStructs.OracleOpenRequestDTO(
                Tools._bytes8ToString(oracleOpenRequests[i].eventIdBytes),
                eventDTO.active,
                eventDTO.startDate,
                oracleOpenRequests[i].time
            );
            requestsDTO[i] = request;
        }

        return requestsDTO;
    }

    /**
     * Checks if there are Oracle open requests for a specified event.
     *
     * @dev This internal function scans through the `oracleOpenRequests` array to determine if any requests are associated
     *      with the provided event ID. It's used to verify the existence of open requests for a specific event.
     *
     * @param eventIdBytes The unique identifier of the event in bytes8 format.
     *
     * @return A boolean value indicating whether any Oracle open requests exist for the specified event.
     *
     * The function iterates through the `oracleOpenRequests` array, comparing the event ID of each request
     * with the provided `eventIdBytes`. If a match is found, it returns true, signifying the presence of open requests
     * for that event. If no matches are found, it returns false, indicating there are no open requests for the event.
     */
    function _hasOracleOpenRequests(bytes8 eventIdBytes) internal view returns (bool) {
        // Iterate through the oracleOpenRequests array to find a match for the provided event ID.
        for (uint256 i = 0; i < oracleOpenRequests.length; i++) {
            // Check if the eventIdBytes matches the current request's eventIdBytes.
            if (oracleOpenRequests[i].eventIdBytes == eventIdBytes) {
                return true; // A match is found, indicating the presence of open requests.
            }
        }
        return false; // No match found, indicating no open requests for the event.
    }

    /**
     * Retrieves Oracle close requests along with associated event details.
     *
     * @dev This function fetches and combines information from the Oracle close requests and the corresponding event details.
     *      It constructs an array of OracleOpenRequestDTO structures which include event ID, active status, start date, and request time.
     *
     * @return An array of OracleOpenRequestDTO structs representing close requests and associated event information.
     *
     * The function iterates over the `oracleCloseRequests` array, retrieving event details for each request from the VAULT.
     * It then constructs an OracleOpenRequestDTO for each request, containing the event's string ID, active status, start date,
     * and the time of the Oracle request. These DTOs provide a comprehensive view of the close requests and the related event data.
     */
    function getOracleCloseRequests() external view returns (AStructs.OracleOpenRequestDTO[] memory) {
        AStructs.OracleOpenRequestDTO[] memory requestsDTO =
            new AStructs.OracleOpenRequestDTO[](oracleCloseRequests.length);
        for (uint256 i = 0; i < oracleCloseRequests.length; i++) {
            AStructs.EventDTO memory eventDTO = VAULT.getEventDTO(oracleCloseRequests[i].eventIdBytes);

            AStructs.OracleOpenRequestDTO memory request = AStructs.OracleOpenRequestDTO(
                Tools._bytes8ToString(oracleCloseRequests[i].eventIdBytes),
                eventDTO.active,
                eventDTO.startDate,
                oracleCloseRequests[i].time
            );
            requestsDTO[i] = request;
        }
        return requestsDTO;
    }

    /**
     * Checks if there are Oracle Close requests for a specified event.
     *
     * @dev This internal function iterates through the `oracleCloseRequests` array to determine if any requests match the given event ID.
     *      It is used to verify the existence of close requests for a specific event.
     *
     * @param eventIdBytes The unique identifier of the event in bytes8 format.
     *
     * @return A boolean value indicating whether any Oracle Close requests exist for the specified event.
     *
     * The function scans through the `oracleCloseRequests` array, comparing each request's event ID with the provided `eventIdBytes`.
     * If a match is found, it returns true, indicating the presence of close requests for that event.
     * If no matches are found throughout the array, it returns false, indicating no close requests exist for the event.
     */
    function _hasOracleCloseRequests(bytes8 eventIdBytes) internal view returns (bool) {
        // Iterate through the oracleCloseRequests array
        for (uint256 i = 0; i < oracleCloseRequests.length; i++) {
            // Check if the eventIdBytes matches the current request's eventIdBytes
            if (oracleCloseRequests[i].eventIdBytes == eventIdBytes) {
                return true; // If a match is found, return true
            }
        }
        return false; // If no match is found, return false
    }

    /**
     * @dev Adds an Oracle open request for a specific event and stake details.
     * @param _eventId The unique identifier of the event.
     * @param _amountCoinIn The amount of VUND staked from the player's wallet.
     * @param _coinAddress The address of the VUND coin.
     * @param _amountATON The amount of ATON staked from the player's wallet.
     * @param _team The team for which the stake is being made.
     */
    function _addOracleOpenRequest(
        string memory _eventId,
        uint256 _amountCoinIn,
        address _coinAddress,
        uint256 _amountATON,
        uint8 _team
    ) internal {
        bytes8 eventIdBytes = Tools._stringToBytes8(_eventId);
        address player = msg.sender;

        (uint256 amountVUND,) = VAULT.convertCoinToVUND(_coinAddress, _amountCoinIn);

        // Combined check for minimum stake and sufficient balance and allowance
        require(
            amountVUND >= minimumStake && ERC20(_coinAddress).balanceOf(player) >= _amountCoinIn
                && ERC20(_coinAddress).allowance(player, address(VAULT)) >= _amountCoinIn,
            "Check failed: Min Stake, Balance, or Allowance"
        );

        AStructs.OracleOpenRequest memory request = AStructs.OracleOpenRequest(
            eventIdBytes, player, _amountCoinIn, _coinAddress, _amountATON, _team, block.timestamp
        );

        uint256 index = oracleOpenRequests.length;
        for (uint256 i = 0; i < oracleOpenRequests.length; i++) {
            if (oracleOpenRequests[i].eventIdBytes == eventIdBytes) {
                index = i;
                break;
            }
        }

        if (index >= oracleOpenRequests.length) {
            oracleOpenRequests.push(request);
        } else {
            oracleOpenRequests[index] = request;
        }
    }

    /**
     * @dev Adds an Oracle close request for a specific event.
     * @param _eventId The unique identifier of the event.
     */
    function addOracleCloseRequest(string memory _eventId) external {
        // Ensure the Event has not started yet and is still active
        bytes8 eventIdBytes = Tools._stringToBytes8(_eventId);
        AStructs.EventDTO memory eventInfo = VAULT.getEventDTO(eventIdBytes);
        require(eventInfo.startDate < block.timestamp, "Event has not started yet");

        // Check if the event is active and not already closed
        require(eventInfo.active, "Event already Closed");
        address player = msg.sender;

        // Create a new OracleCloseRequest struct
        AStructs.OracleCloseRequest memory request = AStructs.OracleCloseRequest(eventIdBytes, player, block.timestamp);

        // Check if the request is not already added
        bool isAdded = false;
        for (uint256 i = 0; i < oracleCloseRequests.length; i++) {
            if (oracleCloseRequests[i].eventIdBytes == eventIdBytes) {
                isAdded = true;
                break;
            }
        }
        require(!isAdded, "Close Request already Added");

        // Add the OracleCloseRequest to the array
        oracleCloseRequests.push(request);
    }

    /**
     * Fulfills an Oracle open request by adding an event and processing the stake.
     *
     * @dev This function is called to fulfill an open request from the Oracle. It involves adding a new event
     *      with the specified details and processing the stake associated with the event. This function can only be
     *      called by an account with the ORACLE_ROLE.
     *
     * @param _eventId The unique identifier of the event in string format.
     * @param _startDate The start date of the event in UNIX timestamp format.
     * @param _sport The sport category of the event, represented as a uint8.
     *
     * The function first converts the event ID from string to bytes8 format. It then locates the corresponding
     * Oracle open request by iterating through the `oracleOpenRequests` array. Once the request is identified,
     * it validates the team selection and adds the event to the VAULT. A new stake is then created for the event,
     * and rewards are calculated and assigned to the player.
     *
     * After processing, the function removes the fulfilled Oracle request from the `oracleOpenRequests` array
     * to maintain accuracy and up-to-date state of Oracle requests.
     */
    function fullfillOpenRequest(string memory _eventId, uint64 _startDate, uint8 _sport)
        external
        onlyRole(AStructs.ORACLE_ROLE)
    {
        bytes8 eventIdBytes = Tools._stringToBytes8(_eventId);
        // Find the index of the Oracle open request for the specified event
        uint256 index = oracleOpenRequests.length;
        for (uint256 i = 0; i < oracleOpenRequests.length; i++) {
            if (oracleOpenRequests[i].eventIdBytes == eventIdBytes) {
                index = i;
                break;
            }
        }

        // Check if the Oracle open request exists
        require(index < oracleOpenRequests.length, "Request for this event doesnt exist");

        // Get the Oracle open request details
        AStructs.OracleOpenRequest memory request = oracleOpenRequests[index];

        // Ensure valid team selection.
        require(request.team == 1 || request.team == 2, "Invalid team");
        // Add the event

        VAULT.addEvent(request.eventIdBytes, _startDate, _sport, request.requester);
        AStructs.EventDTO memory eventInfo = VAULT.getEventDTO(eventIdBytes);

        _newStake(
            request.eventIdBytes,
            request.amountCoin,
            request.coinAddress,
            request.amountATON,
            request.team,
            request.requester,
            eventInfo,
            true
        );
        (uint256 vundAmount,) = VAULT.convertCoinToVUND(request.coinAddress, request.amountCoin);

        // Calculate and pay rewards
        // OpenEventReward
        uint256 bonusNFT = AStructs.pct_denom + _BonusNFT(request.requester, _sport);

        uint256 rewardsATON = _getVUNDtoATON(
            (vundAmount * AStructs.OPEN_EVENT_PCT * bonusNFT) / (AStructs.pct_denom * AStructs.pct_denom)
        );

        VAULT.addEarningsToPlayer(
            request.requester, 0, rewardsATON, eventIdBytes, uint8(AStructs.EarningCategory.OpenEventReward)
        );

        // Swap the Oracle open request to remove with the last request in the array and then pop (remove) the last element
        oracleOpenRequests[index] = oracleOpenRequests[oracleOpenRequests.length - 1];
        oracleOpenRequests.pop();
        _cleanOracleRequests();
    }

    /**
     * @dev Fulfills an Oracle close request by closing an event and processing rewards.
     * @param _eventId The unique identifier of the event.
     * @param _winner The winner of the event.
     * @param _scoreA The score of team A.
     * @param _scoreB The score of team B.
     */
    function fullfillCloseRequest(string memory _eventId, int8 _winner, uint8 _scoreA, uint8 _scoreB)
        external
        onlyRole(AStructs.ORACLE_ROLE)
    {
        bytes8 eventIdBytes = Tools._stringToBytes8(_eventId);

        // Find the index of the Oracle close request for the specified event
        uint256 index = oracleCloseRequests.length;
        for (uint256 i = 0; i < oracleCloseRequests.length; i++) {
            if (oracleCloseRequests[i].eventIdBytes == eventIdBytes) {
                index = i;
                break;
            }
        }

        // Check if the Oracle close request exists
        require(index < oracleCloseRequests.length, "Request for this event doesnt exist");

        // Get the Oracle close request details
        AStructs.OracleCloseRequest memory request = oracleCloseRequests[index];

        // Close the event and process rewards
        _closeEvent(_eventId, _winner, _scoreA, _scoreB, request.requester);

        // Calculate and pay rewards 10 VUND in ATON
        uint256 rewardsATON = _getVUNDtoATON(10 ** 19);
        VAULT.addEarningsToPlayer(
            request.requester, 0, rewardsATON, eventIdBytes, uint8(AStructs.EarningCategory.CloseEventReward)
        );

        // Swap the Oracle close request to remove with the last request in the array and then pop (remove) the last element
        oracleCloseRequests[index] = oracleCloseRequests[oracleCloseRequests.length - 1];
        oracleCloseRequests.pop();
        _cleanOracleRequests();
    }

    /**
     * @dev Clears the arrays containing open and close oracle requests.
     *
     * Oracle requests are typically used to retrieve data from external sources.
     * This function removes all pending requests, both open and close, by popping
     * each entry from the arrays until they are empty.
     *
     * @return bool Returns `true` once both arrays are cleared.
     */
    function _cleanOracleRequests() internal returns (bool) {
        uint256 tenMinutesAgo = block.timestamp - 10 minutes;

        // Clear old entries from oracleOpenRequests
        for (uint256 i = 0; i < oracleOpenRequests.length;) {
            if (oracleOpenRequests[i].time < tenMinutesAgo) {
                if (i != oracleOpenRequests.length - 1) {
                    oracleOpenRequests[i] = oracleOpenRequests[oracleOpenRequests.length - 1];
                }
                oracleOpenRequests.pop();
            } else {
                i++; // Only increment if no element was deleted
            }
        }

        // Clear old entries from oracleCloseRequests
        for (uint256 i = 0; i < oracleCloseRequests.length;) {
            if (oracleCloseRequests[i].time < tenMinutesAgo) {
                if (i != oracleCloseRequests.length - 1) {
                    oracleCloseRequests[i] = oracleCloseRequests[oracleCloseRequests.length - 1];
                }
                oracleCloseRequests.pop();
            } else {
                i++; // Only increment if no element was deleted
            }
        }

        return true;
    }

    /**
     * Allows a player to stake on an event.
     *
     * @dev This function enables a player to place a stake on a specified event. Depending on whether it's the first stake
     *      for the event or a subsequent one, the function either adds an Oracle open request or processes the new stake directly.
     *
     * @param _eventId The unique identifier of the event in string format.
     * @param _amountCoinIn The amount of coins to stake.
     * @param _coinAddress The address of the coin contract.
     * @param _amountATON The amount of ATON tokens to stake.
     * @param _team The team on which the stake is placed, represented as a uint8.
     *
     * The function begins by converting the event ID from string to bytes8 format and fetching the event details from the VAULT.
     * If it's the first stake for the event (indicated by zero total VUND in both teams), an Oracle open request is added.
     * Otherwise, the function processes the new stake directly by invoking `_newStake`. This allows for dynamic handling
     * of stakes based on the event's current status and maintains the integrity of event betting and Oracle request management.
     */
    function stake(
        string memory _eventId,
        uint256 _amountCoinIn,
        address _coinAddress,
        uint256 _amountATON,
        uint8 _team
    ) external {
        // Convert the event ID to bytes8 format and retrieve event information from the VAULT.
        bytes8 eventIdBytes = Tools._stringToBytes8(_eventId);
        AStructs.EventDTO memory eventInfo = VAULT.getEventDTO(eventIdBytes);

        // Determine if this is the first stake for the event and handle accordingly.
        if (eventInfo.totalVUND_A + eventInfo.totalVUND_B == 0) {
            _addOracleOpenRequest(_eventId, _amountCoinIn, _coinAddress, _amountATON, _team);
        } else {
            bool isOpenEvent = false;
            if ((_team == 1 && eventInfo.totalVUND_B == 0) || (_team == 2 && eventInfo.totalVUND_A == 0)) {
                isOpenEvent = true;
            }
            _newStake(eventIdBytes, _amountCoinIn, _coinAddress, _amountATON, _team, msg.sender, eventInfo, isOpenEvent);
        }
    }

    /**
     * Allows a player to stake on an event.
     *
     * @dev This function enables a player to place a stake on a specified event. Depending on whether it's the first stake
     *      for the event or a subsequent one, the function either adds an Oracle open request or processes the new stake directly.
     *
     * @param _eventId The unique identifier of the event in string format.
     * @param _amountCoinIn The amount of coins to stake.
     * @param _coinAddress The address of the coin contract.
     * @param _amountATON The amount of ATON tokens to stake.
     * @param _team The team on which the stake is placed, represented as a uint8.
     *
     * The function begins by converting the event ID from string to bytes8 format and fetching the event details from the VAULT.
     * If it's the first stake for the event (indicated by zero total VUND in both teams), an Oracle open request is added.
     * Otherwise, the function processes the new stake directly by invoking `_newStake`. This allows for dynamic handling
     * of stakes based on the event's current status and maintains the integrity of event betting and Oracle request management.
     */
    function stakeOracle(
        string memory _eventId,
        uint256 _amountCoinIn,
        address _coinAddress,
        uint256 _amountATON,
        uint8 _team,
        address _player
    ) external onlyRole(AStructs.ORACLE_ROLE) {
        // Convert the event ID to bytes8 format and retrieve event information from the VAULT.
        bytes8 eventIdBytes = Tools._stringToBytes8(_eventId);
        AStructs.EventDTO memory eventInfo = VAULT.getEventDTO(eventIdBytes);

        _newStakeOracle(eventIdBytes, _amountCoinIn, _coinAddress, _amountATON, _team, _player, eventInfo);
    }

    /**
     * Retrieves the stake details for a player in a specific event.
     *
     * @dev This function provides a way to fetch a player's stake details for a given event.
     *      It converts the event ID from a string to bytes8 format and then queries the VAULT contract
     *      to retrieve the stake information associated with the player for that particular event.
     *
     * @param _eventId The unique identifier of the event in string format. It is converted to bytes8
     *                 internally for processing.
     *
     * @return AStructs.StakeDTO A structure containing the stake details for the player in the specified event.
     *
     * The function is marked as external and view, indicating that it doesn't modify the state and can be
     * called externally. The `msg.sender` is used to identify the player calling this function, and their
     * stake information for the given event ID is retrieved and returned.
     */
    function getPlayerStake(string memory _eventId) external view returns (AStructs.StakeDTO memory) {
        // Convert the event ID from string to bytes8 format.
        bytes8 eventIdBytes = Tools._stringToBytes8(_eventId);

        // Retrieve and return the player's stake details from the VAULT for the given event.
        return VAULT.getPlayerStake(eventIdBytes, msg.sender);
    }

    /**
     * Retrieves the details of an event.
     *
     * @dev This function is used to fetch detailed information about a specific event based on its identifier.
     *      It first converts the event ID from string to bytes8 format. Then, it queries the VAULT contract to
     *      retrieve the event details. Additionally, the function calculates the current state of the event
     *      (e.g., whether it's open, closed, etc.) and includes this in the returned data.
     *
     * @param _eventId The unique identifier of the event in string format. It is converted internally to bytes8
     *                 format for processing.
     *
     * @return AStructs.EventDTO A structure containing detailed information about the specified event.
     *
     * The function is marked as external and view, indicating that it only reads data and can be called externally.
     * It utilizes the `Tools._stringToBytes8` utility function to convert the event ID and relies on the VAULT
     * contract to fetch the event details. The event state is then calculated and incorporated into the returned data.
     */
    function getEventDTO(string memory _eventId) external view returns (AStructs.EventDTO memory) {
        // Convert the event ID from string to bytes8 format.
        bytes8 eventIdBytes = Tools._stringToBytes8(_eventId);

        // Retrieve event details from the VAULT contract.
        AStructs.EventDTO memory eventDTO = VAULT.getEventDTO(eventIdBytes);

        // Calculate and update the event state.
        eventDTO.eventState = _calculateEventState(eventIdBytes, eventDTO);

        return eventDTO;
    }

    /**
     * Retrieves the details of an event and calculates its current state.
     *
     * @dev This function assesses the current state of an event by considering various factors like oracle requests,
     *      stakes placed, event active status, start date, and whether the player has claimed rewards. It returns a
     *      uint8 representing the state of the event.
     *
     * @param _eventIdBytes The unique identifier of the event in bytes8 format.
     * @param _eventDTO The data structure containing event details.
     *
     * @return eventState The calculated state of the event, represented as a uint8.
     *
     * The function goes through several checks to determine the event's current state:
     * 1. Checks for pending Oracle Open and Close requests.
     * 2. Determines whether the event has received any stakes.
     * 3. Assesses if the event is active and has started, or if it's live but not yet started.
     * 4. Evaluates if the player has pending rewards or has already claimed them.
     *
     * The event state is crucial for managing the lifecycle of an event and guiding players' interactions with it.
     */
    function _calculateEventState(bytes8 _eventIdBytes, AStructs.EventDTO memory _eventDTO)
        internal
        view
        returns (uint8 eventState)
    {
        uint256 overtime = 0 minutes;
        bool isOvertime = _eventDTO.overtime;
        if (isOvertime) {
            overtime = 5 minutes;
        }

        // Check if there are pending Oracle Open requests for the specified event
        if (_hasOracleOpenRequests(_eventIdBytes)) {
            return uint8(AStructs.EventState.OpenRequest); // Event state 1: Oracle Open Request Pending, Awaiting Oracle Transaction
        }
        // Check if there are pending Oracle Close requests for the specified event
        if (_hasOracleCloseRequests(_eventIdBytes)) {
            return uint8(AStructs.EventState.CloseRequest); // Event state 5: Oracle Close Request Pending, Awaiting Oracle Transaction
        }

        // Check if there are no stakes placed on the event
        if (_eventDTO.totalVUND_A + _eventDTO.totalVUND_B == 0) {
            return uint8(AStructs.EventState.NotInitialized); // Event state 0: No Stakes, Event hasn't received any stakes yet
        }

        // Check if the event is active and has started
        if (_eventDTO.active && block.timestamp + overtime < _eventDTO.startDate) {
            return uint8(AStructs.EventState.StakingOn); // Event state 2: Active and Started, Stake Period Ongoing
        }

        // Check if the event is active but has not started yet
        if (_eventDTO.active && block.timestamp + overtime >= _eventDTO.startDate) {
            return uint8(AStructs.EventState.Live); // Event state 3: Match Scheduled, Stake Period Not Yet Started
        }

        // Note: The Smart Contract cannot determine when the Sport Match finishes.
        // In the Web App, set eventState = 4 if (STAGE='FINISHED' or STAGE='CANCELLED') and eventState == 3.

        // Check if the player has not yet claimed rewards for the event
        if (!VAULT.isPlayerFinalizedEvent(_eventIdBytes, msg.sender)) {
            if (VAULT.getPlayerStake(_eventIdBytes, msg.sender).stakeVUND > 0) {
                return uint8(AStructs.EventState.RewardsPending); // Event state 6: Player Rewards Pending, Player can still claim rewards
            }
        }

        // Event state 7: Not Active and Player has already claimed rewards, Event cycle concluded
        return uint8(AStructs.EventState.Closed);
    }

    /**
     * Retrieves the list of player addresses participating in a specific event.
     *
     * @dev This function is designed to fetch the addresses of all players who are participating in a given event.
     *      It converts the event ID from string to bytes8 format and then queries the VAULT contract to obtain the list
     *      of player addresses associated with that event. This function can be used to get an overview of player participation
     *      in any specific event.
     *
     * @param _eventId The unique identifier of the event in string format. It is converted to bytes8 format
     *                 internally for querying the VAULT.
     *
     * @return An array of addresses representing the players participating in the specified event.
     *
     * The function is marked as external and view, indicating that it only reads data and can be called from outside the contract.
     * It utilizes the `Tools._stringToBytes8` utility function to convert the event ID and relies on the VAULT contract
     * to fetch the list of participating player addresses.
     */
    function EventPlayers(string memory _eventId) external view returns (address[] memory) {
        // Convert the event ID from string to bytes8 format.
        bytes8 eventIdBytes = Tools._stringToBytes8(_eventId);

        // Retrieve and return the list of player addresses for the given event.
        return VAULT.getEventPlayers(eventIdBytes);
    }

    /**
     * @dev Internal function to create a new stake for an event.
     * @param _eventIdBytes Unique identifier of the event in bytes8 format.
     * @param _amountCoinIn Amount of VUND staked.
     * @param _coinAddress Address of the coin being staked.
     * @param _amountATON Amount of ATON staked from the player's wallet.
     * @param _team Chosen team for the stake (0 = Team A, 1 = Team B).
     * @param _player Address of the player placing the stake.
     * @param _eventInfo .
     * @param _isOpenEvent .
     */
    function _newStake(
        bytes8 _eventIdBytes,
        uint256 _amountCoinIn,
        address _coinAddress,
        uint256 _amountATON,
        uint8 _team,
        address _player,
        AStructs.EventDTO memory _eventInfo,
        bool _isOpenEvent
    ) internal {
        // Validate the event's status and starting time.
        // require(_eventInfo.active, 'Event is not active');

        uint256 overtime = 0 minutes;
        if (_eventInfo.overtime) {
            overtime = 5 minutes;
        }
        require(_eventInfo.startDate > block.timestamp + overtime, "Event already started");

        // Convert the staked coin amount to VUND equivalent.
        (uint256 vundAmount, uint256 adjustedCoinAmountIn) = VAULT.convertCoinToVUND(_coinAddress, _amountCoinIn);

        // Ensure the value of ATON being staked doesn't exceed that of the VUND equivalent.
        uint256 amountATONMax = _getVUNDtoATON(vundAmount);

        if (_amountATON > amountATONMax) {
            _amountATON = amountATONMax;
        }

        // Transfer the equivalent VUND value from the player to this contract.

        VAULT.retrieveCoin(_player, adjustedCoinAmountIn, _coinAddress, 0);

        // If any ATON is staked, burn a portion of it.
        if (_amountATON > 0) {
            VAULT.retrieveCoin(_player, _amountATON, address(ATON), _amountATON);
        }

        // If VUND is being staked, provide a bonus based on NFT holdings and potential leverage.
        if (_coinAddress == address(VAULT)) {
            // Ensure this is comparing to VUND's address.
            uint256 bonusAmount =
                _getVUNDtoATON((vundAmount * _BonusNFT(_player, NFTcategories.VUNDrocket)) / AStructs.pct_denom);
            _amountATON += bonusAmount;
        }

        // Ensure the player's stake doesn't surpass the event's maximum stake limit.
        _checkMaxStakeVUND(_eventIdBytes, _player, vundAmount, _eventInfo.maxStakeVUND, _eventInfo.sport);

        // Register the stake in the VAULT contract
        VAULT.addStake(_eventIdBytes, _coinAddress, _amountCoinIn, _amountATON, _team, _player, _isOpenEvent);
    }

    /**
     * @dev Internal function to create a new stake for an event.
     * @param _eventIdBytes Unique identifier of the event in bytes8 format.
     * @param _amountCoinIn Amount of VUND staked.
     * @param _coinAddress Address of the coin being staked.
     * @param _amountATON Amount of ATON staked from the player's wallet.
     * @param _team Chosen team for the stake (0 = Team A, 1 = Team B).
     * @param _player Address of the player placing the stake.
     * @param _eventInfo .
     */
    function _newStakeOracle(
        bytes8 _eventIdBytes,
        uint256 _amountCoinIn,
        address _coinAddress,
        uint256 _amountATON,
        uint8 _team,
        address _player,
        AStructs.EventDTO memory _eventInfo
    ) internal {
        // Validate the event's status and starting time.
        // require(_eventInfo.active, 'Event is not active');

        uint256 overtime = 0 minutes;
        if (_eventInfo.overtime) {
            overtime = 5 minutes;
        }
        require(_eventInfo.startDate > block.timestamp + overtime, "Event already started");

        // Convert the staked coin amount to VUND equivalent.
        (, uint256 adjustedCoinAmountIn) = VAULT.convertCoinToVUND(_coinAddress, _amountCoinIn);

        // Transfer the equivalent VUND value from the player to this contract.
        VAULT.retrieveCoin(msg.sender, adjustedCoinAmountIn, _coinAddress, 0);

        // Register the stake in the VAULT contract
        VAULT.addStake(_eventIdBytes, _coinAddress, _amountCoinIn, _amountATON, _team, _player, false);
    }

    /**
     * @dev Internal function to check and handle the maximum VUND stake limit.
     * @param _eventIdBytes The unique identifier of the event in bytes8 format.
     * @param _player The address of the player creating the stake.
     * @param _amountVUND The total amount of VUND being staked.
     * @param _maxStakeVUND The maximum VUND stake allowed for the event.
     */
    function _checkMaxStakeVUND(
        bytes8 _eventIdBytes,
        address _player,
        uint256 _amountVUND,
        uint256 _maxStakeVUND,
        uint8 _sportId
    ) internal {
        if (_amountVUND > _maxStakeVUND * _maxStakeVUND) {
            uint256 rewardsATON = _getVUNDtoATON(
                (_amountVUND) * AStructs.MAX_SQUARE_STAKE_PCT * _BonusNFT(_player, _sportId)
            ) / (AStructs.pct_denom * AStructs.pct_denom); // 5%*(bonus) ATON

            VAULT.addEarningsToPlayer(
                _player, 0, rewardsATON, _eventIdBytes, uint8(AStructs.EarningCategory.MaxVUNDStake)
            ); // 7 Max VUND stake
        } else if (_amountVUND > _maxStakeVUND) {
            uint256 rewardsATON = _getVUNDtoATON((_amountVUND) * AStructs.MAX_STAKE_PCT * _BonusNFT(_player, _sportId))
                / (AStructs.pct_denom * AStructs.pct_denom); // 2%*(bonus) ATON

            VAULT.addEarningsToPlayer(
                _player, 0, rewardsATON, _eventIdBytes, uint8(AStructs.EarningCategory.MaxVUNDStake)
            ); // 7 Max VUND stake
        }
    }

    /**
     * @dev Calculates the bonus multiplier based on NFT rarity and Atovix count.
     * @param _player Address of the player whose bonus is being determined.
     * @param _category Category identifier for the staking mechanics.
     * @return mult The calculated bonus multiplier.
     */
    function _BonusNFT(address _player, uint8 _category) internal view returns (uint256 mult) {
        // If PVT contract is not set, return 0 as there is no multiplier.
        if (PVT == address(0)) return 0;

        // Retrieve the NFT rarity (quality) for the player in the specified category.
        uint8 quality = IPVT(PVT).getBonus(_player, _category);
        // Retrieve the Atovix count for the player.
        uint256 atovixCount = IPVT(PVT).getStakedAtovixCount(_player);

        // Calculate Atovix bonus based on count with different logic after 10.
        uint256 atovixBonus = _calculateAtovixBonus(atovixCount);

        // Check for the special category 'VUNDrocket' which has its own calculation.
        if (_category == uint8(NFTcategories.VUNDrocket)) {
            // Multiplier for 'VUNDrocket' is based on a fixed value multiplied by quality.
            mult = 20000 * quality;
            if (atovixCount > 0) {
                // Apply Atovix bonus if any Atovix tokens are present.
                mult = (mult * atovixBonus);
            }
            return mult;
        }

        // Return 0 if neither quality nor Atovix count is present.
        if (quality == 0 && atovixCount == 0) return 0;

        // Define a base multiplier which is a factor of NFT quality.
        uint256 baseMultiplier = quality == 0 ? 100000 : 2 ** quality * 100000; //2^quality * 1%

        // Adjust the base multiplier by the Atovix bonus.
        mult = (baseMultiplier * atovixBonus) / AStructs.pct_denom;

        return mult;
    }

    /**
     * @dev Calculates the Atovix bonus multiplier based on the Atovix count.
     * This function applies different logic for counts up to 10 and beyond.
     * For counts up to 10, it uses quadratic scaling. For counts above 10, it uses linear scaling.
     * @param atovixCount The count of Atovix tokens for the player.
     * @return The calculated Atovix bonus as a multiplier.
     */
    function _calculateAtovixBonus(uint256 atovixCount) internal pure returns (uint256) {
        if (atovixCount == 0) return AStructs.pct_denom;
        if (atovixCount <= 10) {
            return AStructs.pct_denom + atovixCount * (atovixCount - 1) * 100000;
        } else {
            return AStructs.pct_denom + 10 * 9 * 100000 + (atovixCount - 10) * 100000;
        }
    }

    function BonusNFT(address _player, uint8 _category) external view returns (uint256 mult) {
        return _BonusNFT(_player, _category);
    }

    /**
     * @dev Closes an event by updating its final result and distributing the earnings to all participating players.
     * @param _eventId The unique ID of the event.
     * @param _winner The winner of the event (-1 for Tie, 0 for Team A, 1 for Team B).
     * @param _scoreA The final score of Team A.
     * @param _scoreB The final score of Team B.
     * @param _player The address of the player who triggered the event closure.
     */
    function _closeEvent(string memory _eventId, int8 _winner, uint8 _scoreA, uint8 _scoreB, address _player)
        internal
    {
        bytes8 eventIdBytes = Tools._stringToBytes8(_eventId);

        VAULT.closeEvent(eventIdBytes, _winner, _scoreA, _scoreB, _player);
    }

    /**
     * @dev Finalizes the player's participation in all active events.
     * This function checks active events for the player, calculates the vault fee and updates the player's earnings.
     */
    function finalizePlayerEvent(string memory eventId) external {
        // Fetch details of these active events.
        bytes8 _eventIdBytes = Tools._stringToBytes8(eventId);

        AStructs.EventDTO memory eventDTO = VAULT.getEventDTO(_eventIdBytes);
        // Initialize the total vault fee to zero.
        uint256 vaultFee = 0;

        // Check if the event is not active, has a winner, and the player hasn't finalized their stake for this event.
        if (!eventDTO.active && eventDTO.winner != -1 && !VAULT.isPlayerFinalizedEvent(_eventIdBytes, msg.sender)) {
            // If all conditions are met, finalize this event for the player and accumulate the vault fee.
            vaultFee += _finalizePlayerEvent(_eventIdBytes, eventDTO, msg.sender);
        }

        // If there's a vault fee accumulated, add earnings for the VAULT.
        if (vaultFee > 0) {
            VAULT.addEarningsToPlayer(
                address(VAULT), vaultFee, 0, _eventIdBytes, uint8(AStructs.EarningCategory.VaultFee)
            );
        }
    }

    /**
     * @dev Finalizes a specific event for a player.
     * It calculates the player's earnings for a specific event, updates the player's finalized status and adds earnings to the player.
     *
     * @param _eventIdBytes The unique ID of the event.
     * @param _eventDTO The data structure containing the event's details.
     * @param _player The address of the player.
     *
     * @return vaultFee The fee that goes to the vault.
     */
    function _finalizePlayerEvent(
        bytes8 _eventIdBytes,
        AStructs.EventDTO memory _eventDTO,
        address _player // 22
    ) internal returns (uint256 vaultFee) {
        AStructs.OutEarningsDTO memory outObj = _calculateEarnings(
            _eventIdBytes,
            _eventDTO.winner, // 0 for Team A winning, 1 for Team B winning, -2 for a tie, -3 for cancelled
            _player,
            AStructs.StakeDTO(0, 0, 0, 0)
        );

        // Check if a vault fee is applicable.
        if (outObj.isVaultFee) {
            // Calculate and pay referral bonuses for the player's referrals.

            // Calculate the vault fee from earnings.
            vaultFee = (premium * outObj.earningsVUND) / AStructs.pct_denom;
            // Deduct vault fee from the player's earnings.
            outObj.earningsVUND -= vaultFee;
            // Deduct referral bonuses from the vault fee.
        }

        // Mark this event as finalized for the player.
        VAULT.setPlayerFinalizedEvent(_eventIdBytes, _player);
        // Add the player's earnings for this event.
        VAULT.addEarningsToPlayer(
            _player, outObj.earningsVUND, outObj.earningsATON, _eventIdBytes, outObj.earningCategory
        );
    }

    /**
     * Retrieves a list of active event IDs in which the player is currently participating.
     *
     * @dev This function fetches the active event IDs associated with the player from the VAULT.
     *      It then converts these event IDs from bytes8 format to string format for easier readability.
     *
     * @return An array of string-formatted active event IDs in which the player is participating.
     *
     * The function queries the VAULT for the list of active events linked to the player's address.
     * Each event ID in bytes8 format is then converted to a string. This conversion facilitates easier
     * handling and display of event IDs in the user interface or other external applications.
     */
    function getPlayerActiveEvents() external view returns (AStructs.EventDTO[] memory) {
        // Retrieve active event IDs from VAULT
        AStructs.EventDTO[] memory activeEvents = VAULT.getPlayerActiveEvents(msg.sender);

        // Convert bytes8 event IDs to string format
        for (uint256 i = 0; i < activeEvents.length; i++) {
            activeEvents[i].eventState =
                _calculateEventState(Tools._stringToBytes8(activeEvents[i].eventId), activeEvents[i]);
        }

        return activeEvents;
    }

    /**
     * Retrieves a list of closed event IDs that the player has participated in.
     *
     * @dev This function fetches the closed event IDs associated with the player from the VAULT.
     *      Similar to active events, these IDs are converted from bytes8 to string format.
     *
     * @return An array of string-formatted closed event IDs in which the player has participated.
     *
     * The function queries the VAULT for the list of closed events linked to the player's address.
     * Each event ID in bytes8 format is then converted to a string. This allows for a more user-friendly
     * representation of event IDs, especially when displaying historical data or for record-keeping purposes.
     */
    function getPlayerClosedEvents() external view returns (AStructs.EventDTO[] memory) {
        // Retrieve active event IDs from VAULT
        AStructs.EventDTO[] memory closedEvents = VAULT.getPlayerClosedEvents(msg.sender);

        // Convert bytes8 event IDs to string format
        for (uint256 i = 0; i < closedEvents.length; i++) {
            closedEvents[i].eventState =
                _calculateEventState(Tools._stringToBytes8(closedEvents[i].eventId), closedEvents[i]);
        }

        return closedEvents;
    }

    /**
     * Calculates a player's earnings for a specific event.
     *
     * @dev This function computes earnings based on event outcome, team selection, and stake details.
     *
     * @param _eventId The unique ID of the event in a string format (e.g., '80hXDSf6').
     * @param _winner The result of the event (-2 for a tie, 0 for Team A winning, 1 for Team B winning, -3 for cancelled).
     * @param _player The Ethereum address of the player.
     * @param _quoteStakeDTO The stake details of the player as a StakeDTO structure.
     *
     * @return earningsVUND The player's earnings in VUND tokens.
     * @return earningsATON The player's earnings in ATON tokens.
     * @return vaultFee The vault fee deducted from the earnings.
     * @return earningCategory Numeric code indicating the earning category (e.g., Win, Loss, Tie).
     * @return bonusATON Additional ATON tokens earned as a bonus.
     */
    function calculateEarnings(
        string memory _eventId, // 80hXDSf6
        int8 _winner, // 0 for Team A winning, 1 for Team B winning, -2 for a tie, -3 for cancelled   : 1
        address _player, //signer[0]
        AStructs.StakeDTO memory _quoteStakeDTO
    ) external view returns (uint256, uint256, uint256, uint256, uint256) {
        // ) external view returns (uint256 earningsVUND, uint256 earningsATON, uint256 vaultFee, uint256 earningCategory, uint256 bonusATON) {
        bytes8 eventIdBytes = Tools._stringToBytes8(_eventId);
        AStructs.OutEarningsDTO memory outObj = _calculateEarnings(eventIdBytes, _winner, _player, _quoteStakeDTO);
        uint256 vaultFee;
        // In case of cancellation or singular stake there is no Fee charged to the player
        if (outObj.isVaultFee) {
            vaultFee = (premium * outObj.earningsVUND) / AStructs.pct_denom;
            outObj.earningsVUND = outObj.earningsVUND - vaultFee;
        }

        return (outObj.earningsVUND, outObj.earningsATON, vaultFee, outObj.earningCategory, outObj.bonusATON);
    }

    /**
     * Calculates the share percentage and bonus NFT for a player's stake in an event.
     *
     * @dev This internal function computes the player's share of the total stake and any applicable NFT bonus.
     *
     * @param effectivePlayerVUND The effective VUND amount staked by the player.
     * @param _eventIdBytes The unique ID of the event in a bytes8 format.
     * @param stakeVUND The VUND amount staked by the player.
     * @param team The team selected by the player (expressed as a uint8).
     *
     * @return playerSharePercentage The percentage of the total stake that belongs to the player.
     * @return bonusNFT The NFT bonus amount applicable to the player.
     */
    function _calculatePlayerShare(uint256 effectivePlayerVUND, bytes8 _eventIdBytes, uint256 stakeVUND, uint8 team)
        internal
        view
        returns (uint256 playerSharePercentage, uint256 bonusNFT)
    {
        bonusNFT = AStructs.pct_denom + _BonusNFT(msg.sender, VAULT.getSport(_eventIdBytes));
        playerSharePercentage = (effectivePlayerVUND * AStructs.pct_denom)
            / (VAULT.getEventStakedVUND(_eventIdBytes, AStructs.getContex(team, AStructs.Effective)) + stakeVUND);
        return (playerSharePercentage, bonusNFT);
    }

    /**
     * Internal function to calculate earnings based on event data and player's stake.
     *
     * @dev This function wraps multiple steps in the earnings calculation process, including updating player stakes,
     *      determining the player's team, calculating share and bonus, and finalizing the earnings amounts.
     *
     * @param _eventIdBytes The unique ID of the event in a bytes8 format.
     * @param _winner The result of the event (-2 for a tie, 0 for Team A winning, 1 for Team B winning, -3 for cancelled).
     * @param _player The Ethereum address of the player.
     * @param _quoteStakeDTO The stake details of the player as a StakeDTO structure.
     *
     * @return A structure (OutEarningsDTO) containing detailed information about the player's earnings.
     */
    function _calculateEarnings(
        bytes8 _eventIdBytes,
        int8 _winner,
        address _player,
        AStructs.StakeDTO memory _quoteStakeDTO
    ) internal view returns (AStructs.OutEarningsDTO memory) {
        AStructs.StakeDTO memory stakeDTO = _updatePlayerStake(_eventIdBytes, _player, _quoteStakeDTO);

        if (stakeDTO.stakeVUND == 0) {
            return AStructs.OutEarningsDTO({
                earningsVUND: 0, // Initialize with appropriate value
                earningsATON: 0, // Initialize with appropriate value
                earningCategory: 0, // Initialize with appropriate value
                isVaultFee: false, // Initialize with appropriate value
                bonusATON: _calculateAtonBonus(_eventIdBytes, _quoteStakeDTO) // Initialize with appropriate value
            });
        }

        uint8 team = _selectTeam(stakeDTO, _quoteStakeDTO);

        (uint256 playerSharePercentage, uint256 bonusNFT) =
            _calculatePlayerShare(stakeDTO.effectivePlayerVUND, _eventIdBytes, stakeDTO.stakeVUND, team);

        return _determineEarnings(
            _updatePlayerCount(_eventIdBytes, stakeDTO.effectivePlayerVUND),
            _winner,
            stakeDTO,
            playerSharePercentage,
            bonusNFT,
            _quoteStakeDTO,
            _eventIdBytes
        );
    }

    function _selectTeam(AStructs.StakeDTO memory _stakeDTO, AStructs.StakeDTO memory _quoteStakeDTO)
        internal
        pure
        returns (uint8 team)
    {
        if (_stakeDTO.effectivePlayerVUND > 0) {
            team = _stakeDTO.team;
        } else {
            team = _quoteStakeDTO.team;
        }
        return team;
    }

    /**
     * Updates a player's stake for a specific event.
     *
     * @dev This internal function is used to update the player's stake based on new stake details provided.
     *      It handles the logic of updating both VUND and ATON stakes, and also calculates the effective VUND stake.
     *
     * @param _eventIdBytes The unique ID of the event in a bytes8 format.
     * @param _player The Ethereum address of the player.
     * @param _quoteStakeDTO The new stake details to be added for the player, as a StakeDTO structure.
     *
     * @return stakeDTO The updated stake details for the player as a StakeDTO structure.
     */
    function _updatePlayerStake(bytes8 _eventIdBytes, address _player, AStructs.StakeDTO memory _quoteStakeDTO)
        internal
        view
        returns (AStructs.StakeDTO memory stakeDTO)
    {
        // Retrieve the player's existing stake for the event.
        stakeDTO = VAULT.getPlayerStake(_eventIdBytes, _player);

        // Update the team selection for the player if no VUND stake exists.
        if (stakeDTO.stakeVUND == 0) {
            stakeDTO.team = _quoteStakeDTO.team;
        }

        // Add the new VUND and ATON stakes to the player's existing stakes.
        stakeDTO.stakeVUND += _quoteStakeDTO.stakeVUND;
        stakeDTO.stakeATON += _quoteStakeDTO.stakeATON;

        // Calculate additional ATON stake based on the bonus NFT.
        // The `effectivePlayerVUND` field, in this context, is repurposed to indicate whether the player's stake is in VUND or COIN.
        // If `effectivePlayerVUND` is greater than 0, it implies the stake is in VUND, and thus eligible for an ATON bonus.
        // The bonus ATON stake is proportional to the VUND stake and is determined by the player's NFT category.
        // This bonus is then converted from VUND to ATON using the `_getVUNDtoATON` function.
        if (_quoteStakeDTO.effectivePlayerVUND > 0) {
            stakeDTO.stakeATON += _getVUNDtoATON(
                (_quoteStakeDTO.stakeVUND * _BonusNFT(_player, NFTcategories.VUNDrocket)) / AStructs.pct_denom
            );
        }

        // Update the effective VUND stake if there are any existing or new stakes.
        // This is the total VUND stake plus the ATON stake converted to its VUND equivalent.
        if ((stakeDTO.stakeVUND > 0 || stakeDTO.stakeATON > 0) || _quoteStakeDTO.stakeVUND > 0) {
            stakeDTO.effectivePlayerVUND =
                stakeDTO.stakeVUND + (stakeDTO.stakeATON * ATON.calculateFactorAton()) / AStructs.pct_denom;
        }

        return stakeDTO;
    }

    /**
     * Updates and returns the player count for a given event.
     *
     * @dev This internal function manages the count of players participating in an event.
     *      It uses the current player count and the effective VUND stake to determine if the player count should be incremented.
     *
     * @param _eventIdBytes The unique ID of the event in bytes8 format. Used to identify the event for which the player count is being updated.
     * @param _effectivePlayerVUND Indicates whether the player has a previous stake in the event. A zero value implies the player is new to the event.
     *
     * @return playerCount The updated count of players for the event.
     *
     * The function first retrieves the current number of players registered for the event.
     * It then checks two conditions:
     * 1. If the player count is one and `_effectivePlayerVUND` is zero, or if the player count is zero, it implies that the player is new to the event.
     *    In this scenario, the player count is incremented to include the new player.
     * 2. If `_effectivePlayerVUND` is greater than zero, it indicates that the player has already been counted in the player count.
     *    In this case, the player count remains unchanged as the player is not new to the event.
     */
    function _updatePlayerCount(bytes8 _eventIdBytes, uint256 _effectivePlayerVUND)
        internal
        view
        returns (uint256 playerCount)
    {
        // Retrieve the current number of players registered for the event.
        playerCount = VAULT.getEventPlayerCount(_eventIdBytes);

        // Increment the player count if the current player is new to the event.
        // This is determined by checking if `_effectivePlayerVUND` is zero.
        if (((playerCount == 1 && _effectivePlayerVUND == 0) || playerCount == 0)) {
            playerCount += 1;
        }

        return playerCount;
    }

    /**
     * Determines and calculates the earnings based on the event outcome and the player's stake.
     *
     * @dev This function computes the player's earnings in various scenarios (singular stake, event cancellation, tie, win, or loss).
     *      It takes into account the player's stake details, share percentage, bonus NFT, and the event outcome to calculate earnings.
     *
     * @param playerCount The total number of players participating in the event.
     * @param _winner The result of the event (0 for Team A win, 1 for Team B win, -2 for a tie, -3 for cancellation).
     * @param stakeDTO The stake details of the player for the event.
     * @param playerSharePercentage The player's share percentage in the total stakes.
     * @param bonusNFT The bonus NFT amount applicable to the player.
     * @param _quoteStakeDTO The quoted stake details for the event.
     * @param _eventIdBytes The unique ID of the event in a bytes8 format.
     *
     * @return outObj A structure containing the detailed earnings information.
     *
     * The function initializes the earnings output object with default values.
     * It then processes the earnings based on the event outcome and player's stake:
     * - Singular Stake: If there's only one player, the player retains their original stake with potential additional earnings based on ATON and bonus NFT.
     * - Cancelled Event: In case of event cancellation, players receive their original stake back without any additional earnings or vault fees.
     * - Tie: Earnings in case of a tie are calculated based on the player's stake share and bonus NFT.
     * - Win: If the player's selected team wins, the earnings are calculated based on win logic, including the player's stake share and bonus NFT.
     * - Loss: In case of a loss, the earnings are calculated based on loss logic, which typically results in reduced earnings.
     * Finally, the function calculates any additional bonus ATON earnings and returns the complete earnings information.
     */
    function _determineEarnings(
        uint256 playerCount,
        int8 _winner,
        AStructs.StakeDTO memory stakeDTO,
        uint256 playerSharePercentage,
        uint256 bonusNFT,
        AStructs.StakeDTO memory _quoteStakeDTO,
        bytes8 _eventIdBytes
    ) internal view returns (AStructs.OutEarningsDTO memory) {
        // Initialize the earnings output object with default values.
        AStructs.OutEarningsDTO memory outObj = AStructs.OutEarningsDTO({
            earningsVUND: 0,
            earningsATON: 0,
            earningCategory: 0,
            isVaultFee: true,
            bonusATON: 0
        });
        //make sure there is only one player in the event
        if (playerCount == 1) {
            // Singular stake logic
            outObj.earningsVUND = stakeDTO.stakeVUND;
            outObj.earningsATON = stakeDTO.stakeATON
                + (
                    (_getVUNDtoATON(stakeDTO.stakeVUND) * AStructs.SINGULAR_STAKE_PCT * bonusNFT)
                        / (AStructs.pct_denom * AStructs.pct_denom)
                );
            outObj.earningCategory = uint8(AStructs.EarningCategory.SingularStake);
            outObj.isVaultFee = false;
        } else if (_winner == -3) {
            // Cancelled event logic
            outObj.earningsVUND = stakeDTO.stakeVUND;
            outObj.earningsATON = stakeDTO.stakeATON;
            outObj.earningCategory = uint8(AStructs.EarningCategory.CancelledEvent);
            outObj.isVaultFee = false;
        } else if (_winner == -2) {
            // Tie stake logic
            (outObj.earningsVUND, outObj.earningsATON) = _calculateEarningsForTie(
                playerSharePercentage, _eventIdBytes, bonusNFT, stakeDTO.stakeVUND, _quoteStakeDTO
            );
            outObj.earningCategory = uint8(AStructs.EarningCategory.TieStake);
        } else if (stakeDTO.team == uint256(int256(_winner))) {
            // Won stake logic
            (outObj.earningsVUND, outObj.earningsATON, outObj.isVaultFee) = _calculateEarningsForWin(
                playerSharePercentage, _eventIdBytes, bonusNFT, stakeDTO.stakeVUND, _quoteStakeDTO
            );

            outObj.earningCategory = uint8(AStructs.EarningCategory.WonStake);
        } else {
            // Loss stake logic
            (outObj.earningsVUND, outObj.earningsATON) = _calculateEarningsForLoss(stakeDTO.stakeVUND, bonusNFT);
            outObj.earningCategory = uint8(AStructs.EarningCategory.LossStake);
        }

        outObj.bonusATON = _calculateAtonBonus(_eventIdBytes, _quoteStakeDTO);

        return outObj;
    }

    /**
     * Calculates the earnings for a tie event.
     *
     * @dev This function calculates the player's earnings when the event ends in a tie.
     *      It considers the player's share percentage, bonus NFT, and the total VUND staked in the event.
     *
     * @param playerSharePercentage The player's share percentage in the total stakes.
     * @param _eventIdBytes The unique ID of the event in bytes8 format.
     * @param bonusNFT The bonus NFT amount applicable to the player.
     * @param stakeVUND The VUND amount staked by the player.
     * @param _quoteStakeDTO The quoted stake details for the event.
     *
     * @return earningsVUND The calculated earnings in VUND for a tie event.
     * @return earningsATON The calculated earnings in ATON for a tie event.
     */
    function _calculateEarningsForTie(
        uint256 playerSharePercentage,
        bytes8 _eventIdBytes,
        uint256 bonusNFT,
        uint256 stakeVUND,
        AStructs.StakeDTO memory _quoteStakeDTO
    ) internal view returns (uint256 earningsVUND, uint256 earningsATON) {
        earningsVUND = (
            playerSharePercentage
                * (VAULT.getEventStakedVUND(_eventIdBytes, AStructs.WholeRawVUND) + _quoteStakeDTO.stakeVUND)
        ) / AStructs.pct_denom;
        earningsATON = ((_getVUNDtoATON(stakeVUND) * AStructs.DRAW_EVENT_PCT * bonusNFT))
            / (AStructs.pct_denom * AStructs.pct_denom);

        return (earningsVUND, earningsATON);
    }

    /**
     * Calculates the earnings for a winning event.
     *
     * @dev This function computes the player's earnings when their selected team wins the event.
     *      It uses player's share percentage, bonus NFT, and the total VUND staked to determine earnings.
     *      It also determines if a vault fee is applicable.
     *
     * @param playerSharePercentage The player's share percentage in the total stakes.
     * @param _eventIdBytes The unique ID of the event in bytes8 format.
     * @param bonusNFT The bonus NFT amount applicable to the player.
     * @param stakeVUND The VUND amount staked by the player.
     * @param _quoteStakeDTO The quoted stake details for the event.
     *
     * @return earningsVUND The calculated earnings in VUND for a win.
     * @return earningsATON The calculated earnings in ATON for a win.
     * @return isVaultFee A boolean indicating if a vault fee is applicable.
     */
    function _calculateEarningsForWin(
        uint256 playerSharePercentage,
        bytes8 _eventIdBytes,
        uint256 bonusNFT,
        uint256 stakeVUND,
        AStructs.StakeDTO memory _quoteStakeDTO
    ) internal view returns (uint256 earningsVUND, uint256 earningsATON, bool isVaultFee) {
        earningsVUND = (
            playerSharePercentage
                * (VAULT.getEventStakedVUND(_eventIdBytes, AStructs.WholeRawVUND) + _quoteStakeDTO.stakeVUND)
        ) / AStructs.pct_denom;
        earningsATON = ((_getVUNDtoATON(stakeVUND) * AStructs.WON_EVENT_PCT * bonusNFT))
            / (AStructs.pct_denom * AStructs.pct_denom);

        isVaultFee = true;
        if (stakeVUND > earningsVUND - (premium * earningsVUND) / AStructs.pct_denom) {
            isVaultFee = false;
        }

        return (earningsVUND, earningsATON, isVaultFee);
    }

    /**
     * Calculates the earnings for a losing event.
     *
     * @dev This function calculates the player's earnings when their selected team loses the event.
     *      It primarily focuses on the ATON earnings based on the bonus NFT, as VUND earnings are typically zero in a loss.
     *
     * @param bonusNFT The bonus NFT amount applicable to the player.
     * @param stakeVUND The VUND amount staked by the player.
     *
     * @return earningsVUND The calculated earnings in VUND for a loss, usually zero.
     * @return earningsATON The calculated earnings in ATON for a loss.
     */
    function _calculateEarningsForLoss(uint256 bonusNFT, uint256 stakeVUND)
        internal
        view
        returns (uint256 earningsVUND, uint256 earningsATON)
    {
        earningsVUND = 0;
        earningsATON = ((_getVUNDtoATON(stakeVUND) * AStructs.LOST_EVENT_PCT * bonusNFT))
            / (AStructs.pct_denom * AStructs.pct_denom);

        return (earningsVUND, earningsATON);
    }

    /**
     * Calculates the VUND equivalent of a specified ATON amount.
     *
     * @dev This function is used to convert a given amount of ATON to its equivalent value in VUND.
     *      It uses the current conversion factor obtained from the ATON contract to perform this calculation.
     *
     * @param _amountATON The amount of ATON to be converted into VUND.
     *
     * @return The equivalent amount of VUND for the given ATON amount.
     *
     * The conversion process involves multiplying the ATON amount by the ATON conversion factor and then
     * normalizing it based on the predefined percentage denominator to maintain proportionality and accuracy.
     */
    function _getATONtoVUND(uint256 _amountATON) internal view returns (uint256) {
        // Retrieve the current conversion factor for ATON to VUND.
        uint256 factorATON = IATON(ATON).calculateFactorAton();

        // Calculate and return the equivalent amount of VUND.
        uint256 amountVUND = (_amountATON * factorATON) / AStructs.pct_denom;

        return amountVUND;
    }

    /**
     * Converts a given VUND amount to its equivalent in ATON.
     *
     * @dev This function calculates the ATON equivalent for a specified amount of VUND.
     *      The conversion is based on the current rate obtained from the ATON contract.
     *
     * @param _amountVUND The amount of VUND to be converted into ATON.
     *
     * @return The equivalent amount of ATON for the provided VUND amount.
     *
     * The conversion process takes the VUND amount, multiplies it by a predefined percentage denominator, and
     * then divides by the ATON conversion factor to calculate the equivalent ATON amount.
     */
    function _getVUNDtoATON(uint256 _amountVUND) internal view returns (uint256) {
        // Retrieve the current conversion factor for VUND to ATON.
        uint256 factorATON = IATON(ATON).calculateFactorAton();

        // Calculate and return the equivalent amount of ATON.
        uint256 amountATON = (_amountVUND * AStructs.pct_denom) / factorATON;

        return amountATON;
    }

    /**
     * Retrieves and returns coin data for a given player.
     *
     * @dev This function fetches details about various coins, including ATON, from the Vault.
     *      It returns an array of Coin structures with updated details such as balance, allowance, symbol, and equivalent VUND balance.
     *
     * @param _player The address of the player for whom coin data is being fetched.
     *
     * @return An array of Coin structures containing detailed information about each coin.
     *
     * The function first retrieves a list of coins from the Vault, then creates a new array with an additional slot for ATON.
     * It initializes the first element of this array with ATON details and then copies the rest from the Vault's list.
     * Afterward, it updates each coin's details, including decimals, allowance, balance, symbol, and its equivalent balance in VUND.
     * The allowance and balance are fetched based on the player's address, and the balance is also converted to its VUND equivalent.
     */
    function getCoinsData(address _player) external view returns (AStructs.Coin[] memory) {
        // Fetch the list of coins from the Vault.
        AStructs.Coin[] memory coinsFromVault = VAULT.getCoinList();

        // Create a new array with an additional slot for ATON.
        AStructs.Coin[] memory coins = new AStructs.Coin[](coinsFromVault.length + 1);

        // Initialize the first element with ATON details.
        coins[0].token = address(ATON);
        coins[0].decimals = 0; // Initial placeholder value.
        coins[0].active = true;

        // Copy the rest of the coins from the Vault's list.
        for (uint256 i = 0; i < coinsFromVault.length; i++) {
            coins[i + 1] = coinsFromVault[i];
        }

        // Update details for each coin, including ATON.
        for (uint8 i = 0; i < coins.length; i++) {
            coins[i].decimals = ERC20(coins[i].token).decimals();
            if (_player != address(VAULT)) {
                coins[i].allowance = IERC20(coins[i].token).allowance(_player, address(VAULT));
            } else {
                coins[i].allowance = 0;
            }
            coins[i].balance = IERC20(coins[i].token).balanceOf(_player);
            coins[i].symbol = ERC20(coins[i].token).symbol();
            (uint256 balanceVUND,) = Tools.convertCoinToVUND(coins[i].balance, coins[i]);
            coins[i].balanceVUND = balanceVUND;
        }

        return coins;
    }

    /**
     * Calculates the ATON bonus for a player's stake in an event.
     *
     * @dev This function determines the ATON bonus amount based on the stake amount, event state, and player's NFT bonus.
     *      The bonus calculation varies depending on the state of the event (e.g., Not Initialized, Ended, Staking On).
     *
     * @param eventIdBytes The unique ID of the event in bytes8 format.
     * @param _quoteStakeDTO The staking details provided by the player.
     *
     * @return The calculated ATON bonus amount based on the player's stake and the event's state.
     *
     * The function first checks if the player has staked any VUND. If so, it retrieves the event details and calculates the event state.
     * Based on the event state, different bonus calculations are applied:
     * - Not Initialized: A bonus for the first stake and a maximum square stake bonus are calculated.
     * - Ended: A fixed bonus amount (10 VUND in ATON) is returned.
     * - Staking On: The bonus depends on whether the player's stake exceeds the maximum stake or the maximum square stake thresholds.
     * For each scenario, the respective bonus amount is converted from VUND to ATON and returned.
     * If the player hasn't staked any VUND, the function returns zero.
     */
    function _calculateAtonBonus(bytes8 eventIdBytes, AStructs.StakeDTO memory _quoteStakeDTO)
        internal
        view
        returns (uint256)
    {
        if (_quoteStakeDTO.stakeVUND > 0) {
            AStructs.EventDTO memory eventDTO = VAULT.getEventDTO(eventIdBytes);

            // Calculate Event State
            eventDTO.eventState = _calculateEventState(eventIdBytes, eventDTO);
            uint256 bonusNFT = AStructs.pct_denom + _BonusNFT(msg.sender, eventDTO.sport);

            if (eventDTO.eventState == uint8(AStructs.EventState.NotInitialized)) {
                uint256 firstStakeBonus = (_quoteStakeDTO.stakeVUND * AStructs.OPEN_EVENT_PCT * bonusNFT)
                    / (AStructs.pct_denom * AStructs.pct_denom);
                uint256 maxStakeBonus = (_quoteStakeDTO.stakeVUND * AStructs.MAX_SQUARE_STAKE_PCT * bonusNFT)
                    / (AStructs.pct_denom * AStructs.pct_denom);
                return _getVUNDtoATON(maxStakeBonus + firstStakeBonus);
            } else if (eventDTO.eventState == uint8(AStructs.EventState.Ended)) {
                return _getVUNDtoATON(10 ** 19); // 10 VUND in ATON
            } else if (eventDTO.eventState == uint8(AStructs.EventState.StakingOn)) {
                // Max Stake only
                if (_quoteStakeDTO.stakeVUND > eventDTO.maxStakeVUND * eventDTO.maxStakeVUND) {
                    uint256 maxStakeBonus = (_quoteStakeDTO.stakeVUND * AStructs.MAX_SQUARE_STAKE_PCT * bonusNFT)
                        / (AStructs.pct_denom * AStructs.pct_denom);
                    return _getVUNDtoATON(maxStakeBonus);
                }

                if (_quoteStakeDTO.stakeVUND > eventDTO.maxStakeVUND) {
                    uint256 maxStakeBonus = (_quoteStakeDTO.stakeVUND * AStructs.MAX_STAKE_PCT * bonusNFT)
                        / (AStructs.pct_denom * AStructs.pct_denom);
                    return _getVUNDtoATON(maxStakeBonus);
                }
                return 0;
            }

            return _getVUNDtoATON(0);
        } else {
            return _getVUNDtoATON(0);
        }
    }
}
// All rights reserved. This software and associated documentation files (the "Software"),
// cannot be used, copied, modified, merged, published, distributed, sublicensed, and/or
// sold without the express and written permission of the owner.
