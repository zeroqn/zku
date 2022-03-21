const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("CardGame", function () {
  it("should a player, commit card suit, comit next card and reveal next card", async function () {
    const CardGame = await ethers.getContractFactory("CardGame");
    const cardGame = await CardGame.deploy();
    await cardGame.deployed();

    // Copy from ../circuit/commit_suit_calldata.json
    const calldata = [
      [
        "0x0780e060b314488a80f2e9ff239ad4db2c076b6d2c211eae7c6215570428b677",
        "0x10f434739140001a21014f2730de0092eb112c3ca0acb1f39239a9fc20684075",
      ],
      [
        [
          "0x1359bd239869680e627a15c039f462ad7158fbc53b3957f1e528cf8870d44086",
          "0x090d9d3b271a72bcf7723b2e6c553472c15ebd0ed6c19aec70ab30c7aa354ca1",
        ],
        [
          "0x10faa9de121dc549b00a4194aa77f28ffd316eb711fc012c7611cb7efd089956",
          "0x00bd9206dd14d2477499d362f0fdc76ce72f80a97f7fba5d9bf944bd6a02c6f5",
        ],
      ],
      [
        "0x2bea4c9ee97a636760bc544dd52d525a4e432c6d192cac47d6fc0b10046c92b7",
        "0x0b00d70f2a1af42f0f93a64292234a03294e0968ecb5cb67c43cc887ab6fb58a",
      ],
      ["0x2a8c7364b5b848cf41a7fe8d6e8b6322e45fd1466556c7d98e0f2fabcf7784a5"],
    ];
    const addPlayerTx = await cardGame.addPlayer(
      calldata[0],
      calldata[1],
      calldata[2],
      calldata[3]
    );
    await addPlayerTx.wait();

    // Copy from ../circuit/next_card_calldata.json
    const nextCardCallData = [
      [
        "0x0076ddeb4bc45ffc735b3c876362ad2c7515eccd922f2070c7bf8dcf7e9c87b9",
        "0x194efe2877ae65fc16a9261441ad52067f74e4062011851d258e3d76d3baf1da",
      ],
      [
        [
          "0x20602602288513752506fe955ad2027a62a5943d50aab165dbbebafbad4249d1",
          "0x1e13874905fc15216e7cf41ed25b96293501dd7da9eeb3386cd770dcad06cf39",
        ],
        [
          "0x171cf9aad716069c8ee6a0fdcdf3a757ea449e2183c0d995a40941cb53c83b9b",
          "0x1d344f0abbcc436b1b53718c5fbc78bc4c3445de3cfa4672ca0cbca70bce53af",
        ],
      ],
      [
        "0x13fcf90d03cc7d5ca63eea8562da46916a2ca97f09a2b7f06d99a152c5729a75",
        "0x1b06b3754b7408046b8946008e6f875c38a3dce9cb296145e51f2905b217cb09",
      ],
      [
        "0x095ed1c5da94f43adee3313d7d265105c594eaee9df4630f4ad09e2c2a721ce3",
        "0x2ce0e98efd349bc23f09753d17809c52ab11ceefefb48fe464ee87f4d9cfa0c6",
        "0x2a8c7364b5b848cf41a7fe8d6e8b6322e45fd1466556c7d98e0f2fabcf7784a5",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        "0x095ed1c5da94f43adee3313d7d265105c594eaee9df4630f4ad09e2c2a721ce3",
        "0x2ce0e98efd349bc23f09753d17809c52ab11ceefefb48fe464ee87f4d9cfa0c6",
      ],
    ];
    const setNextCardTx = await cardGame.setNextCard(
      nextCardCallData[0],
      nextCardCallData[1],
      nextCardCallData[2],
      nextCardCallData[3]
    );
    await setNextCardTx.wait();

    const revealCardTx = await cardGame.revealCard(
      "19245294645528044749875569008416193983007247604813466378283191623600286696613", // Root
      1, // CardNumber
      0, // playerIndice
      0, // cardTreeIndice
      1 // cardTrapdoor
    );
    await revealCardTx.wait();
  });
});
