//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "./NextCardVerifier.sol" as NextCardVerifier;
import "./CommitSuitVerifier.sol" as CommitSuitVerifier;

contract CardGame {
    uint256 public constant SNARK_FIELD =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint256 players = 0;
    mapping(address => uint256) public playerIndices;
    mapping(address => uint256) public playerSuitRoots;
    mapping(address => uint256) public nextCard;
    mapping(uint256 => bool) public cardNullifier;
    mapping(address => uint256[]) public cardTrapdoors;
    mapping(address => uint32[2]) public cards;

    function addPlayer(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[1] memory input
    ) public returns (uint256) {
        CommitSuitVerifier.Verifier verifier = new CommitSuitVerifier.Verifier();
        require(verifier.verifyProof(a, b, c, input));

        playerIndices[msg.sender] = players++;
        playerSuitRoots[msg.sender] = input[0];

        return playerIndices[msg.sender];
    }

    function setNextCard(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[6] memory input
    ) public {
        NextCardVerifier.Verifier verifier = new NextCardVerifier.Verifier();

        require(playerSuitRoots[msg.sender] == input[2]);
        require(playerIndices[msg.sender] == input[3]);
        require(verifier.verifyProof(a, b, c, input));

        // Never see this card before
        require(cardNullifier[input[1]] == false);
        cardNullifier[input[1]] = true;
        nextCard[msg.sender] = input[0];
    }

    function revealCard(
        uint256 root,
        uint32 cardNumber,
        uint32 playerIndice,
        uint32 cardTreeIndice,
        uint256 cardTrapdoor
    ) public {
        uint256 commit = cardCommitment(
            root,
            cardNumber,
            playerIndice,
            cardTreeIndice,
            cardTrapdoor
        );
        require(commit == nextCard[msg.sender]);

        cardTrapdoors[msg.sender].push(cardTrapdoor);
        cards[msg.sender][0] = cardNumber;
        cards[msg.sender][1] = cardTreeIndice;
    }

    function cardCommitment(
        uint256 root,
        uint32 cardNumber,
        uint32 playerIndice,
        uint32 cardTreeIndice,
        uint256 cardTrapdoor
    ) public pure returns (uint256) {
        bytes memory data = new bytes(32 + 4 + 4 + 4 + 32);
        assembly {
            mstore(add(data, 0x4c), cardTrapdoor)
            mstore(add(data, 0x2c), cardTreeIndice)
            mstore(add(data, 0x28), playerIndice)
            mstore(add(data, 0x24), cardNumber)
            mstore(add(data, 0x20), root)
        }

        uint256 commitment = uint256(sha256(data)) % SNARK_FIELD;
        return commitment;
    }
}
