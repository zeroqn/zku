pragma circom 2.0.0;

include "../../../circomlib/circuits/mimcsponge.circom";
include "../../../circomlib/circuits/sha256/sha256.circom";
include "../../../circomlib/circuits/bitify.circom";

template CalculateCardNullifier() {
    signal input cardNumber;
    signal input playerIndice;
    signal input cardTreeIndice;

    signal output nullifier;

    component hasher = MiMCSponge(3, 220, 1);
    hasher.ins[0] <== cardNumber;
    hasher.ins[1] <== playerIndice;
    hasher.ins[2] <== cardTreeIndice;
    hasher.k <== 0;
    
    nullifier <== hasher.outs[0];
}

template CalculateCardCommitment() {
    signal input root;
    signal input cardNumber;
    signal input playerIndice;
    signal input cardTreeIndice;
    signal input cardTrapdoor;

    signal output commitment;

    component hasher = Sha256(256 + 32 + 32 + 32 + 256);
    component bitsRoot = Num2Bits_strict();
    component bitsCardNumber = Num2Bits(32);
    component bitsPlayerIndice = Num2Bits(32);
    component bitsCardTreeIndice = Num2Bits(32);
    component bitsCardTrapdoor = Num2Bits_strict();

    bitsRoot.in <== root;
    bitsCardNumber.in <== cardNumber;
    bitsPlayerIndice.in <== playerIndice;
    bitsCardTreeIndice.in <== cardTreeIndice;
    bitsCardTrapdoor.in <== cardTrapdoor;

    var index = 0;

    // Padding to 256bits with zero
    hasher.in[index] <== 0;
    index++;
    hasher.in[index] <== 0;
    index++;
    for(var i = 0; i < 254; i++) {
        hasher.in[index] <== bitsRoot.out[253 - i];
        index++;
    }
    for(var i = 0; i < 32; i++) {
        hasher.in[index] <== bitsCardNumber.out[31 - i];
        index++;
    }
    for(var i = 0; i < 32; i++) {
        hasher.in[index] <== bitsPlayerIndice.out[31 - i];
        index++;
    }
    for(var i = 0; i < 32; i++) {
        hasher.in[index] <== bitsCardTreeIndice.out[31 - i];
        index++;
    }
    hasher.in[index] <== 0;
    index++;
    hasher.in[index] <== 0;
    index++;
    for(var i = 0; i < 254; i++) {
        hasher.in[index] <== bitsCardTrapdoor.out[253 - i];
        index++;
    }

    component b2n = Bits2Num(256);
    for (var i = 0; i < 256; i++) {
        b2n.in[i] <== hasher.out[255 - i];
    }
    commitment <== b2n.out;
}

/* component main {public [root, cardNumber, playerIndice, cardTreeIndice, cardTrapdoor]} = CalculateCardCommitment(); */
