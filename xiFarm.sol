pragma solidity ^0.5.16;

import "./IBEP20.sol";

//XI FARM CONTRACT
//A DUMB MANS ATTEMPT AT MAKING A STAKING FUNCTIONALITY FOR A SHITCOIN.
//REVEL IN IT'S BADNESS.

contract XiFarm is Context, Ownable {
    
  using SafeMath for uint256;
  
  address poohAddy = 0x9673C2196fCAe71bE87864CDb04aDc4644559e89;//POOHTEST ADDY
  address XiAddy = 0x098b246bf19ba9C5aD9C5dD994815e1db444eaA6;//XITEST ADDY
  
  IBEP20 POOH = IBEP20(poohAddy);
  IBEP20 Xi = IBEP20(XiAddy);
  
  uint public xiStakeRewardCap = 20000000 * (10 ** 18);//20% of TOTAL Xi Supply - To be deposited by Xi Token contract creator
  uint public xiStakeTime = 96000; //TIME IN BLOCKS - ~1,440,000 seconds
  uint public xiTokensLeft; // Tracks how many REWARD tokens are left in contract
 
  uint totalStaked = 0;
  uint startBlock;
  uint endBlock;
  
  mapping (address => uint256) public stakedBalance;


  constructor() public {
      xiTokensLeft = xiStakeRewardCap;
      startBlock = block.number;
      endBlock = startBlock+xiStakeTime;
  }
    //Struct that keeps information about each users stake, mapped to with Stakes
    struct stakeInfo {
        
        uint[] deposits;
        uint[] depositTimes;
        uint[] rewards;
        
    }
    
    mapping(address => stakeInfo) Stakes;
    
    function stakePOOH(uint256 _amount) public {
        require(_amount > 0);
        require(block.number < endBlock);
        //Transfer POOH for staking
        require(POOH.transferFrom(msg.sender, address(this), _amount));
        //Update stakedBalance for msgsender address
        stakedBalance[msg.sender] = stakedBalance[msg.sender].add(_amount);
        //Add _amount to totalStaked
        totalStaked = totalStaked.add(_amount);
        //Push _amount to deposits[] and block.number to depositTimes[]
        //Used to calculate and distribute rewards upon unstaking - repeated for every deposit made individually
        Stakes[msg.sender].deposits.push(_amount);
        Stakes[msg.sender].depositTimes.push(block.number);

    }
    
    function unstakeTokens() public {
        //Check staked balance above 0
        require(stakedBalance[msg.sender] > 0);
        //Repeat for every deposit made by user
        for(uint i; i < Stakes[msg.sender].deposits.length; i++) {
            //get difference in block numbers from deposit block to current block
            uint diff = (block.number.sub(Stakes[msg.sender].depositTimes[i]));
            //Clamp diff to maximum possible stake window
            if(block.number > endBlock){
                diff = diff.sub(block.number-endBlock);
            }
            //assign appropriate reward to user rewards[i]
            //Number of tokens staked multiplied by number of blocks staked for and divided by 20k to keep the total supply reasonable
            Stakes[msg.sender].rewards[i] = (Stakes[msg.sender].deposits[i].mul(diff))/20000;
            //send amount of Xi stored in rewards[i] to user
            Xi.transfer(msg.sender, Stakes[msg.sender].rewards[i]);
            //subtract reward amount from xiTokensLeft for next loop
            xiTokensLeft = xiTokensLeft.sub(Stakes[msg.sender].rewards[i]);
            //subtract deposits[i] from user stakedBalance
            stakedBalance[msg.sender] = stakedBalance[msg.sender].sub(Stakes[msg.sender].deposits[i]);
        }
        //delete deposits[] and depositTimes[] to clear??
        delete Stakes[msg.sender].deposits;
        delete Stakes[msg.sender].depositTimes;
        //Transfer POOH back to user
        POOH.transfer(msg.sender, stakedBalance[msg.sender]);
        //subtract from total staked
        //Set user stakedBalance back to 0
        totalStaked = totalStaked.sub(stakedBalance[msg.sender]);
        stakedBalance[msg.sender] = 0;
        
    }
    
    function burnUnclaimedXi() public onlyOwner {
        Xi.transfer(0x0000000000000000000000000000000000000000, Xi.balanceOf(address(this)));
    }
    
    
}
