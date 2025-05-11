// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

contract OrisCoin is ERC721URIStorage, Ownable, VRFConsumerBase {
    uint256 public tokenCounter;
    bytes32 internal keyHash;
    uint256 internal fee;

    struct OrisMetadata {
        uint8[9] numbers;
        uint256 drawId;
        bool claimed;
    }

    mapping(uint256 => OrisMetadata) public orisData;
    mapping(uint256 => uint8[20]) public dailyDraws;

    event CoinMinted(address indexed owner, uint256 tokenId, uint8[9] numbers);
    event DrawCompleted(uint256 drawId, uint8[20] drawnNumbers);

    constructor(
        address vrfCoordinator,
        address linkToken,
        bytes32 _keyHash,
        uint256 _fee
    ) ERC721("OrisCoin", "ORIS") VRFConsumerBase(vrfCoordinator, linkToken) {
        tokenCounter = 0;
        keyHash = _keyHash;
        fee = _fee;
    }

    function mintCoin(address to, uint8[9] memory numbers) public onlyOwner {
        uint256 tokenId = tokenCounter;
        _safeMint(to, tokenId);
        orisData[tokenId] = OrisMetadata(numbers, 0, false);
        emit CoinMinted(to, tokenId, numbers);
        tokenCounter++;
    }

    function requestDailyDraw() public onlyOwner returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
        return requestRandomness(keyHash, fee);
    }

    function fulfillRandomness(bytes32, uint256 randomness) internal override {
        uint8[20] memory result;
        uint8 count = 0;
        for (uint8 i = 0; i < 80 && count < 20; i++) {
            uint8 value = uint8((uint256(keccak256(abi.encode(randomness, i))) % 80) + 1);
            bool duplicate = false;
            for (uint8 j = 0; j < count; j++) {
                if (result[j] == value) {
                    duplicate = true;
                    break;
                }
            }
            if (!duplicate) {
                result[count] = value;
                count++;
            }
        }
        dailyDraws[block.timestamp] = result;
        emit DrawCompleted(block.timestamp, result);
    }

    function checkMatch(uint256 tokenId, uint256 drawId) public view returns (uint8 matches) {
        require(_exists(tokenId), "Token does not exist");
        uint8[9] memory userNums = orisData[tokenId].numbers;
        uint8[20] memory drawNums = dailyDraws[drawId];
        for (uint8 i = 0; i < 9; i++) {
            for (uint8 j = 0; j < 20; j++) {
                if (userNums[i] == drawNums[j]) {
                    matches++;
                }
            }
        }
    }
}
