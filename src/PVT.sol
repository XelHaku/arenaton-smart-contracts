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

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol"; // ERC721 token with URI storage capabilities
import "@openzeppelin/contracts/access/Ownable.sol"; // Access control mechanism for ownership
import "lib/chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "lib/chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol"; // Interface for interacting with Chainlink VRF Coordinator
import "./interfaces/IATON.sol"; // Interface for the ATON contract
import "./interfaces/IVAULT.sol"; // Interface for the VAULT contract
import "./interfaces/ICANVAS.sol"; // Interface for the VAULT contract
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol"; // Security feature to prevent reentrancy attacks
import "./libraries/EventsLib.sol"; // Library for events
import "./libraries/NFTcategories.sol"; // Library for NFT categories
    // Hardhat console logging
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "lib/chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/utils/Counters.sol";
// PVT contract inherits from multiple contracts/interfaces to provide ERC721, VRF, ownership, and reentrancy guard functionalities

contract PVT is ERC721URIStorage, VRFConsumerBaseV2, Ownable, ReentrancyGuard, ERC2981 {
    // References to other contracts/interfaces
    IVAULT internal VAULT; // Reference to the VAULT contract
    IATON internal ATON; // Reference to the ATON contract

    // PVT Vars ######################################################################

    ICANVAS public CANVAS;

    // Chainlink VRF related variables for randomness
    VRFCoordinatorV2Interface private immutable vrfCoordinator; // Reference to the VRF Coordinator
    uint64 private immutable subscriptionId; // Subscription ID for Chainlink VRF service
    bytes32 private immutable gasLane; // Key hash for the gas lane to use for VRF requests
    uint32 private immutable callbackGasLimit; // Gas limit for the callback function from VRF
    uint16 private constant REQUEST_CONFIRMATIONS = 3; // Number of confirmations required for VRF request
    uint256 private tokenCounter; // Counter for the token IDs
    uint256 internal constant MAX_CATEGORY_Probability = 649; // Maximum Probability for category determination

    // Mapping for Chainlink VRF requestId to the requester's address
    mapping(uint256 => address) public requestIdToSender;

    // Mappings for NFT traits and ownership
    mapping(uint64 => string) private uriCode; // Mapping from a code to a URI for metadata
    mapping(uint256 => uint8) private category; // Mapping from token ID to its category
    mapping(uint256 => uint16) private quality; // Mapping from token ID to its quality
    mapping(address => uint256[]) private stakesArray; // Mapping from an address to an array of stakes
    mapping(uint256 => bool) private charged; // Mapping to check if a token ID is charged
    mapping(uint256 => uint256) private eventCount; // Mapping from token ID to its event count
    uint256 private chestCount; // Counter for chests (not clear without context)

    // Additional mappings for various features and states
    uint256 maxQuality = 3; //
    mapping(uint256 => bool) private isRequestChest;
    // Mapping to check if a VRF request is for a chest
    mapping(address => mapping(uint8 => uint256)) private stakedCategory; // Mapping from address and category to stakes
    mapping(address => uint256[]) private stakedAtovix; // Mapping from address to stakes in Atovix
    mapping(address => uint256) private walletAtovix; // Mapping from address to  Atovix count

    mapping(address => uint256) private playerPower; // Mapping from address to player power

    mapping(address => uint256[3]) private nftMintRoll; // Chainlink piles up results from 2 random numbers here, this space is used to save 2 dice rolls and a

    // Using OpenZeppelin's Counters utility to keep track of token IDs
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    // Mapping from owner to list of owned token IDs
    mapping(address => uint256[]) private _ownedTokens;

    // Mapping from token ID to its index in the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Variable for the contract URI (metadata)
    string public contractURI_; // fee = 200 -> 2%, recipient - > address to receive the fee

    // Commission sharing related variables
    uint256 private totalPowerSupply; // Total power supply for commission calculations

    // Mappings to store the last accumulated commission per token for each player
    mapping(address => uint256) private lastAccumulatedCommissionPerTokenForPlayerATON;
    mapping(address => uint256) private lastAccumulatedCommissionPerTokenForPlayerVUND;

    // Variables for accumulated commission per token and total commission
    uint256 private accumulatedCommissionPerTokenVUND;
    uint256 private accumulatedCommissionPerTokenATON;
    uint256 private totalCommissionVUND;
    uint256 private totalCommissionATON;

    // Constructor to initialize the contract with required addresses and Chainlink VRF parameters
    constructor(
        address _VAULT,
        address _ATON,
        address _vrfCoordinatorV2,
        uint64 _subscriptionId,
        bytes32 _gasLane,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2(_vrfCoordinatorV2) ERC721("Powered Vault Token Collection", "PVT") Ownable(msg.sender) {
        VAULT = IVAULT(_VAULT);
        ATON = IATON(_ATON);
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinatorV2);
        gasLane = _gasLane;
        subscriptionId = _subscriptionId;
        callbackGasLimit = _callbackGasLimit;

        playerPower[address(this)] = 1;
        totalPowerSupply = 1;
    }

    // Marketplace requirement
    function royaltyInfo(uint256 tokenId, uint256 salePrice) public view override returns (address, uint256) {
        uint256 royaltyFraction = 200;
        uint256 royaltyAmount = (salePrice * royaltyFraction) / _feeDenominator();
        address ownerAddress = owner(); // Assuming 'owner()' is a function returning the owner's address
        tokenId = 0;
        return (ownerAddress, royaltyAmount);
    }

    // Override the supportsInterface function to check if a given interfaceId is supported by the contract
    function supportsInterface(bytes4 interfaceId) public view override(ERC721URIStorage, ERC2981) returns (bool) {
        // Call the supportsInterface of ERC721URIStorage to check for support of the interfaceId
        return ERC721URIStorage.supportsInterface(interfaceId);
    }

    // Function to get the contract's metadata URI
    // Marketplace requirement

    function contractURI() public view returns (string memory) {
        // Return the stored contract URI
        return contractURI_;
    }

    // Function to get the token URI for a given tokenId
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        // Ensure the token has been minted before proceeding
        _requireOwned(tokenId);

        // Determine if the token is staked by checking if the owner is the contract itself
        bool staked = (ownerOf(tokenId) == address(this));

        // Fetch the URI for the token based on its traits (category, quality, staked status, and charged status)
        // The traits are encoded into a single uint32 which is used as a key in the uriCode mapping
        uint8 pixelColor = CANVAS.getPixelColor(tokenId);
        string memory uri =
            uriCode[AStructs.encodeTrait(category[tokenId], quality[tokenId], staked, charged[tokenId], pixelColor)];

        // If the URI is non-empty, return it; otherwise, return an empty string
        return bytes(uri).length > 0 ? uri : "";
    }

    // Function to add multiple URIs for tokens
    function setCanvas(address _canvasAddress) external onlyOwner {
        CANVAS = ICANVAS(_canvasAddress);
    }

    // Function to add multiple URIs for tokens
    function addUris(AStructs.traitsUpload[] memory traits) external onlyOwner {
        // Iterate over the array of traits to add URIs
        for (uint8 i = 0; i < traits.length; i++) {
            // Encode the traits and set the corresponding URI in the uriCode mapping
            uriCode[AStructs.encodeTrait(
                traits[i].category, traits[i].quality, traits[i].staked, traits[i].charged, traits[i].color
            )] = traits[i].uri;
        }
    }

    // Function to set a new contract URI
    function setContractURI(string memory _newUri) external onlyOwner {
        // Update the contract URI with the new value
        contractURI_ = _newUri;
    }

    // Function to mint a specific type of NFT called Atovix, only callable by the contract owner
    // TODO: remove for Production
    function mintAtovix(uint16 _atovixQuality) external onlyOwner {
        _mintAtovix(_atovixQuality);
    }

    function _mintAtovix(uint16 _atovixQuality) internal {
        // Create a trait structure for the new Atovix NFT
        AStructs.traitsShort memory trait = AStructs.traitsShort({
            category: NFTcategories.Atovix, // Set the category to Atovix
            quality: _atovixQuality // Set the quality index for the Atovix
        });
        // Mint the NFT with the specified traits
        _mintNFT(msg.sender, trait);
    }

    // Internal function to mint a Treasure Chest NFT
    function _mintTreasureChest() internal {
        chestCount++; // Increment the count of treasure chests

        // Define the traits for the Treasure Chest NFT
        AStructs.traitsShort memory traits = AStructs.traitsShort({
            category: NFTcategories.TreasureChest, // Set the category to 'TreasureChest'
            quality: 1 // Set the quality level to 1
        });
        // Mint the NFT with the defined traits
        _mintNFT(msg.sender, traits);
    }

    // Internal function to initiate the minting of a regular NFT using Chainlink VRF
    function _mintRegularNft() internal returns (uint256 requestId) {
        // Request a random number from Chainlink VRF
        requestId = vrfCoordinator.requestRandomWords(
            gasLane, // The gas lane key hash
            subscriptionId, // The subscription ID for VRF service
            REQUEST_CONFIRMATIONS, // The number of confirmations to wait for
            callbackGasLimit, // The gas limit for the callback function
            3 // Number of random words requested
        );

        // Store the mapping of the requestId to the sender's address
        requestIdToSender[requestId] = msg.sender;
        isRequestChest[requestId] = false; // Mark the request as not for a chest

        // Emit an event indicating that an NFT has been requested
        emit EventsLib.NftRequested(requestId, msg.sender);
    }

    // Internal function to mint an NFT with given traits and assign it to a player
    function _mintNFT(address _player, AStructs.traitsShort memory _trait) internal {
        tokenCounter++; // Increment the token counter

        // Mint the NFT to the player and set its attributes

        _safeMint(_player, tokenCounter);

        category[tokenCounter] = _trait.category;
        quality[tokenCounter] = _trait.quality;
        _addTokenToOwnerEnumeration(_player, tokenCounter); // Add the token to the owner's enumeration

        if (_trait.category == NFTcategories.Atovix) {
            walletAtovix[_player] += 1;
            _updatePlayerPower(NFTcategories.Atovix, 1, msg.sender, true); // Update the player's power
        }

        // Emit an event indicating that an NFT has been minted
        emit EventsLib.NftMinted(_trait, _player);
    }

    // Function to fuse three NFTs into one with higher quality

    function fuseNFT(uint256[3] memory _tokenIdsFuse) external nonReentrant returns (bool) {
        // Validate ownership of the NFTs and get their common quality
        uint16 commonQuality = _validateOwnershipAndGetQuality(_tokenIdsFuse);

        uint8 _category = category[_tokenIdsFuse[0]];

        // Create traits for the new, higher quality NFT
        AStructs.traitsShort memory trait = AStructs.traitsShort({
            category: _category, // Use the same category as the original NFTs
            quality: commonQuality + 1 // Increase the quality by one
        });

        // Mint the new NFT for the player
        _mintNFT(msg.sender, trait);

        // Emit an event indicating that NFTs have been fused
        emit EventsLib.fusion(
            msg.sender,
            _tokenIdsFuse[0],
            _tokenIdsFuse[1],
            _tokenIdsFuse[2],
            tokenCounter, // The new token ID
            category[tokenCounter], // The category of the new NFT
            quality[tokenCounter] // The quality of the new NFT
        );

        if (_category == NFTcategories.Pixel) {
            CANVAS.removePixels(_tokenIdsFuse);
        }
        // Burn the original NFTs to maintain rarity
        for (uint256 i = 0; i < 3; i++) {
            _updatePlayerPower(_category, commonQuality, msg.sender, false); // Update the player's power

            _burn(_tokenIdsFuse[i]); // Burn the original NFT
        }

        return true; // Indicate successful fusion
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        nftMintRoll[requestIdToSender[requestId]] = [randomWords[0], randomWords[1], isRequestChest[requestId] ? 1 : 0];
    }

    function claimNft() external nonReentrant {
        require(nftMintRoll[msg.sender][0] > 0 && nftMintRoll[msg.sender][1] > 0, "No NFTs to mint");

        uint16 qualityFound;
        uint8 categoryFound;

        uint256 rnd0 = nftMintRoll[msg.sender][0];
        uint256 rnd1 = nftMintRoll[msg.sender][1];

        // Determine the category and quality based on the random numbers provided by VRF
        // TREASURE CHEST Type
        if (nftMintRoll[msg.sender][2] > 0) {
            // If the request was for a chest, determine the category accordingly
            categoryFound = _getChestCategoryFromRng(rnd0 % MAX_CATEGORY_Probability);

            if (categoryFound == NFTcategories.Atovix) {
                // If the category is Atovix, determine the quality based on stakes
                qualityFound = uint16((rnd1 % maxQuality) + 1);
            } else {
                // For other categories, determine the quality using a different method
                qualityFound = _getQualityFromRng(rnd1 % _diceSize(maxQuality));
            }
            // REGULAR Type
        } else {
            // For regular minting, determine the category and quality using random numbers
            categoryFound = _getRegularCategoryFromRng(rnd0 % MAX_CATEGORY_Probability);
            qualityFound = _getQualityFromRng(rnd1 % _diceSize(maxQuality));
        }

        // Create the traits for the new NFT
        AStructs.traitsShort memory trait = AStructs.traitsShort({
            category: categoryFound, // Set the determined category
            quality: qualityFound // Set the determined quality
        });

        _mintNFT(msg.sender, trait);

        nftMintRoll[msg.sender][0] = 0;
        nftMintRoll[msg.sender][1] = 0;
        nftMintRoll[msg.sender][2] = 0;
    }

    // NFT Actions

    // Function to allow users to request the minting of a new NFT
    function buyRegularNft() external nonReentrant {
        // The user pays a certain amount of VUND to ATON tokens to request an NFT
        _payToken(_regularNftPrice(), msg.sender, true);

        // Call the internal function to mint a regular NFT
        _mintRegularNft();
    }

    function _regularNftPrice() internal view returns (uint256) {
        return _getVUNDtoATON(100 * 10 ** 18);
    }

    // External function to allow players to purchase a Treasure Chest NFT
    function buyTreasureChest() external nonReentrant returns (bool) {
        // Calculate the price of the Treasure Chest, which increases with each purchase
        // Charge the player the calculated price
        // Mint a Treasure Chest NFT for the player
        _mintTreasureChest();
        _payToken(_chestPrice(), msg.sender, false);
        // Indicate successful purchase
        return true;
    }

    function _chestPrice() internal view returns (uint256) {
        return 10 * 10 ** 18 + 10 ** 16 * chestCount;
    }

    // Internal function to "open" a Treasure Chest NFT
    function _openTreasureChest(uint256 _tokenId) internal returns (uint256 requestId) {
        // Ensure the caller is the owner of the specified NFT
        require(ownerOf(_tokenId) == msg.sender, "Id not own");
        // Update the player's power level as the Treasure Chest is being used

        _transfer(msg.sender, address(this), _tokenId);
        // Request a random number from Chainlink VRF to determine the outcome of opening the chest
        requestId =
            vrfCoordinator.requestRandomWords(gasLane, subscriptionId, REQUEST_CONFIRMATIONS, callbackGasLimit, 2);

        // Map the returned request ID to the sender's address for tracking
        requestIdToSender[requestId] = msg.sender;
        // Mark the request as a Treasure Chest opening
        isRequestChest[requestId] = true;
        // Emit an event indicating the NFT operation
        emit EventsLib.NftRequested(requestId, msg.sender);
    }

    // Allows users to stake their NFTs with specific handling based on NFT categories
    function stakeNFT(uint256 _tokenId) external nonReentrant {
        // Retrieve the traits of the NFT to be staked
        AStructs.traitsFull memory traitsNew = _tokenInfo(_tokenId);

        // Ensure the caller is the owner of the NFT
        require(msg.sender == ownerOf(_tokenId), "Caller not owner");

        // Different handling based on the NFT category
        if (traitsNew.category == NFTcategories.TreasureChest) {
            // Automatically open the Treasure Chest instead of staking it
            _openTreasureChest(_tokenId);
            return;
        }

        if (traitsNew.category == NFTcategories.Atovix) {
            // Directly stake Atovix NFTs without checking for duplicates
            stakedAtovix[msg.sender].push(_tokenId);
        } else {
            // Check for and handle duplicates or same-category NFTs already staked
            bool isDuplicateOrSameCategory = false;
            for (uint256 i = 0; i < stakesArray[msg.sender].length; i++) {
                uint256 stakedTokenId = stakesArray[msg.sender][i];
                AStructs.traitsFull memory traitsStaked = _tokenInfo(stakedTokenId);

                // Revert if a duplicate or same-category NFT is already staked
                if (traitsStaked.category == traitsNew.category) {
                    if (traitsStaked.quality == traitsNew.quality) {
                        revert("Duplicate NFT");
                    }
                    // Unstake the same-category NFT
                    _unStakeNFT(stakedTokenId);
                    // Efficiently remove the unstaked NFT from the stakes array
                    stakesArray[msg.sender][i] = stakesArray[msg.sender][stakesArray[msg.sender].length - 1];
                    stakesArray[msg.sender].pop();
                    isDuplicateOrSameCategory = true;
                    break;
                }
            }

            // Update staked category info if it's not a duplicate or same-category
            if (!isDuplicateOrSameCategory) {
                stakedCategory[msg.sender][traitsNew.category] = _tokenId;
            }
        }

        // Safely transfer the NFT to the contract for staking
        safeTransferFrom(msg.sender, address(this), _tokenId);
        // Record the staking action
        stakesArray[msg.sender].push(_tokenId);

        // Emit an event for staking the NFT (consider adding this if not already implemented)
        // emit NFTStaked(msg.sender, _tokenId);
    }

    // Function to allow users to unstake their NFTs
    function unStakeNFT(uint256 _tokenId) external nonReentrant {
        // Call the internal function to handle the actual unstaking logic
        _unStakeNFT(_tokenId);
    }

    // Internal function to handle unstaking of NFTs
    function _unStakeNFT(uint256 _tokenId) internal {
        // Find the token in the general stakes array and remove it
        uint256 indexGeneralStake = _findAndRemoveStake(_tokenId, stakesArray[msg.sender]);
        // If the token is an Atovix, find it in the Atovix stakes array and remove it
        uint256 indexAtovixStake =
            (category[_tokenId] == NFTcategories.Atovix) ? _findAndRemoveStake(_tokenId, stakedAtovix[msg.sender]) : 0;

        // Ensure that the token is staked (owned by the contract) and the caller is the owner
        require(
            address(this) == ownerOf(_tokenId) && indexGeneralStake != type(uint256).max
                && (category[_tokenId] != NFTcategories.Atovix || indexAtovixStake != type(uint256).max),
            "UnstakeNFT Error"
        );

        // Reset the stakes hash for the token's category
        stakedCategory[msg.sender][category[_tokenId]] = 0;

        // Update the 'charged' status of the token if necessary
        if (!charged[_tokenId]) {
            charged[_tokenId] = _isChargedToken(msg.sender, _tokenId);
        }

        // Transfer the token back to the user, completing the unstaking process
        _transfer(address(this), msg.sender, _tokenId);
    }

    // Internal function to remove a staked NFT from the player's array of staked NFTs
    function _popStakedNFT(address _player, uint256 index) internal {
        // If the token to remove isn't the last one, move the last token to its position
        if (index != stakesArray[_player].length - 1) {
            stakesArray[_player][index] = stakesArray[_player][stakesArray[_player].length - 1];
        }
        // Remove the last token from the array
        stakesArray[_player].pop();
    }

    // Internal function to remove a staked Atovix from the player's array of staked Atovix
    function _popStakedAtovix(address _player, uint256 index) internal {
        // If the token to remove isn't the last one, move the last token to its position
        if (index != stakedAtovix[_player].length - 1) {
            stakedAtovix[_player][index] = stakedAtovix[_player][stakedAtovix[_player].length - 1];
        }
        // Remove the last token from the array
        stakedAtovix[_player].pop();
    }

    // Internal function to calculate the level of a player based on their staked NFTs
    function _getNFTlevel(address _player) internal view returns (uint256) {
        uint256 lvl = 0;
        // Loop through the staked NFTs of the player to aggregate their total quality.
        for (uint256 i = 0; i < stakesArray[_player].length; i++) {
            lvl += quality[stakesArray[_player][i]];
        }
        // Atovix NFTs contribute a fixed amount to the level calculation
        lvl += stakedAtovix[_player].length * 10;
        // Return the calculated level
        return lvl;
    }

    // External function to retrieve a player's NFT data, including both staked and owned NFTs
    function getPlayerNftData(address _player) external view returns (AStructs.traitsFull[] memory) {
        // Calculate the combined total of staked and owned NFTs for the player
        uint256 totalLength = stakesArray[_player].length + _ownedTokens[_player].length;

        // Initialize an array to hold the NFT data
        AStructs.traitsFull[] memory nftDataArray = new AStructs.traitsFull[](totalLength);

        // Counter to track the current insertion position in nftDataArray
        uint256 currentIndex = 0;

        // Iterate through staked NFTs and populate their data in nftDataArray
        for (uint256 i = 0; i < stakesArray[_player].length; i++) {
            nftDataArray[currentIndex] = _tokenInfo(stakesArray[_player][i]);
            currentIndex++;
        }

        // Iterate through owned NFTs and populate their data in nftDataArray
        for (uint256 i = 0; i < _ownedTokens[_player].length; i++) {
            nftDataArray[currentIndex] = _tokenInfo(_ownedTokens[_player][i]);
            currentIndex++;
        }

        // Return the consolidated NFT data array
        return nftDataArray;
    }

    modifier onlyCanvas() {
        require(msg.sender == address(CANVAS), "Not authorized: caller is not the CANVAS");
        _;
    }

    function addEarningsToPlayerInAton(address _player, uint256 _eaningsATON, uint8 _earningCategory)
        external
        onlyCanvas
    {
        VAULT.addEarningsToPlayer(_player, 0, _eaningsATON, "", _earningCategory);
    }

    // Internal function to find a specific NFT in a stake list and remove it
    function _findAndRemoveStake(uint256 _tokenId, uint256[] storage stakeList) internal returns (uint256) {
        for (uint256 i = 0; i < stakeList.length; i++) {
            if (_tokenId == stakeList[i]) {
                // Replace the found token with the last token in the list and shrink the list
                stakeList[i] = stakeList[stakeList.length - 1];
                stakeList.pop();
                return i;
            }
        }
        // Return an "invalid" index if the token was not found
        return type(uint256).max;
    }

    // Internal function to validate ownership and quality of a set of NFTs before an operation like fusion
    function _validateOwnershipAndGetQuality(uint256[3] memory _tokenValIds) internal returns (uint16) {
        // Assume the first token's quality as the initial quality
        uint16 initialQuality = quality[_tokenValIds[0]];
        // Assume the first token's category as the initial category
        uint16 initialCategory = category[_tokenValIds[0]];

        // Check that all tokens are owned by the sender, have the same quality and category, and are charged
        for (uint256 i = 1; i < 3; i++) {
            if (
                !(ownerOf(_tokenValIds[i]) == msg.sender || _isStakedByPlayer(_tokenValIds[i], msg.sender))
                    || quality[_tokenValIds[i]] != initialQuality || category[_tokenValIds[i]] != initialCategory
                    || !charged[_tokenValIds[i]] || category[_tokenValIds[i]] == NFTcategories.Atovix
                    || category[_tokenValIds[i]] == NFTcategories.TreasureChest
            ) {
                revert("Validation failed: Ownership, quality, category, or charge");
            }
        }

        // Return the common quality of the tokens
        return initialQuality;
    }

    // Internal function to check if an NFT is staked by a player and perform cleanup if so
    function _isStakedByPlayer(uint256 tokenId, address player) internal returns (bool) {
        for (uint256 j = 0; j < stakesArray[player].length; j++) {
            if (tokenId == stakesArray[player][j]) {
                // Remove the staked NFT from the player's stakes
                _popStakedNFT(player, j);
                // Remove the NFT from the owner's enumeration under the contract's address
                _removeTokenFromOwnerEnumeration(address(this), tokenId);
                // Indicate successful cleanup
                return true;
            }
        }
        // Indicate the NFT was not staked by the player
        return false;
    }

    // Private function to remove a token from the enumeration of owned tokens for an address
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // Get the index of the last token in the owner's list
        uint256 lastTokenIndex = _ownedTokens[from].length - 1;
        // Retrieve the position of the token being removed in the owner's list
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        if (tokenIndex != lastTokenIndex) {
            // Get the ID of the last token in the owner's list
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];
            // Move the last token to the position of the token being removed
            _ownedTokens[from][tokenIndex] = lastTokenId;
            // Update the position of the moved token in the mapping
            _ownedTokensIndex[lastTokenId] = tokenIndex;
        }

        // Delete the last position in the owner's token list
        _ownedTokens[from].pop();
        // Remove the token's entry from the index mapping
        delete _ownedTokensIndex[tokenId];
    }

    // Internal function to calculate a player's luck based on their NFT level, VAULT level, and current painted pixels
    function _getPlayerLuck(address _player) internal view returns (uint256) {
        // Calculate the NFT level for the player
        uint256 lvlNFT = 10 * _getNFTlevel(_player); // 10*10 * 1 = 100
        // Retrieve the player's level from the VAULT contract
        uint256 lvlVAULT = VAULT.getPlayerLevel(msg.sender); // 100 2.2  = 220
        // Get the number of pixels currently painted by the player

        AStructs.playerCanvasInfo memory playerCanvasInfo = CANVAS.playerCanvasInfo(_player);
        uint256 lvlcurrentPaintedPixels = (playerCanvasInfo.dailyPaintCount + 1) * playerCanvasInfo.currentPaintedPixels; // 10   *   21 = 210
        // Define a luck factor, which is a constant to scale the luck value
        uint256 factor = 500;

        // Return the total luck, which is a weighted sum of the NFT level, VAULT level, and painted pixels
        return factor * (lvlNFT + lvlVAULT + lvlcurrentPaintedPixels); // 500 * 500 =  250000
    }

    // Internal pure function to calculate the size of the dice based on the maximum quality
    // This is used for determining the probability distribution of NFT qualities
    function _diceSize(uint256 _maxQuality) internal pure returns (uint256) {
        uint256 sumWeights = 0;
        // Calculate the sum of weights for the dice roll, which decreases exponentially with quality
        for (uint256 i = 1; i <= _maxQuality; i++) {
            sumWeights += AStructs.pct_denom / 2 ** i;
        }
        // Return the total sum of weights
        return sumWeights;
    }

    // Internal function to build an array representing the Probability of each quality level for a given category
    function _buildQualityProbabilityArray() internal view returns (uint256[] memory) {
        // Retrieve the maximum quality for the category

        // Initialize an array to store the Probability of each quality level
        uint256[] memory array = new uint256[](maxQuality + 1);
        // Calculate the size of the dice for the given maximum quality
        uint256 diceSize = _diceSize(maxQuality);
        // The first element represents the total weight
        array[0] = diceSize;

        // Populate the array with the Probability of each quality level
        for (uint256 i = 1; i < array.length; i++) {
            // The Probability decreases exponentially with the quality level
            array[i] = array[i - 1] - AStructs.pct_denom / (2 ** (i));

            // Ensure the last element represents the smallest Probability (1)
            if (i + 1 == array.length) {
                array[i] = 1;
            }
        }
        // Return the array with all the Probabilitys
        return array;
    }

    // #endregion Mint + ChainLink +(Stake)

    // Internal pure function to determine the category of a regular NFT based on a random number
    function _getRegularCategoryFromRng(uint256 categoryRng) internal pure returns (uint8) {
        uint256 cumulativeSum = 0; // Initialize cumulative sum to 0.
        uint256[32] memory categoryProbabilityArray = _getRegularProbabilityCategoryArray(); // Fetch the cumulative distribution array.

        // Ensure the categoryRng doesn't go beyond the length of categoryProbabilityArray.
        if (categoryRng > categoryProbabilityArray.length) {
            categoryRng = categoryProbabilityArray.length;
        }

        for (uint256 i = 0; i < categoryProbabilityArray.length; i++) {
            // Loop through each element in the cumulative distribution.

            // Check if the given random number lies between the last cumulative sum
            // and the current item in the array, which means the category has been identified.
            if (categoryRng >= cumulativeSum && categoryRng < categoryProbabilityArray[i]) {
                uint8 categoryFound = _getRegularCategoryIndex(i); // Fetch the category index based on the loop counter.

                return categoryFound; // Return the determined category.
            }

            // Update the cumulativeSum for the next iteration.
            cumulativeSum = categoryProbabilityArray[i];
        }

        // If the function hasn't returned a category by this point, the categoryRng doesn't map
        // to any category, and thus, the function will revert.
        return 1;
    }

    // Internal view function to determine the category of a treasure chest NFT based on a random number
    // and the player's luck
    function _getChestCategoryFromRng(uint256 _categoryRng) internal view returns (uint8) {
        uint256 cumulativeSum = 0;
        uint256[4] memory categoryProbabilityArray = _chestProbabilityCategoryArray();

        // Ensuring _categoryRng doesn't exceed the length of categoryProbabilityArray.
        if (_categoryRng > categoryProbabilityArray.length) {
            _categoryRng = categoryProbabilityArray.length;
        }

        uint256 playerLuck = _getPlayerLuck(msg.sender); // Calculate the player's luck.

        // Adjust the random number by subtracting player's luck.
        if (playerLuck > _categoryRng) {
            _categoryRng = 0;
        } else {
            _categoryRng -= playerLuck;
        }

        for (uint256 i = 0; i < categoryProbabilityArray.length; i++) {
            // Looping through each value in the cumulative distribution.

            // If the provided random number lies between the previous cumulative sum
            // and the current value in the array, the category is found.
            if (_categoryRng >= cumulativeSum && _categoryRng < categoryProbabilityArray[i]) {
                uint8 categoryFound = _chestCategoryIndex(i); // Fetch the category index.

                return categoryFound; // Return the identified category.
            }

            // Update the cumulativeSum for the next iteration.
            cumulativeSum = categoryProbabilityArray[i];
        }

        // If the function hasn't returned by this point, the categoryRng doesn't map
        // to any category, and the function will revert.
        return 1; // Return the identified category.
    }

    // Internal pure function to build an array representing the cumulative Probability of each regular category
    function _getRegularProbabilityCategoryArray() internal pure returns (uint256[32] memory) {
        uint256[32] memory categoryProbabilityArray;

        // Setting base Probability for the first category.
        categoryProbabilityArray[0] = 20;

        // Incrementing the Probabilitys by 21 for the next 29 categories (potentially sports-related).
        for (uint256 i = 1; i <= 29; i++) {
            categoryProbabilityArray[i] = categoryProbabilityArray[i - 1] + 1 + 20;
        }

        // Special categories with their own thematic representations and Probabilitys incremented by 3.
        categoryProbabilityArray[30] = categoryProbabilityArray[29] + 1 + 9; // Treasure Chest
        categoryProbabilityArray[31] = categoryProbabilityArray[30] + 1 + 9; // VUND rocket

        return categoryProbabilityArray;
    }

    // Internal pure function to build an array representing the cumulative Probability of each chest category
    function _chestProbabilityCategoryArray() internal pure returns (uint256[4] memory) {
        uint256[4] memory categoryProbabilityArray;

        // Base Probability for the first category.
        categoryProbabilityArray[0] = 7000000;

        // Cumulative Probability for ATON rocket, which is the base Probability + 1 + 2.
        categoryProbabilityArray[1] = categoryProbabilityArray[0] + 1 + 3000000;

        // Cumulative Probability for VUND rocket.
        // This should ideally reference the previous category's Probability.
        categoryProbabilityArray[2] = categoryProbabilityArray[1] + 1 + 1500000;

        // Cumulative Probability for Atovix Vunders category.
        categoryProbabilityArray[3] = categoryProbabilityArray[2] + 1 + 1000000;

        return categoryProbabilityArray;
    }

    // External pure function to expose the regular Probability category array
    function getRegularProbabilityCategoryArray() external pure returns (uint256[32] memory) {
        return _getRegularProbabilityCategoryArray();
    }

    // External pure function to expose the chest Probability category array
    function getChestProbabilityCategoryArray() external pure returns (uint256[4] memory) {
        return _chestProbabilityCategoryArray();
    }

    // Public view function to determine the quality of an NFT based on a random number and the player's luck
    function _getQualityFromRng(uint256 _qualityRng) public view returns (uint8) {
        // Retrieve the level of the NFT for the calling player.
        uint256 playerLuck = _getPlayerLuck(msg.sender);

        // Adjust the random number by subtracting player's luck.
        if (playerLuck > _qualityRng) {
            _qualityRng = 0;
        } else {
            _qualityRng -= playerLuck;
        }

        // Retrieve the maximum quality possible for the given category.

        // Define the range (dice size) for the random number based on the maximum quality.
        uint256 diceSize = _diceSize(maxQuality);

        // Ensure the random number doesn't exceed the defined range.
        if (_qualityRng > diceSize) {
            _qualityRng = diceSize;
        }

        // Build an array that defines the Probabilitys of each quality for the provided category.
        uint256[] memory qualityProbabilityArray = _buildQualityProbabilityArray();

        // Initialize a variable to store the found quality.
        uint8 qualityFound = 1;

        // Loop through each quality Probability in the array.
        for (uint8 i = 0; i < qualityProbabilityArray.length; i++) {
            // If we are not at the last quality Probability in the array...
            if (i + 1 < qualityProbabilityArray.length) {
                // Check if the random number falls between the current quality Probability and the next one.
                if (_qualityRng < qualityProbabilityArray[i] && _qualityRng > qualityProbabilityArray[i + 1]) {
                    qualityFound = i + 1; // Set the quality to the current index + 1.
                }
            } else {
                // If we are at the last quality Probability in the array, simply check if the random number is less than the current quality Probability.
                if (_qualityRng < qualityProbabilityArray[i]) {
                    qualityFound = i + 1; // Set the quality to the current index + 1.
                }
            }
        }

        // Return the found quality.
        return qualityFound;
    }

    // Internal pure function to get the index of a regular category based on the position in the array
    function _getRegularCategoryIndex(uint256 i) internal pure returns (uint8) {
        return NFTcategories.getRegularCategoryIndex(i);
    }

    // Internal pure function to get the index of a chest category based on the position in the array
    function _chestCategoryIndex(uint256 i) internal pure returns (uint8) {
        return NFTcategories.getChestCategoryIndex(i);
    }

    // Internal view function to get the count of events for a given player and category.
    // If the category is less than 90, it retrieves the specific event counter from the VAULT,
    // otherwise, it retrieves the general event counter (category 0).
    function _getEventCount(address _player, uint8 _category) internal view returns (uint256) {
        if (_category < 90) {
            //  If NFT is a SPORTS NFT
            return VAULT.eventWinCount(_player, _category); // Retrieve event count for specific category.
        } else if (_category == NFTcategories.AtonTicket) {
            return VAULT.eventOpenWinCount(_player, _category); // Retrieve event count for specific category.
        } else {
            return VAULT.eventWinCount(_player, 0); // Retrieve general event count for categories >= 90.
        }
    }

    // Internal view function to check if a token is charged based on the event count and the token's quality.
    // It calculates if the token's event count has increased by a factor of 2 to the power of its quality
    // since the last update.
    function _isChargedToken(address _player, uint256 _tokenId) internal view returns (bool) {
        // Retrieve the final event count for the NFT's category and its owner.
        uint256 eventsCountFinal = _getEventCount(_player, category[_tokenId]);

        // Check if the difference between the final event count and the NFT's last update event count
        // meets or exceeds the threshold for its category.
        if (eventsCountFinal - eventCount[_tokenId] >= 2 ** quality[_tokenId]) {
            return true; // The token is charged if the condition is met.
        }
        return false; // The token is not charged if the condition is not met.
    }

    // External view function to get the quality of the token staked by the player in a specific category.
    // If a token is staked in the given category, it returns its quality; otherwise, it returns 0.
    function getBonus(address _player, uint8 _category) external view returns (uint16) {
        uint256 tokenId = stakedCategory[_player][_category]; // Retrieve the tokenId staked in the specified category.

        if (tokenId > 0) {
            return quality[tokenId]; // Return the quality of the staked token if it exists.
        } else {
            return 0; // Return 0 if no token is staked in the specified category.
        }
    }

    // Internal view function that calculates the unclaimed commissions for a player in VUND and ATON tokens.
    function _playerCommission(address _player)
        internal
        view
        returns (uint256 unclaimedCommissionVUND, uint256 unclaimedCommissionATON)
    {
        uint256 playerPowerValue = playerPower[_player]; // Retrieves the player's power value.
        uint256 tokenUnit = 10 ** 18; // Defines the token unit for calculation,  18 decimal places.

        // Calculate the unclaimed commission for VUND tokens.
        unclaimedCommissionVUND = _calculateUnclaimedCommission(
            playerPowerValue,
            accumulatedCommissionPerTokenVUND,
            lastAccumulatedCommissionPerTokenForPlayerVUND[_player],
            tokenUnit
        );

        // Calculate the unclaimed commission for ATON tokens.
        unclaimedCommissionATON = _calculateUnclaimedCommission(
            playerPowerValue,
            accumulatedCommissionPerTokenATON,
            lastAccumulatedCommissionPerTokenForPlayerATON[_player],
            tokenUnit
        );
    }

    // Private pure function to calculate the unclaimed commission based on player power and accumulated commission rates.
    function _calculateUnclaimedCommission(
        uint256 playerPowerValue,
        uint256 accumulatedCommissionPerToken,
        uint256 lastAccumulatedCommissionPerTokenForPlayer,
        uint256 tokenUnit
    ) private pure returns (uint256 unclaimedCommission) {
        uint256 owedPerToken = accumulatedCommissionPerToken - lastAccumulatedCommissionPerTokenForPlayer; // Calculate the difference in accumulated commission.
        if (owedPerToken > 0) {
            unclaimedCommission = (playerPowerValue * owedPerToken) / tokenUnit; // Calculate the unclaimed commission if owed per token is greater than zero.
        } else {
            unclaimedCommission = 0; // Set unclaimed commission to zero if no commission is owed.
        }
    }

    // Internal function to accumulate commission in VUND and ATON tokens.
    function _accumulateCommission(uint256 _newCommissionVUND, uint256 _newCommissionATON) internal {
        // Update the accumulated commission per power unit for VUND tokens.
        accumulatedCommissionPerTokenVUND += (_newCommissionVUND * (10 ** 18)) / totalPowerSupply;

        // Update the accumulated commission per power unit for ATON tokens.
        accumulatedCommissionPerTokenATON += (_newCommissionATON * (10 ** 18)) / totalPowerSupply;

        // Increase the total stored commissions for both VUND and ATON tokens.
        totalCommissionVUND += _newCommissionVUND;
        totalCommissionATON += _newCommissionATON;

        // Emit an event to log the accumulation of commissions.
        emit EventsLib.AccumulateNFT(
            _newCommissionVUND, accumulatedCommissionPerTokenVUND, _newCommissionATON, accumulatedCommissionPerTokenATON
        );
    }

    // Internal function to distribute the accumulated commission to a player.
    function _distributeCommission(address player) internal {
        // Retrieve the player's unclaimed commissions for VUND and ATON.
        (uint256 unclaimedCommissionVUND, uint256 unclaimedCommissionATON) = _playerCommission(player);

        // Distribute the VUND commission if it is greater than zero.
        if (unclaimedCommissionVUND > 0) {
            _distributeVUNDCommission(player, unclaimedCommissionVUND);
        }

        // Distribute the ATON commission if it is greater than zero.
        if (unclaimedCommissionATON > 0) {
            _distributeATONCommission(player, unclaimedCommissionATON);
        }

        // Emit an event after distributing both types of commissions to the player.
        emit EventsLib.Earnings(
            "",
            player,
            "",
            player,
            unclaimedCommissionVUND,
            unclaimedCommissionATON,
            uint8(AStructs.EarningCategory.CommissionPower)
        );
    }

    // Internal function to distribute VUND commission to a player.
    function _distributeVUNDCommission(address player, uint256 commission) internal {
        // Transfer the VUND commission to the player or the owner if the player is the contract itself.
        VAULT.transfer(player == address(this) ? owner() : player, commission);

        // Update the record of the last accumulated commission per token for the player.
        lastAccumulatedCommissionPerTokenForPlayerVUND[player] = accumulatedCommissionPerTokenVUND;
    }

    // Internal function to distribute ATON commission to a player.
    function _distributeATONCommission(address player, uint256 commission) internal {
        // Transfer the ATON commission to the player or the owner if the player is the contract itself.
        ATON.transfer(player == address(this) ? owner() : player, commission);

        // Update the record of the last accumulated commission per token for the player.
        lastAccumulatedCommissionPerTokenForPlayerATON[player] = accumulatedCommissionPerTokenATON;
    }

    // Updates a player's power based on their NFT category, quality, and whether power is being added or removed.
    // @param _category The NFT category
    // @param _quality The quality level of the NFT
    // @param _player The address of the player
    // @param isAdd A boolean indicating if the power is being added (true) or removed (false)
    function _updatePlayerPower(uint8 _category, uint16 _quality, address _player, bool isAdd) internal {
        // Distribute any unclaimed commission to the player before updating their power
        _distributeCommission(_player);

        // Variable to hold the power unit value
        uint256 _unit;

        // Calculate the power unit based on the NFT category and quality
        if (_category == NFTcategories.Atovix) {
            // Retrieve the count of Atovix tokens staked by the player
            uint256 atovixCount = walletAtovix[_player];

            // Calculate the new power points based on the current Atovix count.
            // If no Atovix tokens are staked (count is 0), new power points are 0.
            // Otherwise, use the formula: atovixCount * (atovixCount - 1).
            // This formula rewards the staking of multiple Atovix tokens,
            // as the power increases quadratically with the number of tokens staked.
            uint256 newPoints = atovixCount == 0 ? 0 : atovixCount * (atovixCount - 1);

            // Calculate the previous power points, which represents the power before
            // the current add/remove operation. It's based on the previous Atovix count.
            // If the count is less than 2, previous power points are 0.
            // Otherwise, calculate using the count minus one: (atovixCount - 1) * (atovixCount - 2).
            uint256 previousPoints = atovixCount < 2 ? 0 : (atovixCount - 1) * (atovixCount - 2);

            // Determine the power unit to be added or removed.
            // If adding power (isAdd is true), the unit is the difference between the new and previous points.
            // This represents the additional power gained by staking an additional Atovix token.
            // If removing power, calculate the difference in reverse, considering the removal of a token.
            // The formula for removal is the difference between the power if one more token had been staked
            // and the new power after actually removing the token.
            _unit = isAdd ? newPoints - previousPoints : (atovixCount + 1) * atovixCount - newPoints;
        } else {
            // Default power calculation for other categories
            _unit = _calculatePowerSupplyByQuality(_quality);
        }

        // Update the player's power and the total power supply
        if (isAdd) {
            playerPower[_player] += _unit; // Add power to the player's total
            totalPowerSupply += _unit; // Increase the total power supply
        } else {
            playerPower[_player] -= _unit; // Subtract power from the player's total
            totalPowerSupply -= _unit; // Decrease the total power supply
        }
    }

    // Calculates f(quality) = 2^(2*quality - 1) with a cap on quality to prevent overflow
    // Ensures that the output remains within the uint256 limit
    function _calculatePowerSupplyByQuality(uint256 _quality) public pure returns (uint256) {
        // Cap _quality at 128 to prevent overflow in result calculation
        if (_quality > 128) {
            _quality = 128;
        }

        // Perform the direct calculation for 2^(2*_quality - 1)
        // This calculation is safe for _quality values up to 128, avoiding uint256 overflows
        return 2 ** (2 * _quality - 1);
    }

    // Internal function to handle token payments and commission accumulation.
    function _payToken(uint256 _tokenAmount, address _player, bool isATON) internal {
        // Transfer the specified token amount from the player to the contract.
        // If the token is ATON, use the ATON contract; otherwise, use the VAULT contract.
        // The transfer must succeed, otherwise the function will revert.

        require(
            (
                isATON
                    ? ATON.transferFrom(_player, address(this), _tokenAmount)
                    : IATON(address(VAULT)).transferFrom(_player, address(this), _tokenAmount)
            ),
            "Transfer failed"
        );

        // Accumulate commission for the contract based on the type of token paid.
        _accumulateCommission(isATON ? 0 : _tokenAmount, isATON ? _tokenAmount : 0);
    }

    // Internal override function to handle the transfer of tokens.
    function _transfer(address from, address to, uint256 tokenId) internal override {
        uint8 _category = category[tokenId]; // Retrieve the category of the token.
        uint16 _quality = quality[tokenId]; // Retrieve the quality of the token.

        // If the token is not being minted, remove it from the sender's list and update their power.
        if (from != address(0)) {
            _removeTokenFromOwnerEnumeration(from, tokenId); // Remove the token from the sender's enumeration.
            if (charged[tokenId] || from == address(this)) {
                _updatePlayerPower(_category, _quality, from, false); // Decrease the sender's power.
            }

            if (_category == NFTcategories.Atovix) {
                walletAtovix[from] -= 1;
            }
        }

        // If the token is not being burned, add it to the recipient's list and update their power.
        if (to != address(0)) {
            _addTokenToOwnerEnumeration(to, tokenId); // Add the token to the recipient's enumeration.
            if (charged[tokenId] || to == address(this)) {
                _updatePlayerPower(_category, _quality, to, true); // Increase the recipient's power.
            }
            if (_category == NFTcategories.Atovix) {
                walletAtovix[to] += 1;
            }
        }

        super._transfer(from, to, tokenId); // Call the parent contract's transfer function.
    }

    // Private function to add a token to the enumeration of owned tokens for an address.
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        _ownedTokensIndex[tokenId] = _ownedTokens[to].length; // Set the index of the token in the owner's list.
        _ownedTokens[to].push(tokenId); // Add the token to the owner's list.
    }

    // QUERIES
    // External view function to get a list of tokens owned by a specific address.
    function tokensOfOwner(address owner) external view returns (uint256[] memory) {
        return _ownedTokens[owner]; // Return the list of tokens owned by the address.
    }

    // External view function to provide a summary of contract and player information including unclaimed commissions.
    function pvtSummary(address _player) external view returns (AStructs.PvtSummary memory) {
        // Retrieve unclaimed commissions for the player.
        (uint256 unclaimedCommissionVUND, uint256 unclaimedCommissionATON) = _playerCommission(_player);

        // Construct and return a summary struct with various contract and player details.
        AStructs.PvtSummary memory _summary = AStructs.PvtSummary({
            tokenCounter: tokenCounter, // Total number of tokens.
            chestCount: chestCount, // Number of chests.
            chestPrice: _chestPrice(), //Price of a treasure chest NFT in VUND.
            regularPrice: _regularNftPrice(), // Price of a regular NFT in ATON
            playerPower: playerPower[_player], // Power Supply from Player NFTs
            totalPowerSupply: totalPowerSupply, // Total power supply in the game/contract.
            unclaimedCommissionVUND: unclaimedCommissionVUND, // Unclaimed VUND commission for the player.
            unclaimedCommissionATON: unclaimedCommissionATON, // Unclaimed ATON commission for the player.
            totalCommissionVUND: 0,
            totalCommissionATON: 0,
            stakedNftLevel: _getNFTlevel(_player), // Player's level in the VAULT.
            luck: _getPlayerLuck(_player),
            claimNFT: nftMintRoll[_player][0] > 0 && nftMintRoll[_player][1] > 0,
            stakedAtovixCount: stakedAtovix[_player].length
        });

        return _summary; // Return the constructed summary.
    }

    // External view function to get detailed information about a token.
    function getQuality(uint256 _tokenId) external view returns (uint16) {
        return quality[_tokenId]; // Return the result of the internal function _tokenInfo.
    }

    // External view function to get detailed information about a token.
    function tokenInfo(uint256 tokenId) external view returns (AStructs.traitsFull memory) {
        return _tokenInfo(tokenId); // Return the result of the internal function _tokenInfo.
    }

    // Internal view function to get detailed information about a token.
    function _tokenInfo(uint256 _tokenId) internal view returns (AStructs.traitsFull memory) {
        // Retrieve various attributes of the token using its ID.
        uint8 _category = category[_tokenId];
        uint16 _quality = quality[_tokenId];
        // (uint128 x, uint128 y) = AStructs.decodeCoordinates(tokenIdCoordinates[_tokenId]);

        bool _staked = _ownerOf(_tokenId) == address(this); // Determine if the token is staked.
        bool chargeThis = charged[_tokenId]; // Retrieve the charged status of the token.

        // If the token is staked and not charged, check if it should be charged.
        if (_staked && !chargeThis) {
            chargeThis = _isChargedToken(msg.sender, _tokenId);
        }

        // Construct and return the full traits of the token.

        uint8 pixelColor = 0;

        if (_category == NFTcategories.Pixel) {
            pixelColor = CANVAS.getPixelColor(_tokenId);
        }
        return AStructs.traitsFull({
            tokenId: _tokenId,
            category: _category,
            quality: _quality,
            uri: uriCode[AStructs.encodeTrait(_category, _quality, _staked, chargeThis, pixelColor)],
            staked: _staked,
            charged: chargeThis
        });
    }

    // Internal view function to convert VUND tokens to ATON tokens.
    function getVUNDtoATON(uint256 _amountVUND) external view returns (uint256) {
        // Calculate the ATON equivalent of the VUND amount using a conversion factor.
        return _getVUNDtoATON(_amountVUND);
    }

    function _getVUNDtoATON(uint256 _amountVUND) internal view returns (uint256) {
        // Calculate the ATON equivalent of the VUND amount using a conversion factor.
        return (_amountVUND * AStructs.pct_denom) / IATON(ATON).calculateFactorAton();
    }
}
// All rights reserved. This software and associated documentation files (the "Software"),
// cannot be used, copied, modified, merged, published, distributed, sublicensed, and/or
// sold without the express and written permission of the owner.
