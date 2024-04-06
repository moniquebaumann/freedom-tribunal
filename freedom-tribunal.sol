// SPDX-License-Identifier: GNU AFFERO GENERAL PUBLIC LICENSE Version 3

// Incentive System for Truth Exploration, Respect & Freedom. 

// Any project can become a community guarded project via the Freedom Tribunal.

// The Freedom Tribunal leverages Freedom Cash as decentralized currency to incentivize voting.

pragma solidity 0.8.19;

import "https://raw.githubusercontent.com/moniquebaumann/freedom-cash/v0.0.1/freedom-cash-interface.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/v4.9.4/contracts/token/ERC20/IERC20.sol";

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