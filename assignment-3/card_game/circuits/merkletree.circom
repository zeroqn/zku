pragma circom 2.0.0;

include "../../../circomlib/circuits/mimcsponge.circom";

template MerkleRoot(nLeaves) {
    var leafOffset = nLeaves -1 ;

    signal input leaves[nLeaves];
    signal output root;

    component hashers[nLeaves * 2 - 1];

    // Calculate leaves
    for (var i = 0; i < nLeaves; i++) {
        hashers[i + leafOffset] = MiMCSponge(1, 220, 1);
        hashers[i + leafOffset].ins[0] <== leaves[i];
        hashers[i + leafOffset].k <== 0;
    }

    // Calculate branches + root
    for (var i = leafOffset - 1; i >= 0; i--) {
        hashers[i] = MiMCSponge(2, 220, 1);
        hashers[i].ins[0] <== hashers[i * 2 + 1].outs[0];
        hashers[i].ins[1] <== hashers[i * 2 + 2].outs[0];
        hashers[i].k <== 0;
    }

    root <== hashers[0].outs[0];
}

// if s == 0 returns [in[0], in[1]]
// if s == 1 returns [in[1], in[0]]
template Mux2() {
    signal input ins[2];
    signal input s;
    signal output outs[2];

    s * (1 - s) === 0;
    outs[0] <== (ins[1] - ins[0])*s + ins[0];
    outs[1] <== (ins[0] - ins[1])*s + ins[1];
}

template VerifyMerkleProof(nLevel) {
    signal input root;
    signal input leaf;
    signal input indices[nLevel];
    signal input pathElements[nLevel];

    component hashers[nLevel + 1];
    component selectors[nLevel + 1];

    // Hash leaf
    hashers[0] = MiMCSponge(1, 220, 1);
    hashers[0].ins[0] <== leaf;
    hashers[0].k <== 0;

    // Hash branches
    for (var i = 0; i < nLevel; i++) {
        hashers[i + 1] = MiMCSponge(2, 220, 1);
        selectors[i + 1] = Mux2();

        selectors[i + 1].ins[0] <== hashers[i].outs[0];
        selectors[i + 1].ins[1] <== pathElements[i];
        selectors[i + 1].s <== indices[i];

        hashers[i + 1].ins[0] <== selectors[i + 1].outs[0];
        hashers[i + 1].ins[1] <== selectors[i + 1].outs[1];
        hashers[i + 1].k <== 0;
    }

    root === hashers[nLevel].outs[0];
}
