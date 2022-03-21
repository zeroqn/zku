pragma circom 2.0.0;

include "../../../circomlib/circuits/mimcsponge.circom";

template MerkleRoot(nLeaves) {
    var leafOffset = nLeaves -1 ;

    signal input leaves[nLeaves];
    signal output nodes[nLeaves * 2 - 1];

    component hashers[nLeaves * 2 - 1];

    // Calculate leaves
    for (var i = 0; i < nLeaves; i++) {
        hashers[i + leafOffset] = MiMCSponge(1, 220, 1);
        hashers[i + leafOffset].ins[0] <== leaves[i];
        hashers[i + leafOffset].k <== 0;
        nodes[i + leafOffset] <== hashers[i + leafOffset].outs[0];
    }

    // Calculate branches + root
    for (var i = leafOffset - 1; i >= 0; i--) {
        hashers[i] = MiMCSponge(2, 220, 1);
        hashers[i].ins[0] <== hashers[i * 2 + 1].outs[0];
        hashers[i].ins[1] <== hashers[i * 2 + 2].outs[0];
        hashers[i].k <== 0;
        nodes[i] <== hashers[i].outs[0];
    }
}

component main {public [leaves]} = MerkleRoot(4);
