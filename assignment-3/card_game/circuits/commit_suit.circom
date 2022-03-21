pragma circom 2.0.0;

include "../../../circomlib/circuits/mimcsponge.circom";
include "../../triangle_jump/circuits/range_proof.circom";
include "./merkletree.circom";

template CommitCardSuit(nCards) {
    signal input cards[nCards];
    signal output root;

    component cardNumberRangeProofs[nCards];
    component merkleroot = MerkleRoot(nCards);
    for (var i = 0; i < nCards; i++) {
        cardNumberRangeProofs[i] = RangeProof(32, 52);
        cardNumberRangeProofs[i].in <== cards[i];
        
        merkleroot.leaves[i] <== cards[i];
    }

    root <== merkleroot.root;
}

// To simplify demo and circuit size, limit suit to 4
component main = CommitCardSuit(4);
