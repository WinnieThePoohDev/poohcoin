pragma solidity ^0.5.16;

import "./IBEP20.sol";

//XI FARM CONTRACT
//A DUMB MANS ATTEMPT AT MAKING A STAKING FUNCTIONALITY FOR A SHITCOIN.
//REVEL IN IT'S BADNESS.

contract XiFarm is Context, Ownable {
    
  using SafeMath for uint256;
  
  address poohAddy = 0x9673C2196fCAe71bE87864CDb04aDc4644559e89;//POOHTEST ADDY
  address XiAddy = 0x098b246bf19ba9C5aD9C5dD994815e1db444eaA6;//XITEST ADDY
  address LPaddy = 0x0000000000000000000000000000000000000000; //LPTokenAddy - to be updated with onlyOwner function
  
  IBEP20 POOH = IBEP20(poohAddy);
  IBEP20 Xi = IBEP20(XiAddy);
  IBEP20 LPtoken = IBEP20(LPaddy);
  
  uint public xiStakeRewardCap = 20000000 * (10 ** 18);//20% of TOTAL Xi Supply - To be deposited by Xi Token contract creator
  uint public xiStakeTime = 96000; //TIME IN BLOCKS - ~1,440,000 seconds
  uint public xiTokensLeft; // Tracks how many REWARD tokens are left in contract
  uint public LPStakeRewardCap = 70000000 * (10 ** 18); // 70% of TOTAL Xi supply
  uint public LPStakeTime = 192000; // approx 4 weeks in blocks
  uint public LPstakeTimegate = 13000; //approx 2 days in blocks
 
  uint totalStaked = 0;
  uint startBlock;
  uint LPstartBlock;
  uint endBlock;
  uint LPendBlock;
  uint totalLPStaked = 0;
  
  mapping (address => uint256) public stakedBalance;
  mapping (address => uint256) public LPstakedBalance;


  constructor() public {
      xiTokensLeft = xiStakeRewardCap+LPStakeRewardCap;
      startBlock = block.number;
      LPstartBlock = block.number+LPstakeTimegate;
      endBlock = startBlock+xiStakeTime;
      LPendBlock = LPstartBlock+LPStakeTime;
  }
    //Struct that keeps information about each users stake, mapped to with Stakes
    struct stakeInfo {
        
        uint[] deposits;
        uint[] depositTimes;
        uint[] rewards;
        uint[] totalStakedAtDeposit;
        
    }
    
    //Struct that keeps information about each users stake, mapped to with LPStakes
    struct LPstakeInfo {
        
        uint[] deposits;
        uint[] depositTimes;
        uint[] rewards;
        uint[] totalStakedAtDeposit;
        
    }
    
    mapping(address => stakeInfo) Stakes;
    mapping(address => stakeInfo) LPStakes;
    uint[] everyPoohDepositTime;
    
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
        everyPoohDepositTime.push(block.number);
        Stakes[msg.sender].totalStakedAtDeposit.push(totalStaked);
        Stakes[msg.sender].deposits.push(_amount);
        Stakes[msg.sender].depositTimes.push(block.number);

    }
    
    function unstakePOOH() public {
        //Check staked balance above 0
        require(stakedBalance[msg.sender] > 0);
        //Repeat for every deposit made by user
        for(uint i; i < Stakes[msg.sender].deposits.length; i++) {
            //Checks if current deposit in loop was deposited on a lower block number than the latest deposit
            if(Stakes[msg.sender].depositTimes[i] < everyPoohDepositTime[everyPoohDepositTime.length-1]){
                //Loop through every deposit blocknumber, check if user staked balance is lower
                for(uint y = i; Stakes[msg.sender].depositTimes[i] <= everyPoohDepositTime[y]; y++){
                    //set diff var to difference between Deposit [y] and user staked deposit
                    uint diff = everyPoohDepositTime[y].sub(Stakes[msg.sender].depositTimes[i]);
                    //run reward calculation for this deposit based on total number of tokens staked before another deposit.
                    Stakes[msg.sender].rewards[i] = Stakes[msg.sender].rewards[i].add(calcPoohReward(Stakes[msg.sender].deposits[i], Stakes[msg.sender].totalStakedAtDeposit[i])*diff);
                }
            }else{
            uint diff = (block.number.sub(Stakes[msg.sender].depositTimes[i]));
            //Clamp diff to maximum possible stake window
            if(block.number > endBlock){
                diff = diff.sub(block.number-endBlock);
            }
            //assign appropriate reward to user rewards[i]
            Stakes[msg.sender].rewards[i] = calcPoohReward(Stakes[msg.sender].deposits[i], Stakes[msg.sender].totalStakedAtDeposit[i])*diff;
            }
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
    
    function stakeLP(uint256 _amount) public {
        require(_amount > 0);
        require(block.number < LPendBlock);
        //Transfer POOH for staking
        require(LPtoken.transferFrom(msg.sender, address(this), _amount));
        //Update stakedBalance for msgsender address
        LPstakedBalance[msg.sender] = LPstakedBalance[msg.sender].add(_amount);
        //Add _amount to totalStaked
        totalLPStaked = totalLPStaked.add(_amount);
        //Push _amount to deposits[] and block.number to depositTimes[]
        //Used to calculate and distribute rewards upon unstaking - repeated for every deposit made individually
        LPStakes[msg.sender].deposits.push(_amount);
        LPStakes[msg.sender].depositTimes.push(block.number);

    }
    
    function claimLPstakes() public {
        //Check staked balance above 0
        require(LPstakedBalance[msg.sender] > 0);
        //Repeat for every deposit made by user
        for(uint i; i < LPStakes[msg.sender].deposits.length; i++) {
            //get difference in block numbers from deposit block to current block
            uint diff = (block.number.sub(LPStakes[msg.sender].depositTimes[i]));
            //Clamp diff to maximum possible stake window
            if(block.number > LPendBlock){
                diff = diff.sub(block.number-LPendBlock);
            }
            //assign appropriate reward to user rewards[i]
            //Uses calcReward() internal function
            LPStakes[msg.sender].rewards[i] = calcReward(LPStakes[msg.sender].deposits[i])*diff;
            //send amount of Xi stored in rewards[i] to user
            Xi.transfer(msg.sender, LPStakes[msg.sender].rewards[i]);
            //subtract reward amount from xiTokensLeft for next loop
            xiTokensLeft = xiTokensLeft.sub(LPStakes[msg.sender].rewards[i]);
            //subtract deposits[i] from user stakedBalance
            LPstakedBalance[msg.sender] = LPstakedBalance[msg.sender].sub(LPStakes[msg.sender].deposits[i]);
        }
        //delete deposits[] and depositTimes[] to clear??
        delete LPStakes[msg.sender].deposits;
        delete LPStakes[msg.sender].depositTimes;
        //Transfer POOH back to user
        LPtoken.transfer(msg.sender, LPstakedBalance[msg.sender]);
        //subtract from total staked
        //Set user stakedBalance back to 0
        LPstakedBalance[msg.sender] = 0;
    }
    
    function calcReward(uint _reward) internal view returns (uint) {
        uint div = LPStakeRewardCap/totalLPStaked;
        uint mul = _reward.mul(div)/LPStakeTime; 
        return mul;
    }
    
    function calcPoohReward(uint _reward, uint _totalStakedAD) internal view returns (uint) {
        uint div = xiStakeRewardCap/_totalStakedAD;
        uint mul = _reward.mul(div)/xiStakeTime; 
        return mul;
    }
    
    
    function burnUnclaimedXi() public onlyOwner {
        Xi.transfer(0x0000000000000000000000000000000000000000, Xi.balanceOf(address(this)));
    }
    
    function burnUnclaimedPOOH() public onlyOwner {
        POOH.transfer(0x0000000000000000000000000000000000000000, POOH.balanceOf(address(this)));
    }
    
    function updateStakeTokenAddress(address _address) public onlyOwner {
        poohAddy = _address;
    }
    
    function updateRewardTokenAddress(address _address) public onlyOwner {
        XiAddy = _address;
    }
    
    function updateLPaddress(address _address) public onlyOwner {
        LPaddy = _address;
    }
    
    
}
