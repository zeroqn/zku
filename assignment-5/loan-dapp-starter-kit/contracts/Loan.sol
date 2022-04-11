pragma solidity >= 0.5.0 <0.7.0;
import "@aztec/protocol/contracts/ERC1724/ZkAssetMintable.sol";
import "@aztec/protocol/contracts/libs/NoteUtils.sol";
import "@aztec/protocol/contracts/interfaces/IZkAsset.sol";
import "./LoanUtilities.sol";

contract Loan is ZkAssetMintable {

  using SafeMath for uint256;
  using NoteUtils for bytes;
  using LoanUtilities for LoanUtilities.LoanVariables;
  LoanUtilities.LoanVariables public loanVariables;


  IZkAsset public settlementToken;
  // [0] interestRate
  // [1] interestPeriod
  // [2] duration
  // [3] settlementCurrencyId
  // [4] loanSettlementDate
  // [5] lastInterestPaymentDate address public borrower;
  address public lender;
  address public borrower;

  mapping(address => bytes) lenderApprovals;

  event LoanPayment(string paymentType, uint256 lastInterestPaymentDate);
  event LoanDefault();
  event LoanRepaid();

  struct Note {
    address owner;
    bytes32 noteHash;
  }

  function _noteCoderToStruct(bytes memory note) internal pure returns (Note memory codedNote) {
      (address owner, bytes32 noteHash,) = note.extractNote();
      return Note(owner, noteHash );
  }


  constructor(
    bytes32 _notional,
    uint256[] memory _loanVariables,
    address _borrower,
    address _aceAddress,
    address _settlementCurrency
   ) public ZkAssetMintable(_aceAddress, address(0), 1, true, false) {
      loanVariables.loanFactory = msg.sender;
      loanVariables.notional = _notional;
      loanVariables.id = address(this);
      loanVariables.interestRate = _loanVariables[0];
      loanVariables.interestPeriod = _loanVariables[1];
      loanVariables.duration = _loanVariables[2];
      loanVariables.borrower = _borrower;
      borrower = _borrower;
      loanVariables.settlementToken = IZkAsset(_settlementCurrency);
      loanVariables.aceAddress = _aceAddress;
  }

  function requestAccess() public {
    lenderApprovals[msg.sender] = '0x';
  }

  // sharedSecret is encrypted loan viewing key by lender public key
  function approveAccess(address _lender, bytes memory _sharedSecret) public {
    lenderApprovals[_lender] = _sharedSecret;
  }

  function settleLoan(
    bytes calldata _proofData,
    bytes32 _currentInterestBalance,
    address _lender
  ) external {
    // Only loan dapp contract created this loan contract can call this func
    LoanUtilities.onlyLoanDapp(msg.sender, loanVariables.loanFactory);

    // Swap proof: lender take borrower ask, swap lender value and borrower notional value
    LoanUtilities._processLoanSettlement(_proofData, loanVariables);

    loanVariables.loanSettlementDate = block.timestamp;
    loanVariables.lastInterestPaymentDate = block.timestamp;
    loanVariables.currentInterestBalance = _currentInterestBalance;
    loanVariables.lender = _lender;
    lender = _lender;
  }

  // mint new notes from given proof
  function confidentialMint(uint24 _proof, bytes calldata _proofData) external {
    // Only loan dapp contract created this loan contract can call this func
    LoanUtilities.onlyLoanDapp(msg.sender, loanVariables.loanFactory);
    require(msg.sender == owner, "only owner can call the confidentialMint() method");
    require(_proofData.length != 0, "proof invalid");
    // overide this function to change the mint method to msg.sender
    (bytes memory _proofOutputs) = ace.mint(_proof, _proofData, msg.sender);

    // A output note represent total value
    (, bytes memory newTotal, ,) = _proofOutputs.get(0).extractProofOutput();

    // A output notes represent minted values, notional and interest balance
    (, bytes memory mintedNotes, ,) = _proofOutputs.get(1).extractProofOutput();

    (,
    bytes32 noteHash,
    bytes memory metadata) = newTotal.extractNote();

    logOutputNotes(mintedNotes);
    emit UpdateTotalMinted(noteHash, metadata);
  }


  function withdrawInterest(
    bytes memory _proof1,
    bytes memory _proof2,
    uint256 _interestDurationToWithdraw
  ) public {
    // Dividend proof: notional * interest ratio == interest duration to withdrawal
    (,bytes memory _proof1OutputNotes) = LoanUtilities._validateInterestProof(_proof1, _interestDurationToWithdraw, loanVariables);

    // Verify interest withdrawal timestamp is within correct time window
    require(_interestDurationToWithdraw.add(loanVariables.lastInterestPaymentDate) < block.timestamp, ' withdraw is greater than accrued interest');

    // Join split proof: interest balance => interest withdrawal + remain interest balance
    // Also transfer interest withdrawal note
    (bytes32 newCurrentInterestNoteHash) = LoanUtilities._processInterestWithdrawal(_proof2, _proof1OutputNotes, loanVariables);

    // Update remain interest balance
    loanVariables.currentInterestBalance = newCurrentInterestNoteHash;
    loanVariables.lastInterestPaymentDate = loanVariables.lastInterestPaymentDate.add(_interestDurationToWithdraw);

    emit LoanPayment('INTEREST', loanVariables.lastInterestPaymentDate);

  }

  // Adjust interest balance from borrower
  function adjustInterestBalance(bytes memory _proofData) public {
    // Only borrower can adjust interest balance
    LoanUtilities.onlyBorrower(msg.sender,borrower);

    // `[]` means optional, if present, borrower add amount to interest balance. Otherwise borrow withdraw
    // asset from interest balance.

    // Join split proof: old interest balance + [borrower unspend notes] => borrower change + new interest balance
    // borrower change will return to borrower
    (bytes32 newCurrentInterestBalance) = LoanUtilities._processAdjustInterest(_proofData, loanVariables);
    loanVariables.currentInterestBalance = newCurrentInterestBalance;
  }

  function repayLoan(
    bytes memory _proof1,
    bytes memory _proof2
  ) public {
    // Only borrower can repay loan
    LoanUtilities.onlyBorrower(msg.sender, borrower);

    uint256 remainingInterestDuration = loanVariables.loanSettlementDate.add(loanVariables.duration).sub(loanVariables.lastInterestPaymentDate);

    // Dividend proof: notional * ratio == remaining interest duration
    (,bytes memory _proof1OutputNotes) = LoanUtilities._validateInterestProof(_proof1, remainingInterestDuration, loanVariables);

    // Only after duration pass, can repay loan
    require(loanVariables.loanSettlementDate.add(loanVariables.duration) < block.timestamp, 'loan has not matured');


    // Join split proof: notinal note + remaining interest => lender unspend outputs
    LoanUtilities._processLoanRepayment(
      _proof2,
      _proof1OutputNotes,
      loanVariables
    );

    emit LoanRepaid();
  }

   // Mark loan as default is balance is not enough
  function markLoanAsDefault(bytes memory _proof1, bytes memory _proof2, uint256 _interestDurationToWithdraw) public {
    require(_interestDurationToWithdraw.add(loanVariables.lastInterestPaymentDate) < block.timestamp, 'withdraw is greater than accrued interest');
    // Dividend proof: notional * ratio = interest duration to withdrawal
    // Private range proof: current interest balance < interest duration to withdrawal
    LoanUtilities._validateDefaultProofs(_proof1, _proof2, _interestDurationToWithdraw, loanVariables);
    emit LoanDefault();
  }
}
