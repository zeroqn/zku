pragma circom 2.0.0;

include "../node_modules/circomlib/circuits/poseidon.circom";
include "./tree.circom";

template CalculateSecret() {
    // User picked random secret value to compute nullifier(hash) and identity commitment(hash)
    signal input identityNullifier;

    // User picked random secret value to compute identity commitment(hash)
    signal input identityTrapdoor;

    // Hash of identity nullifier and identity trapdoor
    signal output out;

    // Poseidon hash circuit
    component poseidon = Poseidon(2);

    poseidon.inputs[0] <== identityNullifier;
    poseidon.inputs[1] <== identityTrapdoor;

    out <== poseidon.out;
}

template CalculateIdentityCommitment() {
    // Hash of (identity nullifier, identity trapdoor)
    signal input secret;

    signal output out;

    component poseidon = Poseidon(1);

    poseidon.inputs[0] <== secret;

    out <== poseidon.out;
}

template CalculateNullifierHash() {
    // External nullifier, for example, dapp contract address use semaphore
    // Used to prevent double signal
    signal input externalNullifier;

    // Secret identity nullifier above
    signal input identityNullifier;

    signal output out;

    component poseidon = Poseidon(2);

    poseidon.inputs[0] <== externalNullifier;
    poseidon.inputs[1] <== identityNullifier;

    out <== poseidon.out;
}

// nLevels must be < 32.
// nLevels means depth of merkle tree
template Semaphore(nLevels) {
    // User secret identity nullifier
    signal input identityNullifier;

    // User secret identity trapdoor
    signal input identityTrapdoor;

    // Path from leaf to root. For example, we have 4 leafs, 2 levels. Path indices for 0 is [0, 0].
    signal input treePathIndices[nLevels];

    // Siblings from leaf to root. For example, 2 levels. siblings for 0 is [H(1), H(2, 3)].
    signal input treeSiblings[nLevels];

    // Hash of boradcasted signal
    signal input signalHash;

    // External nullifier
    signal input externalNullifier;

    // Identity merkle tree root
    signal output root;

    // Hash of (external nullifier, identity nullifier), prevent double signal
    signal output nullifierHash;

    // Calculate identity secret Hash(identity nullifier, identity trapdoor)
    component calculateSecret = CalculateSecret();
    calculateSecret.identityNullifier <== identityNullifier;
    calculateSecret.identityTrapdoor <== identityTrapdoor;

    signal secret;
    secret <== calculateSecret.out;

    // Calculate identity commitment
    component calculateIdentityCommitment = CalculateIdentityCommitment();
    calculateIdentityCommitment.secret <== secret;

    // Calculate nullifier hash
    component calculateNullifierHash = CalculateNullifierHash();
    calculateNullifierHash.externalNullifier <== externalNullifier;
    calculateNullifierHash.identityNullifier <== identityNullifier;

    // Initialize MerkleTreeInclusionProof circuit for `nLevels` depth of merkle tree
    component inclusionProof = MerkleTreeInclusionProof(nLevels);

    // Identity commitment as leaf
    inclusionProof.leaf <== calculateIdentityCommitment.out;

    // Assign siblings and path indices
    for (var i = 0; i < nLevels; i++) {
        inclusionProof.siblings[i] <== treeSiblings[i];
        inclusionProof.pathIndices[i] <== treePathIndices[i];
    }

    // Output merkle root
    root <== inclusionProof.root;

    // Dummy square to prevent tampering signalHash.
    // Double to prevent optimizer from removing those constraints
    // Reference: https://discord.com/channels/942318442340560917/948655394769752074/952418691172163635
    signal signalHashSquared;
    signalHashSquared <== signalHash * signalHash;

    nullifierHash <== calculateNullifierHash.out;
}

// Public inputs are hash of broadcasted signal and external nullifier(for example, dapp contract address)
// Semaphore is initialized to 20 depth of merkle tree
component main {public [signalHash, externalNullifier]} = Semaphore(20);
