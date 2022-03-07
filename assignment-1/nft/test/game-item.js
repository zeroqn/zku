const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("GameItem", function () {
  it("Should return the new awarded item uri", async function () {
    const GameItem = await ethers.getContractFactory("GameItem");
    const gameItem = await GameItem.deploy();
    await gameItem.deployed();

    const players = await ethers.getSigners();
    const awardItemTx = await gameItem.awardItem(players[0].address);
    await awardItemTx.wait();
    
    expect(await gameItem.ownerOf(1)).to.equal(players[0].address);
    
    const tokenURI = await gameItem.tokenURI(1);
    const [contentType, contentBase64String] = tokenURI.split(",");
    expect(contentType).to.equal("data:application/json;base64");
    
    const dataURIString = new TextDecoder().decode(ethers.utils.base64.decode(contentBase64String));
    const dataURI = JSON.parse(dataURIString);
    expect(dataURI.name).to.equal("GameItem #1");
    expect(dataURI.description).to.equal("demo game item nft");
  });
});
