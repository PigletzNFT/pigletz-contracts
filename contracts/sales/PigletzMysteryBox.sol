// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../piglet/IPigletz.sol";

struct MysteryBoxData {
    uint256 tokenId;
    uint256 numberOfPiglets;
    string tokenURI;
}

contract PigletzMysteryBox is ERC721Enumerable, Ownable {
    using Strings for uint16;

    uint256 _currentTokenId;
    mapping(uint256 => uint8) _numForPiglet;
    uint256 _totalNumberOfPiglets;
    IPigletz _pigletz;
    string _uri;

    constructor(address pigletz) ERC721("PigletzMysteryBox", "PigletzMysteryBox") {
        _currentTokenId = 0;
        _pigletz = IPigletz(pigletz);
    }

    event MysteryBoxOpened(address indexed owner, uint256 tokenId);

    function getTotalNumberOfPiglets() public view returns (uint256) {
        return _totalNumberOfPiglets;
    }

    function getNumberOfPiglets(uint256 tokenId) public view returns (uint16) {
        return _numForPiglet[tokenId];
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _uri = baseURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "URI query for nonexistent token");

        return bytes(_uri).length > 0 ? string(abi.encodePacked(_uri, getNumberOfPiglets(tokenId).toString())) : "";
    }

    function mint(
        address to,
        uint256 amount,
        uint8 numPiglets
    ) public onlyOwner {
        for (uint256 i = 0; i < amount; i++) {
            _currentTokenId++;
            _mint(to, _currentTokenId);
            _numForPiglet[_currentTokenId] = numPiglets;
            _totalNumberOfPiglets += numPiglets;
        }
    }

    function open(uint256 tokenId) public {
        require(ownerOf(tokenId) == msg.sender, "Only the owner can open the box");

        _pigletz.mint(msg.sender, _numForPiglet[tokenId], 0);
        _burn(tokenId);

        emit MysteryBoxOpened(msg.sender, tokenId);
    }

    function burn(uint256 tokenId) public {
        require(_exists(tokenId), "ERC721: token with the given token ID does not exist");
        require(ownerOf(tokenId) == msg.sender, "You are not the owner of this token");
        _totalNumberOfPiglets -= _numForPiglet[tokenId];
        _numForPiglet[tokenId] = 0;
        _burn(tokenId);
    }

    function mysteryBoxesByOwner(address owner) public view returns (MysteryBoxData[] memory) {
        uint256 numTokens = balanceOf(owner);
        MysteryBoxData[] memory result = new MysteryBoxData[](numTokens);
        for (uint256 index = 0; index < numTokens; index++) {
            uint256 tokenId = tokenOfOwnerByIndex(owner, index);
            result[index] = MysteryBoxData(tokenId, _numForPiglet[tokenId], tokenURI(tokenId));
        }
        return result;
    }
}
