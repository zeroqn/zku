pragma circom 2.0.0;

include "../circomlib/circuits/mimcsponge.circom";

template MerkleRoot4() {
    signal input leaves[4];
    signal output root;

    // Intemediate signals
    signal leafNodes[4];
    signal branchNodes[2];
    component leafNodeHashs[4];
    component branchNodeHashs[2];

    // Calculate leaf hashes
    for (var i = 0; i < 4; i++) {
        leafNodeHashs[i] = MiMCSponge(1, 220, 1);

        leafNodeHashs[i].ins[0] <== leaves[i];
        leafNodeHashs[i].k <== 0;
        leafNodes[i] <== leafNodeHashs[i].outs[0];
    }

    // Calculate branch hashes
    for (var i = 0; i < 2; i++) {
        branchNodeHashs[i] = MiMCSponge(2, 220, 1);

        branchNodeHashs[i].ins[0] <== leafNodes[i * 2];
        branchNodeHashs[i].ins[1] <== leafNodes[i * 2 + 1];
        branchNodeHashs[i].k <== 0;
        branchNodes[i] <== branchNodeHashs[i].outs[0];
    }

    // Calculate root
    component hash = MiMCSponge(2, 220, 1);
    
    hash.ins[0] <== branchNodes[0];
    hash.ins[1] <== branchNodes[1];
    hash.k <== 0;
    root <== hash.outs[0];
}

component main {public [leaves]} = MerkleRoot4();
