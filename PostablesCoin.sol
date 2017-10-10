pragma solidity 0.4.16;


// implement safemath as a library
library SafeMath {

  function mul(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a * b;
    require(a == 0 || c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a / b;
    return c;
  }

  function sub(uint256 a, uint256 b) internal constant returns (uint256) {
    require(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a + b;
    require(c >= a);
    return c;
  }
}

// Used for function invoke restriction
contract Owned {

    address public owner; // temporary address

    function Owned() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner)
            revert();
        _; // function code inserted here
    }

    function transferOwnership(address _newOwner) onlyOwner returns (bool success) {
        if (msg.sender != owner)
            revert();
        owner = _newOwner;
        return true;
        
    }
}


contract PostablesCoin is Owned {
    using SafeMath for uint256;

    address     public      special;
    address     public      hotWallet;
    uint256     public      currentMaxVestCycle;
    uint256     public      vestingDuration = 4 weeks;
    uint256     public      totalSupply;
    uint8       public      decimals;
    string      public      name;
    string      public      symbol;
    bool        public      tokenTransfersFrozen;
    bool        public      gamblingEnabled;
    bool        public      contractLaunched;

    /// @notice Used for users to vest their tokens, they must  invoke the vesting function
    /// [key = address][value = PBLS balance to vest]
    mapping (address => uint256) public vestedBalances;
    /// @notice Used to track the payout date for a user
    mapping (address => uint256) public minVestingPayoutDate;
    /// @notice ERC20 mappings
    mapping (address => uint256) public balances;
    mapping (address => mapping (address => uint256)) public allowance;

    /// @notice Notifies blockchain that a vesting occured
    event VestingInitiated(address indexed _vester, uint256 indexed _amount, bool indexed _vested);
    /// @notice Notifies blockchain that vesting ended, and they were paid out
    event VestingEnded(address indexed _vester, uint256 indexed _amount, bool indexed _paid);
    /// @notice ERC20 events
    event Transfer(address indexed _from, address indexed _to, uint256 _amount);
    event Approve(address indexed _owner, address indexed _spender, uint256 _amount);

    function PostablesCoin(address _hotWallet, uint256 _totalSupply) {
        hotWallet = _hotWallet;
        totalSupply = _totalSupply;
        balances[msg.sender] = 0;
        balances[_hotWallet] = _totalSupply;
        name = "PostablesCoin";
        symbol = "PBLES";
        decimals = 18;
    }
    /// @notice Low level function used to validate vesting parameters
    /// @param _vestingDuration must be a minimum of 4 cycles, aka 4 weeks
    /// @param _vestingAmount must be AT LEAST half the users balance for a minimum of 1000 PBLES, user must have a min of 2K PBLES
    function vestCheck(uint256 _vestingDuration, uint256 _vestingAmount, address _invoker) 
        private 
        constant 
        returns (bool valid) 
    {
        require(balances[_invoker] >= 2000000000000000000000);
        require(_vestingDuration >= 4000000000000000000);
        require(_vestingAmount >= balances[_invoker].div(2));
        require(vestedBalances[_invoker].add(_vestingAmount) > vestedBalances[_invoker]);
        return true;
    }

    /// @notice Low level function used to validate vesting parameters, each time a user submits vesting funds, duration is reset
    /// @param _vestingDuration must be a minimum of 4 cycles, aka 4 weeks
    /// @param _vestingAmount must be AT LEAST half the users balance for a minimum of 1000 PBLES, user must have a min of 2K PBLES
    function vestTokens(uint256 _vestingDuration, uint256 _vestingAmount)
        public
        returns (bool vested)
    {
        require(vestCheck(_vestingDuration, _vestingAmount, msg.sender));
        balances[msg.sender] = balances[msg.sender].sub(_vestingAmount);
        balances[this] = balances[this].add(_vestingAmount);
        vestedBalances[msg.sender] = vestedBalances[msg.sender].add(_vestingAmount);
        minVestingPayoutDate[msg.sender] = now + 4 weeks;
        Transfer(msg.sender, this, _vestingAmount);
    }

    function calculateVestingReward()
        private
        constant
        returns (uint256 vestingReward)
    {
        require(vestedBalances[msg.sender] > 0);
        uint256 _vestingBalances = vestedBalances[msg.sender];
        uint256 _rewardAmount = _vestingBalances.mul(100000000000000000);
        return _rewardAmount;
    }

    function vestingRefundCheck(address _invoker)
        private
        constant
        returns (bool valid)
    {
        uint256 _balance = vestedBalances[_invoker];
        require(_balance > 0);
        require(vestedBalances[_invoker].sub(_balance) > 0);
        require(balances[this].sub(_balance) > 0);
        require(balances[_invoker].add(_balance) > 0);
        require(balances[_invoker].add(_balance) > balances[_invoker]);
        return true;
    }

    function retrieveVestingRewards()
        public
        returns (bool rewarded)
    {
        require(vestingRefundCheck(msg.sender));
        uint256 rewardAmount = calculateVestingReward();
        balances[this] = balances[this].sub(rewardAmount);
        balances[msg.sender] = balances[msg.sender].add(rewardAmount);
        msg.sender.transfer(rewardAmount);
        return true;
    }
}