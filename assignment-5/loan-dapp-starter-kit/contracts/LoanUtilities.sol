pragma solidity >= 0.5.0 <0.7.0;
import "@aztec/protocol/contracts/libs/NoteUtils.sol";
import "@aztec/protocol/contracts/ERC1724/ZkAssetMintable.sol";
import "@aztec/protocol/contracts/interfaces/IZkAsset.sol";
import "./ZKERC20/ZKERC20.sol";


library LoanUtilities {

  using SafeMath for uint256;
  using SafeMath for uint32;
  using NoteUtils for bytes;
  
  uint256 constant scalingFactor = 1000000000;
  uint24 constant DIVIDEND_PROOF= 66561;
  uint24 constant JOIN_SPLIT_PROOF = 65793;
  uint24 constant MINT_PRO0F = 66049;
  uint24 constant BILATERAL_SWAP_PROOF = 65794;
  uint24 constant PRIVATE_RANGE_PROOF = 66562;
 
  struct Note {
    address owner;
    bytes32 noteHash;
  }
  
  struct LoanVariables {
    uint256 interestRate;
    uint256 interestPeriod;
    uint256 duration;
    uint256 loanSettlementDate;
    uint256 lastInterestPaymentDate;
    bytes32 notional;
    bytes32 currentInterestBalance;
    address borrower;
    address lender;
    address loanFactory;
    address aceAddress;
    IZkAsset settlementToken;
    address id;
  }
  
  function _noteCoderToStruct(bytes memory note) internal pure returns (Note memory codedNote) {
      (address owner, bytes32 noteHash,) = note.extractNote();
      return Note(owner, noteHash );
  }

  function getRatio(bytes memory _proofData) internal pure returns (uint256 ratio) {
    uint256 za;
    uint256 zb;
    assembly {
      za := mload(add(_proofData, 0x40))
      zb := mload(add(_proofData, 0x60))
    }
    return za.mul(scalingFactor).div(zb);
  }
  

  function onlyLoanDapp(address sender, address loanFactory) external pure {
    require(sender == loanFactory, 'sender is not the loan dapp');
  }
  
  function onlyBorrower(address sender, address borrower) external pure {
    require(sender == borrower, 'sender is not the borrower');
  }
  
  function onlyLender(address sender, address lender) internal pure {
    // require(sender, 'sender is not the lender');
  }

  function _validateDefaultProofs(
    bytes calldata _proof1,
    bytes calldata _proof2,
    uint256 _interestDuration,
    LoanVariables storage _loanVariables
    ) external {


    // Dividend proof: notional * ratio == interest duration
    (,bytes memory _proof1OutputNotes) = _validateInterestProof(_proof1, _interestDuration, _loanVariables);
    
    // Private range proof: current interest balance < interest duration
    (bytes memory _proof2Outputs) = ACE(_loanVariables.aceAddress).validateProof(PRIVATE_RANGE_PROOF, address(this),_proof2);
    (bytes memory _proof2InputNotes, bytes memory _proof2OutputNotes, ,) = _proof2Outputs.get(0).extractProofOutput();

    require(_noteCoderToStruct(_proof2InputNotes.get(0)).noteHash == _noteCoderToStruct(_proof1OutputNotes.get(0)).noteHash, 'withdraw note in 2 is not the same as 1');

    require(_noteCoderToStruct(_proof2InputNotes.get(1)).noteHash == _loanVariables.currentInterestBalance, 'interest note in 2 is not correct');

  }

  
  function _validateInterestProof(
    bytes memory _proof1,
    uint256 _interestDuration,
    LoanVariables storage _loanVariables
  ) internal returns (
    bytes memory _proof1InputNotes, 
    bytes memory _proof1OutputNotes
  ) {
    //PROOF 1

    //NotionalNote * a = WithdrawableInterestNote * b
    require(getRatio(_proof1).div(10000) ==
            _loanVariables.interestPeriod.mul(scalingFactor) // Because erc20 is U256 but aztec only support 32bit
              .div(
                _loanVariables.interestRate
                .mul(_interestDuration)
                  )
           , 'ratios do not match');


    // Dividend proof: notional * ratio == interest amount
    (bytes memory _proof1Outputs) = ACE(_loanVariables.aceAddress).validateProof(DIVIDEND_PROOF, address(this), _proof1);
    (_proof1InputNotes, _proof1OutputNotes, ,) = _proof1Outputs.get(0).extractProofOutput();
    
    // First input must be notional note
    require(_noteCoderToStruct(_proof1InputNotes.get(0)).noteHash == _loanVariables.notional, 'incorrect notional note in proof 1');

  }

  function _processInterestWithdrawal(
    bytes calldata _proof2,
    bytes calldata _proof1OutputNotes,
    LoanVariables storage _loanVariables
  ) external returns (bytes32 newCurrentInterestBalance) {

    // Join split proof: interest balance note => interest withdrawal note + remain interest balance
    (bytes memory _proof2Outputs) = ACE(_loanVariables.aceAddress).validateProof(JOIN_SPLIT_PROOF, address(this), _proof2);
    (bytes memory _proof2InputNotes, bytes memory _proof2OutputNotes, ,) = _proof2Outputs.get(0).extractProofOutput();

    // Ensure withdraw output notes from two proofs are correct, _proof1OutputNotes are output for raito check.
    require(_noteCoderToStruct(_proof2OutputNotes.get(0)).noteHash ==
            _noteCoderToStruct(_proof1OutputNotes.get(0)).noteHash, 'withdraw note in 2 is not the same as 1');

    // First proof for input notes are interest balance note
    require(_noteCoderToStruct(_proof2InputNotes.get(0)).noteHash == _loanVariables.currentInterestBalance, 'interest note in 2 is not correct');

    // Approve to spend input interest balance note
    _loanVariables.settlementToken.confidentialApprove(_noteCoderToStruct(_proof2InputNotes.get(0)).noteHash, address(this), true, '');

    // Actually transfer outputs from ace
    _loanVariables.settlementToken.confidentialTransferFrom(JOIN_SPLIT_PROOF, _proof2Outputs.get(0));

    // Return remain interest balance note
    newCurrentInterestBalance = _noteCoderToStruct(_proof2OutputNotes.get(1)).noteHash;

  }

  function _processAdjustInterest(
    bytes calldata _proofData,
    LoanVariables storage _loanVariables
  ) external returns (bytes32 newCurrentInterestBalance) {

    // Join split proof: interest balance + [borrower unspend notes] => borrower change + new interest balance
    (bytes memory _proofOutputs) = ACE(_loanVariables.aceAddress).validateProof(JOIN_SPLIT_PROOF, address(this), _proofData);
    (bytes memory _proofInputNotes, bytes memory _proofOutputNotes, ,) = _proofOutputs.get(0).extractProofOutput();
    // First input must be interest balance
    require(_noteCoderToStruct(_proofInputNotes.get(0)).noteHash == _loanVariables.currentInterestBalance, 'interest note does not match input note');

    // Second output must be updated interest balance
    require(_noteCoderToStruct(_proofOutputNotes.get(1)).owner == address(this), 'output note not owned by contract');

    // Approve spend input interest balance note
    _loanVariables.settlementToken.confidentialApprove(_noteCoderToStruct(_proofInputNotes.get(0)).noteHash, address(this), true, '');

    // Transfer outputs from ace
    _loanVariables.settlementToken.confidentialTransferFrom(JOIN_SPLIT_PROOF, _proofOutputs.get(0));
    // Update interest balance
    newCurrentInterestBalance = _noteCoderToStruct(_proofOutputNotes.get(1)).noteHash;

  }

  function _processLoanSettlement(
    bytes calldata _proofData,
    LoanVariables storage _loanVariables
  ) external {
    // 65794 is Swap Proof, lender take borrower ask, swap borrower notional note and lender value note
    (bytes memory _proofOutputs) = ACE(_loanVariables.aceAddress).validateProof(65794, address(this), _proofData);
    (bytes memory _loanProofOutputs) = _proofOutputs.get(0);
    (bytes memory _settlementProofOutputs) = _proofOutputs.get(1);

    _loanVariables.settlementToken.confidentialTransferFrom(BILATERAL_SWAP_PROOF, _settlementProofOutputs);

    IZkAsset(_loanVariables.id).confidentialTransferFrom(BILATERAL_SWAP_PROOF, _loanProofOutputs);
  }

  function _processLoanRepayment(
    bytes calldata _proof2,
    bytes calldata _proof1OutputNotes,
    LoanVariables storage _loanVariables
  ) external {
      
    // Join split proof: notional note + remaining interest => lender outputs
    (bytes memory _proof2Outputs) = ACE(_loanVariables.aceAddress).validateProof(JOIN_SPLIT_PROOF, address(this), _proof2);
    (bytes memory _proof2InputNotes, bytes memory _proof2OutputNotes, ,) = _proof2Outputs.get(0).extractProofOutput();

    // require(_noteCoderToStruct(_proof2InputNotes.get(1)).noteHash ==
    //         _noteCoderToStruct(_proof1OutputNotes.get(0)).noteHash, 'withdraw note in 2 is not the same as  1');

    // require(_noteCoderToStruct(_proof2InputNotes.get(0)).noteHash == _loanVariables.notional, 'notional in 2 is not the same as 1');

    require(_noteCoderToStruct(_proof2OutputNotes.get(0)).owner == _loanVariables.lender, 'output note is not owned by the lender');
    require(_noteCoderToStruct(_proof2OutputNotes.get(1)).owner == _loanVariables.lender, 'output note is not owned by the lender');

    // Approve spend input notional
    _loanVariables.settlementToken.confidentialApprove(_noteCoderToStruct(_proof2InputNotes.get(0)).noteHash, address(this), true, '');
    // the first note is the current interest note

    _loanVariables.settlementToken.confidentialTransferFrom(JOIN_SPLIT_PROOF, _proof2Outputs.get(0));



  }

       
}
