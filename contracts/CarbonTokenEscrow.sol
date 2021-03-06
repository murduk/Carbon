pragma solidity ^0.4.18;

// ----------------------------------------------------------------------------
// 'FIXED' 'Example Fixed Supply Token' token contract
//
// Symbol      : FIXED
// Name        : Example Fixed Supply Token
// Total supply: 1,000,000.000000000000000000
// Decimals    : 18
//
// Enjoy.
//
// (c) BokkyPooBah / Bok Consulting Pty Ltd 2017. The MIT Licence.
// ----------------------------------------------------------------------------


// ----------------------------------------------------------------------------
// Safe maths
// ----------------------------------------------------------------------------
library SafeMath {
    function add(uint a, uint b) internal pure returns (uint c) {
        c = a + b;
        require(c >= a);
    }
    function sub(uint a, uint b) internal pure returns (uint c) {
        require(b <= a);
        c = a - b;
    }
    function mul(uint a, uint b) internal pure returns (uint c) {
        c = a * b;
        require(a == 0 || c / a == b);
    }
    function div(uint a, uint b) internal pure returns (uint c) {
        require(b > 0);
        c = a / b;
    }
}


// ----------------------------------------------------------------------------
// ERC Token Standard #20 Interface
// https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md
// ----------------------------------------------------------------------------
contract ERC20Interface {
    function totalSupply() public constant returns (uint);
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}


// ----------------------------------------------------------------------------
// Escrow contract 
//
// Inspired from local.ethereum
// ----------------------------------------------------------------------------
contract CarbonEscrow {
    //function receiveApproval(address from, uint256 tokens, address token, bytes data) public;
    address public arbitrator;
    address public owner;
    
    event Created(bytes32 _tradeHash);
    event Released(bytes32 _tradeHash);
    event Funded(bytes32 _tradeHash);
    event DisputeResolved(bytes32 _tradeHash);    
    
    struct Escrow {
        // Set so we know the trade has already been created
        bool exists;
    }
    
    mapping (bytes32 => Escrow) public escrows;
    
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyArbitrator() {
        require(msg.sender == arbitrator);
        _;
    }    
    
    function CarbonEscrow() public {
        /**
         * Initialize the contract.
         */
        owner = msg.sender;
        arbitrator = msg.sender;
    }
    
    function getEscrowAndHash(
      /**
       * Hashes the values and returns the matching escrow object and trade hash.
       * Returns an empty escrow struct and 0 _tradeHash if not found
       */
      uint16 _tradeID,
      address _seller,
      address _buyer,
      uint256 _value
    ) view private returns (Escrow, bytes32) {
        bytes32 _tradeHash = keccak256(_tradeID, _seller, _buyer, _value);
        return (escrows[_tradeHash], _tradeHash);
    }

    function createEscrow(
      /**
       * Create a new escrow and add it to `escrows`.
       * _tradeHash is created by hashing _tradeID, _seller, _buyer, _value variables.
       */
      uint16 _tradeID, // The unique ID of the trade, generated by localethereum.com
      address _seller, // The selling party of the trade
      address _buyer, // The buying party of the trade
      uint256 _value // The carbontoken amount being held in escrow
    ) public {
        bytes32 _tradeHash = keccak256(_tradeID, _seller, _buyer, _value);
        require(!escrows[_tradeHash].exists); // Require that trade does not already exist
        require(msg.value == _value && msg.value > 0); // Check sent eth against signed _value and make sure is not 0
        escrows[_tradeHash] = Escrow(true);
        Created(_tradeHash);
    }    
    
    //this function is funding the Escrow (msg.sender is the seller and funder)
    //there should be an escrow created, tokens must match the escrow fund,
    function recieveCarbonTokens(address buyer, uint16 tradeID, address tokenAddress, uint tokens) public returns (bool success){
        var (esc, tradeHash) = getEscrowAndHash(tradeID, msg.sender, buyer, tokens);
        require(tradeHash > 0);
        Funded(tradeHash);
        return ERC20Interface(tokenAddress).transferFrom(msg.sender,this,tokens);
    }
    
    //this function is for releasing the Escrow
    //there should be an escrow created, tokens must match the escrow fund. (msg.sender is the seller and releaser)
    function releaseCarbonTokens(address buyer, uint16 tradeID, address tokenAddress, uint tokens) public returns (bool success){
        var (esc, tradeHash) = getEscrowAndHash(tradeID, msg.sender, buyer, tokens);
        require(tradeHash > 0);
        Released(tradeHash);
        return ERC20Interface(tokenAddress).transfer(msg.sender, tokens);
    }    
}


