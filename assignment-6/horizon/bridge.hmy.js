const rlp = require('rlp');
const headerData = require('./headers.json');
const transactions = require('./transaction.json');
const { rpcWrapper, getReceiptProof } = require('../scripts/utils');

const { expect } = require('chai');

let MMRVerifier, HarmonyProver;
let prover, mmrVerifier;

function hexToBytes(hex) {
    for (var bytes = [], c = 0; c < hex.length; c += 2)
        bytes.push(parseInt(hex.substr(c, 2), 16));
    return bytes;
}

describe('HarmonyProver', function () {
    beforeEach(async function () {
        // Deploy mmr libarary
        MMRVerifier = await ethers.getContractFactory("MMRVerifier");
        mmrVerifier = await MMRVerifier.deploy();
        await mmrVerifier.deployed();

        // await HarmonyProver.link('MMRVerifier', mmrVerifier);
        // Deploy harmony prover library, link to mmr verifier
        HarmonyProver = await ethers.getContractFactory(
            "HarmonyProver",
            {
                libraries: {
                    MMRVerifier: mmrVerifier.address
                }
            }
        );
        prover = await HarmonyProver.deploy();
        await prover.deployed();
    });

    it('parse rlp block header', async function () {
        // Test prover rlp header decode functionality
        let header = await prover.toBlockHeader(hexToBytes(headerData.rlpheader));
        expect(header.hash).to.equal(headerData.hash);
    });

    it('parse transaction receipt proof', async function () {
        let callback = getReceiptProof;
        let callbackArgs = [
            process.env.LOCALNET,
            prover,
            transactions.hash
        ];
        let isTxn = true;
        // Get cross-chain transaction receipt proof from local full node
        let txProof = await rpcWrapper(
            transactions.hash,
            isTxn,
            callback,
            callbackArgs
        );
        console.log(txProof);
        expect(txProof.header.hash).to.equal(transactions.header);

        // let response = await prover.getBlockRlpData(txProof.header);
        // console.log(response);

        // let res = await test.bar([123, "abc", "0xD6dDd996B2d5B7DB22306654FD548bA2A58693AC"]);
        // // console.log(res);
    });
});

let TokenLockerOnEthereum, tokenLocker;
let HarmonyLightClient, lightclient;

describe('TokenLocker', function () {
    beforeEach(async function () {
        // Deploy token locker contract on ethereum
        TokenLockerOnEthereum = await ethers.getContractFactory("TokenLockerOnEthereum");
        // Deploy MMRVerifier.deploy
        tokenLocker = await MMRVerifier.deploy();
        await tokenLocker.deployed();

        // Bind token locker address as otherSideBridge address
        await tokenLocker.bind(tokenLocker.address);

        // // await HarmonyProver.link('MMRVerifier', mmrVerifier);
        // HarmonyProver = await ethers.getContractFactory(
        //     "HarmonyProver",
        //     {
        //         libraries: {
        //             MMRVerifier: mmrVerifier.address
        //         }
        //     }
        // );
        // prover = await HarmonyProver.deploy();
        // await prover.deployed();

        
    });

    it('issue map token test', async function () {
        
    });

    it('lock test', async function () {
        
    });

    it('unlock test', async function () {
        
    });

    it('light client upgrade test', async function () {
        
    });
});
