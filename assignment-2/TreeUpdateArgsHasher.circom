include "../node_modules/circomlib/circuits/bitify.circom";
include "../node_modules/circomlib/circuits/sha256/sha256.circom";

// Computes a SHA256 hash of all inputs packed into a byte array
// Field elements are padded to 256 bits with zeroes
template TreeUpdateArgsHasher(nLeaves) {
    // Old withdrawal tree root (aka _currentRoot in contract)
    signal input oldRoot;
    
    // New withdrawal tree root
    signal input newRoot;

    // Inserted batched withdrawals leaf indice
    signal input pathIndices;

    // Batched withdrawal address array
    signal input instances[nLeaves];

    // Batched withdrawal nullifier hash array
    signal input hashes[nLeaves];

    // Batched withdrawal block number array
    signal input blocks[nLeaves];

    // Output is hash of leaf data
    signal output out;

    // 256 (current root) + 256 (new root) + u32 (pathIndices)
    var header = 256 + 256 + 32;

    // 256 (nullifier hash) + 160 (withdraw address) + u32 (block number)
    var bitsPerLeaf = 256 + 160 + 32;

    // Leaf data size is header + nLeaves * bitsPerLeaf
    component hasher = Sha256(header + nLeaves * bitsPerLeaf);

    // the range check on old root is optional, it's enforced by smart contract anyway
    // Convert to bit represent to sha256
    component bitsOldRoot = Num2Bits_strict();
    component bitsNewRoot = Num2Bits_strict();
    component bitsPathIndices = Num2Bits(32);
    component bitsInstance[nLeaves];
    component bitsHash[nLeaves];
    component bitsBlock[nLeaves];

    bitsOldRoot.in <== oldRoot;
    bitsNewRoot.in <== newRoot;
    bitsPathIndices.in <== pathIndices;

    var index = 0;

    // Hash header
    // As comment above, field elements are padded to 256 bits with zeroes
    hasher.in[index++] <== 0;
    hasher.in[index++] <== 0;
    for(var i = 0; i < 254; i++) {
        // Reverse insert bits
        hasher.in[index++] <== bitsOldRoot.out[253 - i];
    }
    hasher.in[index++] <== 0;
    hasher.in[index++] <== 0;
    for(var i = 0; i < 254; i++) {
        // Same as old root
        hasher.in[index++] <== bitsNewRoot.out[253 - i];
    }
    for(var i = 0; i < 32; i++) {
        hasher.in[index++] <== bitsPathIndices.out[31 - i];
    }

    // Hash 256 withdraw data
    for(var leaf = 0; leaf < nLeaves; leaf++) {
        // the range check on hash is optional, it's enforced by the smart contract anyway
        bitsHash[leaf] = Num2Bits_strict();
        bitsInstance[leaf] = Num2Bits(160);
        bitsBlock[leaf] = Num2Bits(32);
        bitsHash[leaf].in <== hashes[leaf];
        bitsInstance[leaf].in <== instances[leaf];
        bitsBlock[leaf].in <== blocks[leaf];
        hasher.in[index++] <== 0;
        hasher.in[index++] <== 0;
        for(var i = 0; i < 254; i++) {
            // padded with zeroes to 256 bits
            hasher.in[index++] <== bitsHash[leaf].out[253 - i];
        }
        for(var i = 0; i < 160; i++) {
            hasher.in[index++] <== bitsInstance[leaf].out[159 - i];
        }
        for(var i = 0; i < 32; i++) {
            hasher.in[index++] <== bitsBlock[leaf].out[31 - i];
        }
    }
    
    // Convert hash bits to number, just like uint256(sha256(data)) does in contract
    component b2n = Bits2Num(256);
    for (var i = 0; i < 256; i++) {
        b2n.in[i] <== hasher.out[255 - i];
    }
    out <== b2n.out;
}
