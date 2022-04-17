/**
 * Copyright 2021 Webb Technologies
 * SPDX-License-Identifier: GPL-3.0-or-later-only
 */

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "../tokens/GovernedTokenWrapper.sol"; 
import "./HandlerHelpers.sol";
import "../interfaces/IExecutor.sol";

/**
    @title Handles GovernedTokenWrapper fee and token updates
    @author Webb Technologies.
    @notice This contract is intended to be used with the Bridge and SignatureBridge contracts.
 */
contract TokenWrapperHandler is IExecutor, HandlerHelpers {
    struct UpdateRecord {
        address _tokenWrapperAddress;
        uint256  _executionChainID;
        uint256 _nonce;
        bytes4 functionSig;
        bytes32 _resourceID;
        bytes32 _updateValue;
    }

    // executionChainID => nonce => Update Record
    mapping (uint256 => mapping(uint256 => UpdateRecord)) public _updateRecords;

    // executionChainID => number of updates
    mapping(uint256 => uint) public _counts;

    /**
        @param bridgeAddress Contract address of previously deployed Bridge.
        @param initialResourceIDs Resource IDs are used to identify a specific contract address.
        These are the Resource IDs this contract will initially support.
        @param initialContractAddresses These are the addresses the {initialResourceIDs} will point to, and are the contracts that will be
        called to perform various deposit calls.
        @dev {initialResourceIDs} and {initialContractAddresses} must have the same length (one resourceID for every address).
        Also, these arrays must be ordered in the way that {initialResourceIDs}[0] is the intended resourceID for {initialContractAddresses}[0].
     */
    constructor(
        address          bridgeAddress,
        bytes32[] memory initialResourceIDs,
        address[] memory initialContractAddresses
    ) {
        require(initialResourceIDs.length == initialContractAddresses.length,
            "initialResourceIDs and initialContractAddresses len mismatch");

        _bridgeAddress = bridgeAddress;

        for (uint256 i = 0; i < initialResourceIDs.length; i++) {
            _setResource(initialResourceIDs[i], initialContractAddresses[i]);
        }
    }

    /**
        @param updateNonce This ID will have been generated by the Bridge contract.
        @param executionChainId ID of chain where execution of proposal occurs.
        @return UpdateRecord which consists of:
        - address _tokenWrapperAddress;
        - uint256  _executionChainID;
        - uint256 _nonce;
        - bytes4 functionSig;
        - bytes32 _resourceID;
        - bytes32 _updateValue;
    */
    function getUpdateRecord(uint updateNonce, uint256 executionChainId) external view returns (UpdateRecord memory) {
        return _updateRecords[executionChainId][updateNonce];
    }

    /**
        @notice Proposal execution should be initiated when a proposal is finalized in the Bridge contract.
        by a relayer on the deposit's destination chain. Or when a valid signature is produced by the DKG in the case of SignatureBridge.
        @param resourceID ResourceID corresponding to a particular set of GovernedTokenWrapper contracts
        @param data Consists of {executionChainID}, {nonce}, {functionSig} {updateValue} all padded to 32 bytes.
        @notice Data passed into the function should be constructed as follows:
        executionChainID                                  uint256     bytes  0 - 32
        nonce                                             uint256     bytes  32 - 64
        functionSig                                       bytes32     bytes  64 - 96
        updateValue                                       bytes32     bytes  96 - 128  
     */
    function executeProposal(bytes32 resourceID, bytes calldata data) external override onlyBridge {
        bytes32         resourceId;
        bytes4          functionSig;
        bytes  calldata arguments;
    
        resourceId = bytes32(data[0:32]);
        functionSig = bytes4(data[32:36]);
        arguments = data[36:];
    
        address governedTokenAddress = _resourceIDToContractAddress[resourceID];
        GovernedTokenWrapper governedToken = GovernedTokenWrapper(governedTokenAddress); 
 

        if (functionSig == bytes4(keccak256("setFee(uint8,uint256)"))) {  
            uint32 nonce = uint32(bytes4(arguments[0:4])); 
            uint8 newFee = uint8(bytes1(arguments[4:5]));
            governedToken.setFee(newFee, nonce);
        } else if (functionSig == bytes4(keccak256("add(address,uint256)"))) {
            uint32 nonce = uint32(bytes4(arguments[0:4]));
            address tokenAddress = address(bytes20(arguments[4:24]));
            governedToken.add(tokenAddress, nonce);
        } else if (functionSig == bytes4(keccak256("remove(address,uint256)"))) {
            uint32 nonce = uint32(bytes4(arguments[0:4]));
            address tokenAddress = address(bytes20(arguments[4:24]));
            governedToken.remove(tokenAddress, nonce);
        } else if (functionSig == bytes4(keccak256("setFeeRecipient(address,uint256)"))) {
            uint32 nonce = uint32(bytes4(arguments[0:4]));
            address payable feeRecipient = payable(address(bytes20(arguments[4:24])));
            governedToken.setFeeRecipient(feeRecipient, nonce);
        } else {
            revert("Invalid function sig");
        }
    }
}