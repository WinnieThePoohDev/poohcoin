contract Xi is Context, IBEP20, Ownable {
    
  using SafeMath for uint256;

  mapping (address => uint256) private _balances;

  mapping (address => mapping (address => uint256)) private _allowances;
  
  address poohAddy = 0x9673C2196fCAe71bE87864CDb04aDc4644559e89;
  address LPaddy = 0x0000000000000000000000000000000000000000; //will have func to change by owner
  
  IBEP20 POOH = IBEP20(poohAddy);
  IBEP20 XILP = IBEP20(LPaddy);

  uint256 private _totalSupply;
  uint8 private _decimals;
  string private _symbol;
  string private _name;
  uint256 totalStaked;
  uint256 totalLPstaked;
  uint256 stakeTime = 96000; // in blocks
  uint256 LPstakeTime = 192000; // in blocks
  uint256 LPtimegate = 13700; // in blocks
  uint256 blockReward = 10; // per token staked
  uint256 LPreward = 35; // per token staked
  uint256 startBlock;
  
  struct poohStakeInfo {
        
        uint[] deposits;
        uint[] depositTimes;
        uint[] rewards;
        
    }
    
    struct LPStakeInfo {
        
        uint[] deposits;
        uint[] depositTimes;
        uint[] rewards;
        
    }
    
  mapping(address => poohStakeInfo) Stakes;
  mapping(address => LPStakeInfo) LPStakes;
  mapping (address => uint256) public stakedBalance;
  mapping(address => uint256) public stakedLPBalance;
  
  constructor() public {
    _name = "Xi Coin";
    _symbol = "Xi";
    _decimals = 18;
    _totalSupply = 1;
    _balances[address(this)] = _totalSupply;
    totalStaked = 0;
    startBlock = block.number;
    _mint(msg.sender, 1000000 * (10 ** 18));

    emit Transfer(address(0), msg.sender, _totalSupply);
  }
  
  function withdrawBNB() public onlyOwner {
      msg.sender.transfer(address(this).balance);
  }
  
    function stakePOOH(uint256 _amount) public {
        require(_amount > 0);
        require(block.number < startBlock.add(stakeTime));
        //Transfer POOH for staking
        require(POOH.transferFrom(msg.sender, address(this), _amount));
        //Update stakedBalance for msgsender address
        stakedBalance[msg.sender] = stakedBalance[msg.sender].add(_amount);
        //Add _amount to totalStaked
        totalStaked = totalStaked.add(_amount);
        //Push _amount to deposits[] and block.number to depositTimes[]
        //Used to calculate poolShare and distribute rewards upon unstaking - repeated for every deposit made individually
        Stakes[msg.sender].deposits.push(_amount);
        Stakes[msg.sender].depositTimes.push(block.number);

    }
    
    function unstakePOOH() public {
        //Check staked balance above 0
        require(stakedBalance[msg.sender] > 0);
        //Repeat for every deposit made by user
        for(uint i; i < Stakes[msg.sender].deposits.length; i++) {
            //get difference in block numbers from deposit block to current block
            uint diff = (block.number.sub(Stakes[msg.sender].depositTimes[i]));
            //Hardcap diff to maximum possible stake time in blocks
            if(diff > 96000){
                diff = 96000;
            }
            //assign appropriate reward to user rewards[i]
            Stakes[msg.sender].rewards[i] = (Stakes[msg.sender].deposits[i].mul(blockReward)).mul(diff);
            //mint amount of Xi stored in rewards[i] to user
            _mint(msg.sender, Stakes[msg.sender].rewards[i]);
        }
        //delete deposits[] and depositTimes[] to clear
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
        require(block.number >= startBlock + LPtimegate);
        require(block.number < startBlock.add(LPstakeTime));
        //Transfer XILP for staking
        require(XILP.transferFrom(msg.sender, address(this), _amount));
        //Update stakedBalance for msgsender address
        stakedLPBalance[msg.sender] = stakedLPBalance[msg.sender].add(_amount);
        //Add _amount to totalStaked
        totalLPstaked = totalLPstaked.add(_amount);
        //Push _amount to deposits[] and block.number to depositTimes[]
        //Used to calculate poolShare and distribute rewards upon unstaking - repeated for every deposit made individually
        LPStakes[msg.sender].deposits.push(_amount);
        LPStakes[msg.sender].depositTimes.push(block.number);

    }
    
    function unstakeLP() public {
        //Check staked balance above 0
        require(stakedLPBalance[msg.sender] > 0);
        //Repeat for every deposit made by user
        for(uint i; i < LPStakes[msg.sender].deposits.length; i++) {
            //get difference in block numbers from deposit block to current block
            uint diff = (block.number.sub(LPStakes[msg.sender].depositTimes[i]));
            //Hardcap diff to maximum possible stake time in blocks
            if(diff > 96000){
                diff = 96000;
            }
            //assign appropriate reward to user rewards[i]
            LPStakes[msg.sender].rewards[i] = (LPStakes[msg.sender].deposits[i].mul(blockReward)).mul(diff);
            //mint amount of Xi stored in rewards[i] to user
            _mint(msg.sender, LPStakes[msg.sender].rewards[i]);
        }
        //delete deposits[] and depositTimes[] to clear
        delete LPStakes[msg.sender].deposits;
        delete LPStakes[msg.sender].depositTimes;
        //Transfer XIBNB-LP back to user
        XILP.transfer(msg.sender, stakedLPBalance[msg.sender]);
        //subtract from total staked
        //Set user stakedLPBalance back to 0
        totalLPstaked = totalLPstaked.sub(stakedLPBalance[msg.sender]);
        stakedLPBalance[msg.sender] = 0;
        
    }
  
