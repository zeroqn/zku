pragma circom 2.0.0;

include "./move.circom";

template TriangleJump() {
    signal input jumpLocs[3][2]; // a(x,y), b(x,y), c(x,y)
    signal input worldRadius;
    signal input energy;

    signal output jumpLocHashes[3];

    component moves[2];
    for (var i = 0; i < 2; i++) {
        moves[i] = Move();
        moves[i].x1 <== jumpLocs[i][0];
        moves[i].y1 <== jumpLocs[i][1];
        moves[i].x2 <== jumpLocs[i+1][0];
        moves[i].y2 <== jumpLocs[i+1][1];
        moves[i].r <== worldRadius;
        moves[i].distMax <== energy;
    }

    moves[0].pub2 === moves[1].pub1;

    jumpLocHashes[0] <== moves[0].pub1;
    jumpLocHashes[1] <== moves[0].pub2;
    jumpLocHashes[2] <== moves[1].pub2;
}

component main {public [worldRadius, energy]} = TriangleJump();
