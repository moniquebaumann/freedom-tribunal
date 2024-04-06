
// File: https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.9.4/contracts/token/ERC20/IERC20.sol


// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// File: https://raw.githubusercontent.com/moniquebaumann/freedom-cash/v0.0.1/freedom-cash-interface.sol



pragma solidity 0.8.19;

interface IFreedomCash {
    function getBuyPrice(uint256 ethBalance, uint256 underway) external pure returns(uint256);
    function getSellPrice(uint256 ethBalance, uint256 underway) external pure returns(uint256);
    function buyFreedomCash(address receiver, uint256 requestAmount) external payable;
    function sellFreedomCash(uint256 amount) external;
    function getAmountOfETHForFC(uint256 fCPrice, uint256 fCAmount) external view returns(uint256);
    function getUnderway() external view returns(uint256);
}

// File: freedom-tribunal.sol



// Incentive System for Truth Exploration, Respect & Freedom. 

// Any project can become a community guarded project via the Freedom Tribunal.

// The Freedom Tribunal leverages Freedom Cash as decentralized currency to incentivize voting.

pragma solidity 0.8.19;



contract FreedomTribunal {

  uint256 public voteCounter;
  mapping(bytes32 => IAsset) public assets;
  mapping(uint256 => IVote) public votes;
  mapping(uint256 => bytes32) public voteToAssetHash;
  address public nativeFreedomCash = 0x1Dc4E031e7737455318C77f7515F8Ea8bE280a93;

  struct IAsset{
    uint256 upVoteScore;
    uint256 downVoteScore;
    uint256 reconciliationFrom;
    bool reconciled;
  }
  struct IVote {
    address payable from;
    uint256 amount;
    bool up;
    uint256 rewardAmount;
    bool claimed;
  }

  error Patience();
  error Nonsense();
  error HashAlreadyRegistered();
  error NothingToClaim();
  
  function isRegistered(bytes32 hash) public view returns(bool) {
    return assets[hash].reconciliationFrom != 0; 
  }
  function addAsset(bytes32 hash, uint256 votingPeriodMinLength) public {
      if (assets[hash].reconciliationFrom != 0) { revert HashAlreadyRegistered(); }
      IAsset memory asset = IAsset(0, 0, block.timestamp + votingPeriodMinLength, false);
      assets[hash] = asset;
  }
  function appreciateAsset(bytes32 hash, uint256 appreciationAmountFC) public payable  {
		if(assets[hash].reconciled) { revert Nonsense(); }    
    voteCounter++;
    IFreedomCash(nativeFreedomCash).buyFreedomCash{value: msg.value}(address(this), appreciationAmountFC);
    assets[hash].upVoteScore += appreciationAmountFC;
    IVote memory vote = IVote(payable (msg.sender), appreciationAmountFC, true, 0, false);
    votes[voteCounter] = vote;
    voteToAssetHash[voteCounter] = hash;
  }
  function depreciateAsset(bytes32 hash, uint256 depreciationAmountFC) public payable  {
    if(assets[hash].reconciled) { revert Nonsense(); }    
    voteCounter++;    
    IFreedomCash(nativeFreedomCash).buyFreedomCash{value: msg.value}(address(this), depreciationAmountFC);
    assets[hash].downVoteScore += depreciationAmountFC;
    IVote memory vote = IVote(payable(msg.sender), depreciationAmountFC, false, 0, false);
    votes[voteCounter] = vote;
    voteToAssetHash[voteCounter] = hash;
  }
  function reconcile(bytes32 hash) public {
    if(assets[hash].reconciled) { revert Nonsense(); }
    if(assets[hash].upVoteScore == 0 && assets[hash].downVoteScore == 0) { revert Nonsense(); }
    if (block.timestamp < assets[hash].reconciliationFrom) { revert Patience(); }
    if (assets[hash].upVoteScore >= assets[hash].downVoteScore) {
      uint256 sumOfLosingVotes = getSumOfLosingVotes(hash, true);
      if (sumOfLosingVotes > 0) {
        uint256 numberOfWinningVotes = getNumberOfWinningVotes(hash, true);
        distributeRewards(hash, true, sumOfLosingVotes, numberOfWinningVotes);      
      }
    } else {
      uint256 sumOfLosingVotes = getSumOfLosingVotes(hash, false);      
      if (sumOfLosingVotes > 0) {
        uint256 numberOfWinningVotes = getNumberOfWinningVotes(hash, false);      
        distributeRewards(hash, false, sumOfLosingVotes, numberOfWinningVotes);
      }
    }
    assets[hash].reconciled = true;
  }
  function getClaimableRewards(address receiver) public view returns(uint256 sum) {
    for (uint256 i = 1; i <= voteCounter; i++) {
      if (receiver == votes[i].from && !votes[i].claimed && assets[voteToAssetHash[i]].reconciled) {
        sum += votes[i].rewardAmount;
      }
    }
  }
  function claimRewards() public {
    uint256 amount = getClaimableRewards(msg.sender);
    if(amount == 0){ revert NothingToClaim(); }
    for (uint256 i = 1; i <= voteCounter; i++) {
      if (msg.sender == votes[i].from) {
        if (!votes[i].claimed && assets[voteToAssetHash[i]].reconciled && votes[i].rewardAmount > 0) {
          votes[i].claimed = true;
        }
      }
    }    
    IERC20(nativeFreedomCash).transfer(msg.sender, amount);
  }
  function getNumberOfWinningVotes(bytes32 hash, bool up) public view returns (uint256 counter) {
    for (uint256 i = 1; i <= voteCounter; i++) {
      if (hash == voteToAssetHash[i]) {
        if(up && votes[i].up) {
          counter++;
        } else if(!up && !votes[i].up) {
          counter++;
        }
      }
    } 
  }
  function getSumOfLosingVotes(bytes32 hash, bool up) public view returns (uint256 sum) {
    for (uint256 i = 1; i <= voteCounter; i++) {
      if (hash == voteToAssetHash[i]) {
        if((up && !votes[i].up) || (!up && votes[i].up)) {
          sum += votes[i].amount;
        }
      } 
    }
  }
  function distributeRewards(bytes32 hash, bool toUpvoters, uint256 sumOfLosingVotes, uint256 numberOfWinningVotes) internal {
    uint256 rewardPerWinner = sumOfLosingVotes / numberOfWinningVotes;      
    for (uint256 i = 1; i <= voteCounter; i++) {
      if (voteToAssetHash[i] == hash) {
        if((votes[i].up && toUpvoters) || (!votes[i].up && !toUpvoters)){
          votes[i].rewardAmount = rewardPerWinner + votes[i].amount;
        } 
      }
    }
  }
}