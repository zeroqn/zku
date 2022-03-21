pragma circom 2.0.0;

include "./card.circom";
include "./merkletree.circom";

template CalculateNextCard() {
    signal input root;
    signal input cardNumber;
    signal input indices[2];
    signal input pathElements[2];
    signal input playerIndice;
    signal input cardTreeIndice;
    signal input cardTrapdoor;

    signal output commitment;
    signal output nullifier;

    // Verify merkle proof
    component merkleproof = VerifyMerkleProof(2);
    merkleproof.root <== root;
    merkleproof.leaf <== cardNumber;
    for (var i = 0; i < 2; i++) {
        merkleproof.indices[i] <== indices[i];
        merkleproof.pathElements[i] <== pathElements[i];
    }

    component calculateCardNullifier = CalculateCardNullifier();
    calculateCardNullifier.cardNumber <== cardNumber;
    calculateCardNullifier.playerIndice <== playerIndice;
    calculateCardNullifier.cardTreeIndice <== cardTreeIndice;

    component calculateCardCommitment = CalculateCardCommitment();
    calculateCardCommitment.root <== root;
    calculateCardCommitment.cardNumber <== cardNumber;
    calculateCardCommitment.playerIndice <== playerIndice;
    calculateCardCommitment.cardTreeIndice <== cardTreeIndice;
    calculateCardCommitment.cardTrapdoor <== cardTrapdoor;

    nullifier <== calculateCardNullifier.nullifier;
    commitment <== calculateCardCommitment.commitment;
}

component main {public [root, playerIndice]} = CalculateNextCard();
