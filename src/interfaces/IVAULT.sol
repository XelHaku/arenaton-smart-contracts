// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;
import '../libraries/AStructs.sol';

interface IVAULT {
    event StakeAdded(string EventId, address indexed player, uint256 amountVUND, uint256 amountATON, uint8 team);

    function allowance(address owner, address spender) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function balanceOf(address owner) external view returns (uint256);

    function addEvent(bytes8 _eventIdBytes, uint64 _startDate, uint8 _sport, address _player) external;

    function owner() external view returns (address);

    function getSport(bytes8 _eventIdBytes) external view returns (uint8);

    function addStake(
        bytes8 _eventIdBytes,
        address _coinAddress,
        uint256 _amountCoinIn,
        uint256 _amountATON,
        uint8 _team,
        address _player,
        bool _isOpenEvent
    ) external;

    function getEventDTO(bytes8 _eventIdBytes) external view returns (AStructs.EventDTO memory);

    function eventOpenWinCount(address _player, uint8 _sport) external view returns (uint256);

    function eventWinCount(address _player, uint8 _sport) external view returns (uint256);

    function EventPlayers(bytes8 _eventIdBytes) external view returns (address[] memory);

    function getPlayerActiveEvents(address _player) external view returns (AStructs.EventDTO[] memory);

    function getPlayerClosedEvents(address _player) external view returns (AStructs.EventDTO[] memory);

    function getPlayerLevel(address _player) external view returns (uint256);

    function closeEvent(bytes8 _eventIdBytes, int8 _result, uint8 _scoreA, uint8 _scoreB, address _player) external;

    function getEventTotalStake(bytes8 _eventIdBytes, bool fee) external view returns (uint256 eventTotalStake);

    function isPlayerFinalizedEvent(bytes8 _eventIdBytes, address _player) external view returns (bool);

    function setPlayerFinalizedEvent(bytes8 _eventIdBytes, address _player) external returns (bool);

    function getEventStakedVUND(bytes8 _eventIdBytes, uint8 _context) external view returns (uint256);

    function getEventPlayers(bytes8 _eventIdBytes) external view returns (address[] memory);

    function getActiveEvents(int8 _sport) external view returns (AStructs.EventDTO[] memory);

    function getPlayerStake(bytes8 _eventIdBytes, address _player) external view returns (AStructs.StakeDTO memory);

    function addEarningsToPlayer(address _player, uint256 _amountVUND, uint256 _amountATON, bytes8 _eventIdBytes, uint8 _category) external;

    function retrieveCoin(address _player, uint256 _amountCoin, address _token, uint256 _amountBurn) external;

    function burnATON(uint256 _burnAmount) external;

    function sendVUNDtoOwner() external;

    function substractVaultVUND(address _player, uint256 _amountVUND) external returns (bool);

    function getEventPlayerCount(bytes8 eventIdbytes) external view returns (uint256);

    function convertCoinToVUND(
        address _coinAddress,
        uint256 _amountCoinIn
    ) external view returns (uint256 vundAmount, uint256 adjustedCoinAmount);

    function convertVUNDToCoin(
        address _coinAddress,
        uint256 _vundAmount
    ) external view returns (uint256 vundAmount, uint256 adjustedCoinAmount);

    function getCoinList() external view returns (AStructs.Coin[] memory);

    function getCoin() external view returns (AStructs.Coin memory);

    function getEventDTOList(bytes8[] memory eventIds) external view returns (AStructs.EventDTO[] memory);

    function swap(
        address _player,
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _amountOut,
        uint256 _comissionPct
    ) external;

    function donateVUND(address _player, uint256 _amount) external;

    function playerCommission(address player) external view returns (uint256 unclaimedCommission);
}