// ----------------------------------------------------------------------------
// Owned contract
// ----------------------------------------------------------------------------
contract Owned {
    address public owner;
    address public newOwner;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    function Owned() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        newOwner = _newOwner;
    }
    function acceptOwnership() public {
        require(msg.sender == newOwner);
        OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }
}


// ----------------------------------------------------------------------------
// ERC20 Token, with the addition of symbol, name and decimals and an
// initial fixed supply
// ----------------------------------------------------------------------------
contract CarbonToken is ERC20Interface, Owned {
    using SafeMath for uint;

    string public symbol;
    string public  name;
    uint8 public decimals;
    uint public _totalSupply;

    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowed;


    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    function CarbonToken() public {
        symbol = "FIXED";
        name = "Example Fixed Supply Token";
        decimals = 18;
        _totalSupply = 1000000 * 10**uint(decimals);
        balances[owner] = _totalSupply;
        Transfer(address(0), owner, _totalSupply);
    }


    // ------------------------------------------------------------------------
    // Total supply
    // ------------------------------------------------------------------------
    function totalSupply() public constant returns (uint) {
        return _totalSupply  - balances[address(0)];
    }


    // ------------------------------------------------------------------------
    // Get the token balance for account `tokenOwner`
    // ------------------------------------------------------------------------
    function balanceOf(address tokenOwner) public constant returns (uint balance) {
        return balances[tokenOwner];
    }


    // ------------------------------------------------------------------------
    // Transfer the balance from token owner's account to `to` account
    // - Owner's account must have sufficient balance to transfer
    // - 0 value transfers are allowed
    // ------------------------------------------------------------------------
    function transfer(address to, uint tokens) public returns (bool success) {
        balances[msg.sender] = balances[msg.sender].sub(tokens);
        balances[to] = balances[to].add(tokens);
        Transfer(msg.sender, to, tokens);
        return true;
    }


    // ------------------------------------------------------------------------
    // Token owner can approve for `spender` to transferFrom(...) `tokens`
    // from the token owner's account
    //
    // https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md
    // recommends that there are no checks for the approval double-spend attack
    // as this should be implemented in user interfaces 
    // ------------------------------------------------------------------------
    function approve(address spender, uint tokens) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        Approval(msg.sender, spender, tokens);
        return true;
    }


    // ------------------------------------------------------------------------
    // Transfer `tokens` from the `from` account to the `to` account
    // 
    // The calling account must already have sufficient tokens approve(...)-d
    // for spending from the `from` account and
    // - From account must have sufficient balance to transfer
    // - Spender must have sufficient allowance to transfer
    // - 0 value transfers are allowed
    // ------------------------------------------------------------------------
    function transferFrom(address from, address to, uint tokens) public returns (bool success) {
        balances[from] = balances[from].sub(tokens);
        allowed[from][msg.sender] = allowed[from][msg.sender].sub(tokens);
        balances[to] = balances[to].add(tokens);
        Transfer(from, to, tokens);
        return true;
    }


    // ------------------------------------------------------------------------
    // Returns the amount of tokens approved by the owner that can be
    // transferred to the spender's account
    // ------------------------------------------------------------------------
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining) {
        return allowed[tokenOwner][spender];
    }


    // ------------------------------------------------------------------------
    // Token owner can approve for `spender` to transferFrom(...) `tokens`
    // from the token owner's account. The `spender` contract function
    // `receiveApproval(...)` is then executed
    // ------------------------------------------------------------------------
    function approveAndCall(address spender, uint tokens, bytes data) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        Approval(msg.sender, spender, tokens);
        //ApproveAndCallFallBack(spender).receiveApproval(msg.sender, tokens, this, data);
        return true;
    }


    // ------------------------------------------------------------------------
    // Don't accept ETH
    // ------------------------------------------------------------------------
    function () public payable {
        revert();
    }


    // ------------------------------------------------------------------------
    // Owner can transfer out any accidentally sent ERC20 tokens
    // ------------------------------------------------------------------------
    function transferAnyERC20Token(address tokenAddress, uint tokens) public onlyOwner returns (bool success) {
        return ERC20Interface(tokenAddress).transfer(owner, tokens);
    }
}
