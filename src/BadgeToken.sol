// SPDX-License-Identifier: GPL-3.0 OR MIT
pragma solidity ^0.8.27;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Pausable.sol";

// Core ERC-20 token for the game, used for rewards and transactions
contract BadgeToken is Ownable, ReentrancyGuard, Pausable {
    string public name = "BadgeToken"; // Token name
    string public symbol = "BADGE"; // Token symbol
    uint8 public decimals = 18; // Decimal places for precision
    uint256 public totalSupply; // Total BADGE supply

    // Balances of BADGE for each address
    mapping(address => uint256) public balances;
    // Allowances for spending on behalf of others
    mapping(address => mapping(address => uint256)) private _allowances;

    // Events for tracking transfers and approvals
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // Constructor sets initial supply and assigns it to the deployer
    constructor(uint256 initialSupply) Ownable(msg.sender) {
        totalSupply = initialSupply * 10 ** decimals; // Convert to smallest unit
        balances[msg.sender] = totalSupply; // Give all tokens to deployer
        emit Transfer(address(0), msg.sender, totalSupply); // Log initial mint
    }

    // Transfer BADGE to another address
    function transfer(address to, uint256 amount) public nonReentrant whenNotPaused returns (bool) {
        require(to != address(0), "Cannot transfer to zero address"); // Prevent burns to zero
        require(balances[msg.sender] >= amount, "Insufficient balance"); // Check sender funds
        balances[msg.sender] -= amount; // Deduct from sender
        balances[to] += amount; // Add to recipient
        emit Transfer(msg.sender, to, amount); // Log the transfer
        return true; // Indicate success
    }

    // Approve another address to spend your BADGE
    function approve(address spender, uint256 amount) public whenNotPaused returns (bool) {
        require(spender != address(0), "Invalid spender address"); // Prevent zero approval
        _allowances[msg.sender][spender] = amount; // Set allowance
        emit Approval(msg.sender, spender, amount); // Log approval
        return true; // Indicate success
    }

    // Transfer BADGE on behalf of an owner with approval
    function transferFrom(address from, address to, uint256 amount) public nonReentrant whenNotPaused returns (bool) {
        require(from != address(0), "Cannot transfer from zero address"); // Check sender
        require(to != address(0), "Cannot transfer to zero address"); // Check recipient
        require(balances[from] >= amount, "Insufficient balance"); // Check funds
        require(_allowances[from][msg.sender] >= amount, "Not approved to spend"); // Check allowance
        balances[from] -= amount; // Deduct from sender
        balances[to] += amount; // Add to recipient
        _allowances[from][msg.sender] -= amount; // Reduce allowance
        emit Transfer(from, to, amount); // Log transfer
        return true; // Indicate success
    }

    // Check an address's BADGE balance
    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    // Check how much a spender can use from an owner
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    // Mint new BADGE tokens (only owner)
    function mint(address to, uint256 amount) public onlyOwner whenNotPaused {
        require(to != address(0), "Cannot mint to zero address"); // Prevent zero mint
        totalSupply += amount; // Increase total supply
        balances[to] += amount; // Add to recipient
        emit Transfer(address(0), to, amount); // Log minting
    }

    // Burn BADGE tokens from sender’s balance
    function burn(uint256 amount) public whenNotPaused {
        require(balances[msg.sender] >= amount, "Insufficient balance"); // Check funds
        balances[msg.sender] -= amount; // Deduct from sender
        totalSupply -= amount; // Reduce total supply
        emit Transfer(msg.sender, address(0), amount); // Log burning
    }

    // Burn BADGE on behalf of an owner with approval
    function burnFrom(address from, uint256 amount) public whenNotPaused {
        require(from != address(0), "Cannot burn from zero address"); // Check sender
        require(balances[from] >= amount, "Insufficient balance"); // Check funds
        require(_allowances[from][msg.sender] >= amount, "Not approved to spend"); // Check allowance
        balances[from] -= amount; // Deduct from sender
        totalSupply -= amount; // Reduce total supply
        _allowances[from][msg.sender] -= amount; // Reduce allowance
        emit Transfer(from, address(0), amount); // Log burning
    }

    // Pause all token operations (only owner)
    function pause() public onlyOwner {
        _pause();
    }

    // Resume token operations (only owner)
    function unpause() public onlyOwner {
        _unpause();
    }
}
