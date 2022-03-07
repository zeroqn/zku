const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("SimpleMerkleTree", function () {
  it.skip("Should able to update merkle root", async function () {
    const SimpleMerkleTree = await ethers.getContractFactory(
      "SimpleMerkleTree4"
    );
    const merkleTree = await SimpleMerkleTree.deploy();
    await merkleTree.deployed();

    const zeroRoot = await merkleTree.root();
    expect(zeroRoot).to.equal(
      "0x890740a8eb06ce9be422cb8da5cdafc2b58c0a5e24036c578de2a433c828ff7d"
    );

    // Try default value
    const abiCoder = new ethers.utils.AbiCoder();
    const leaf = abiCoder.encode(["uint256"], [0]);
    expect(await merkleTree.zeroHash()).to.equal(ethers.utils.keccak256(leaf));

    for (let i = 0; i < 4; i++) {
      const updateLeafTx = await merkleTree.update(leaf, i);
      await updateLeafTx.wait();
      expect(await merkleTree.root()).to.equal(zeroRoot);
    }

    const zeroHash = await merkleTree.zeroHash();
    expect(await merkleTree.getLeaves()).to.eql([zeroHash, zeroHash, zeroHash, zeroHash]);

    const leafOne = abiCoder.encode(["uint256"], [1]);
    const updateLeafTx = await merkleTree.update(leafOne, 1);
    await updateLeafTx.wait();
    expect(await merkleTree.root()).to.equal(
      "0x6f21267e2924835775d03cf48818214cc95760e04b05cfe0320a33f5a5883d59"
    );
  });
});
