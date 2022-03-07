//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./SimpleMerkleTree.sol";

contract GameItem is ERC721URIStorage {
    using Counters for Counters.Counter;
    using Strings for uint256;

    Counters.Counter private _tokenIds;
    SimpleMerkleTree4 merkleTree;

    constructor() ERC721("GameItem", "ITM") {
        merkleTree = new SimpleMerkleTree4();
        bytes32 zeroRoot = hex"890740a8eb06ce9be422cb8da5cdafc2b58c0a5e24036c578de2a433c828ff7d";
        assert(merkleTree.root() == zeroRoot);
    }

    function awardItem(address player) public returns (uint256) {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        require(newItemId < 5, "reach max game item id");
        require(newItemId > 0, "minimal id is 1");

        // Here we encode raw json erc721 metadata string into a base64
        // string and use it as TokenURI.
        // Reference: https://docs.openzeppelin.com/contracts/4.x/utilities#base64
        bytes memory dataURI = abi.encodePacked(
            "{",
                '"name": "GameItem #', newItemId.toString(), '",',
                '"description": "demo game item nft"',
            "}"
        );
        string memory tokenURI = string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(dataURI)
            )
        );

        _mint(player, newItemId);
        _setTokenURI(newItemId, tokenURI);

        bytes32 leafCom = keccak256(
            abi.encodePacked(msg.sender, player, newItemId, tokenURI)
        );
        // Aka id 1 => merkle leaf index 0 and id 2 => 1 merkle leaf index 1
        merkleTree.update(leafCom, newItemId - 1);

        return newItemId;
    }

    function merkleRoot() public view returns (bytes32) {
        return merkleTree.root();
    }
}
