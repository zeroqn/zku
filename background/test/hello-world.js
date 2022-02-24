const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("HelloWorld", function () {
  it("Should able to store and retrieve number", async function () {
    const HelloWorld = await ethers.getContractFactory("HelloWorld");
    const helloWorld = await HelloWorld.deploy();
    await helloWorld.deployed();

    expect(await helloWorld.retrieve()).to.equal(0);

    const storeNumberTx = await helloWorld.store(100);

    // wait until the transaction is mined
    await storeNumberTx.wait();

    expect(await helloWorld.retrieve()).to.equal(100);
  });
});
