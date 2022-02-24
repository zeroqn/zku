//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract HelloWorld {
    uint256 private number;

    function store(uint256 number_) public {
        console.log("Store number %s", number_);
        number = number_;
    }

    function retrieve() public view returns (uint256) {
        console.log("Retrieve number %s", number);
        return number;
    }
}
