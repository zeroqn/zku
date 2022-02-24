const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Ballot", function () {
  it.only("Should give 10 voters the right to vote", async function () {
    const signers = await ethers.getSigners();
    // Which character to start elden ring?
    const proposals = (() => {
        let characters = ["Wretch", "Prophet", "Confessor", "Samurai", "Astrologer", "Bandit", "Prisoner", "Vagabound", "Warrior", "Hero"];
        characters = characters.map((character) => {
            return ethers.utils.formatBytes32String(character);
        });
        return characters
    })();

    const Ballot = await ethers.getContractFactory("Ballot");
    const ballot = await Ballot.deploy(proposals);
    await ballot.deployed();

    // First one is chairperson
    // Original version
    // for (let i = 1; i <= 10; i++) {
    //     const giveRightToVoteTx = await ballot.giveRightToVote(signers[i].address);
    //     await giveRightToVoteTx.wait();
    // }

    const voters = signers.slice(1, 11).map((signer) => signer.address);
    const giveRightToVotesTx = await ballot.giveRightToVotes(voters);
    await giveRightToVotesTx.wait();
  });
});
