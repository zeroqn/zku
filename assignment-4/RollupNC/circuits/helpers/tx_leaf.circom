include "../../circomlib/circuits/mimc.circom";

// Calculate tx hash (sender address(pubkey), sender index(leaf index), to address(pubkey), sender nonce, amount , token type)
template TxLeaf() {

    signal input fromX;
    signal input fromY;
    signal input fromIndex;
    signal input toX;
    signal input toY;
    signal input nonce;
    signal input amount;
    signal input tokenType;

    signal output out;

    component txLeaf = MultiMiMC7(8,91);
    txLeaf.in[0] <== fromX;
    txLeaf.in[1] <== fromY;
    txLeaf.in[2] <== fromIndex;
    txLeaf.in[3] <== toX;
    txLeaf.in[4] <== toY; 
    txLeaf.in[5] <== nonce;
    txLeaf.in[6] <== amount;
    txLeaf.in[7] <== tokenType;

    out <== txLeaf.out;
}
