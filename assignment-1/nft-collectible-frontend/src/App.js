import { useEffect, useState } from "react";
import { ethers } from "ethers";
import "./App.css";
import contract from "./contracts/GameItem.json";

// contract address on localhost ganache
const contractAddress = "0x6b706659301dcc98dcc62e577756b1f5b22b710c";
const snarkjs = require("snarkjs");
const abi = contract.abi;

function App() {
  const [currentAccount, setCurrentAccount] = useState(null);

  const wasmFile = "http://localhost:3000/merkleroot.wasm";
  const zkeyFile = "http://localhost:3000/merkleroot_0001.zkey";
  const verificationKey =
    "http://localhost:3000/merkleroot_verification_key.json";

  const checkWalletIsConnected = () => {
    const { ethereum } = window;

    if (!ethereum) {
      console.log("Make sure you have Metamask installed!");
      return;
    } else {
      console.log("Wallet exists! We're ready to go!");
    }
  };

  const connectWalletHandler = async () => {
    const { ethereum } = window;
    if (!ethereum) {
      alert("Please install Metamask!");
    }

    try {
      const accounts = await ethereum.request({
        method: "eth_requestAccounts",
      });
      console.log("found an account! Address: ", accounts[0]);
      setCurrentAccount(accounts[0]);
    } catch (err) {
      console.log(err);
    }
  };

  const mintNftHandler = async () => {
    try {
      const { ethereum } = window;

      if (ethereum) {
        const provider = new ethers.providers.Web3Provider(ethereum);
        const signer = provider.getSigner();
        const nftContract = new ethers.Contract(contractAddress, abi, signer);

        console.log("Initialize payment");
        let nftTxn = await nftContract.awardItem(await signer.getAddress());

        console.log("Mining... please wait");
        await nftTxn.wait();

        console.log(`Mined, see transaction: ${nftTxn.hash}`);
      } else {
        console.log("Ethereum object does not exist");
      }
    } catch (err) {
      console.log(err);
    }
  };

  const merkleProofHandler = async () => {
    const { ethereum } = window;
    if (!ethereum) {
      console.log("Ethereum object does not exist");
      return;
    }

    try {
      const provider = new ethers.providers.Web3Provider(ethereum);
      const signer = provider.getSigner();
      const nftContract = new ethers.Contract(contractAddress, abi, signer);

      const leaves = await nftContract.merkleLeaves();
      console.log(`Merkle leaves ${leaves}`);

      const { proof, publicSignals } = await snarkjs.groth16.fullProve(
        leaves,
        wasmFile,
        zkeyFile
      );
      const vkey = await fetch(verificationKey).then(function (res) {
        return res.json();
      });

      const res = await snarkjs.groth16.verify(vkey, publicSignals, proof);
      console.log(`verify result ${res}`);
    } catch (err) {
      console.log(err);
    }
  };

  const connectWalletButton = () => {
    return (
      <button
        onClick={connectWalletHandler}
        className="cta-button connect-wallet-button"
      >
        Connect Wallet
      </button>
    );
  };

  const mintNftButton = () => {
    return (
      <button onClick={mintNftHandler} className="cta-button mint-nft-button">
        Mint NFT
      </button>
    );
  };

  const merkleProofButton = () => {
    return (
      <button
        onClick={merkleProofHandler}
        className="cta-button merkle-proof-button"
      >
        Merkle Proof
      </button>
    );
  };

  useEffect(() => {
    checkWalletIsConnected();
  }, []);

  return (
    <div className="main-app">
      <h1>Demo Game Item Tutorial</h1>
      <div>{currentAccount ? mintNftButton() : connectWalletButton()}</div>
      <div>{currentAccount ? merkleProofButton() : ""}</div>
    </div>
  );
}

export default App;
