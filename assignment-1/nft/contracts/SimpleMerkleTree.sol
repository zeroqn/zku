//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract SimpleMerkleTree4 {
    // 1 root + 2 branches + 4 leaves
    bytes32[7] nodes;
    uint256 leafOffset = 3;
    uint256 branchOffset = 1;

    // Construct a merkle tree use zero as leaf
    constructor() {
        // Calculate leaf hashes
        for (uint256 i = 0; i < 4; i++) {
            nodes[i + leafOffset] = keccak256(abi.encodePacked(uint256(0)));
        }

        // Calculate branch hashes
        for (uint256 i = 0; i < 2; i++) {
            bytes32 left = nodes[i * 2 + leafOffset];
            bytes32 right = nodes[i * 2 + leafOffset + 1];
            nodes[i + branchOffset] = keccak256(abi.encodePacked(left, right));
        }

        nodes[0] = keccak256(abi.encodePacked(nodes[1], nodes[2]));
    }

    function zeroHash() public pure returns (bytes32) {
        return keccak256(abi.encodePacked(uint256(0)));
    }

    function root() public view returns (bytes32) {
        return nodes[0];
    }

    function getLeaves() public view returns (bytes32[4] memory) {
        bytes32[4] memory leaves;
        for (uint256 i = 0; i < 4; i++) {
            leaves[i] = nodes[i + leafOffset];
        }
        return leaves;
    }

    function update(bytes32 leaf, uint256 leafIndex) public returns (bytes32) {
        require(leafIndex < 4, "leaf index out of bound");

        // Update leaf
        uint256 index = leafIndex + leafOffset;
        nodes[index] = keccak256(abi.encodePacked(leaf));

        while (0 != index) {
            uint256 parentIndex = (index - 1) / 2;
            if ((index - 1) % 2 == 0) {
                // Left
                nodes[parentIndex] = keccak256(
                    abi.encodePacked(nodes[index], nodes[index + 1])
                );
            } else {
                // Right
                nodes[parentIndex] = keccak256(
                    abi.encodePacked(nodes[index - 1], nodes[index])
                );
            }

            index = parentIndex;
        }

        return nodes[0];
    }
}
