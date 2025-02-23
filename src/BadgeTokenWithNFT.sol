// SPDX-License-Identifier: GPL-3.0 OR MIT
pragma solidity ^0.8.27;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "../lib/openzeppelin-contracts/contracts/utils/Pausable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./IBadgeToken.sol";

// Interface for validator reward distribution
interface IValidatorContract {
    function distributeValidatorReward(address miner, uint256 amount) external;
}

// NFT-based mining game with staking and rewards
contract BadgeTokenWithNFT is ERC721URIStorage, Ownable, ReentrancyGuard, Pausable {
    uint256 public nextTokenId = 1; // Next NFT ID to mint
    uint256 public maxSupply = 5555; // Maximum NFTs allowed
    uint256 public miningReward = 2 * 10 ** 18; // Reward per successful mine (2 BADGE)
    uint256 public miningCooldown = 1 hours; // Time between mining attempts
    uint256 public upgradeCost = 5 * 10 ** 18; // Cost to upgrade NFT (5 BADGE)
    uint256 public weeklyAttempts = 50; // Attempts per week after staking
    uint256 public difficulty = 100; // Base mining difficulty, increases over time

    IBadgeToken public badgeToken; // BADGE token contract
    IValidatorContract public validatorContract; // Validator contract for reward distribution

    // Player data mappings
    mapping(address => uint256[]) public stakedNFTs; // NFTs staked by each player
    mapping(uint256 => uint256) public miningPower; // Power of each NFT
    mapping(address => uint256) public totalStakedPower; // Total power of staked NFTs per player
    mapping(address => uint256) public lastMiningTime; // Last mining attempt time
    mapping(address => uint256) public leaderboard; // Mining success leaderboard
    mapping(address => uint256) public ethStaked; // Staked ETH converted to BADGE (in wei-like units)
    mapping(address => uint256) public stakeStartTime; // When staking began
    mapping(address => uint256) public attemptsLeft; // Remaining weekly attempts

    // Events for game actions
    event NFTMinted(address indexed to, uint256 indexed tokenId, string tokenURI, uint256 power);
    event NFTStaked(address indexed user, uint256 indexed tokenId);
    event NFTUnstaked(address indexed user, uint256 indexed tokenId);
    event BlockMined(address indexed miner, uint256 indexed tokenId, uint256 reward);
    event NFTUpgraded(uint256 indexed tokenId, uint256 newPower);
    event ETHStaked(address indexed user, uint256 ethAmount, uint256 badgeAmount);

    // Constructor links BADGE and Validator contracts
    constructor(address badgeTokenAddress, address validatorContractAddress)
        ERC721("Honey Badger NFT", "HBN")
        Ownable(msg.sender)
    {
        require(badgeTokenAddress != address(0), "Invalid BadgeToken address");
        require(validatorContractAddress != address(0), "Invalid ValidatorContract address");
        badgeToken = IBadgeToken(badgeTokenAddress);
        validatorContract = IValidatorContract(validatorContractAddress);
    }

    // Stake ETH to play, converting to BADGE with proper decimal scaling
    function stakeETH() public payable whenNotPaused {
        require(
            stakeStartTime[msg.sender] == 0 || block.timestamp >= stakeStartTime[msg.sender] + 8 days,
            "Stake still active"
        );
        uint256 requiredEth = _getStakeAmount(msg.sender);
        require(msg.value >= requiredEth, "Insufficient ETH staked");

        // Convert ETH to BADGE: 1 ETH = 10,000 BADGE, scaled to 18 decimals
        uint256 badgeAmount = (msg.value * 10000 * 10 ** 18) / 1 ether;
        ethStaked[msg.sender] = badgeAmount; // Store in wei-like units
        stakeStartTime[msg.sender] = block.timestamp;
        attemptsLeft[msg.sender] = weeklyAttempts;
        emit ETHStaked(msg.sender, msg.value, badgeAmount);
    }

    // Unstake BADGE after 8-day lock
    function unstakeETH() public whenNotPaused {
        require(stakeStartTime[msg.sender] > 0, "No active stake");
        require(block.timestamp >= stakeStartTime[msg.sender] + 8 days, "Stake locked");
        uint256 badgeAmount = ethStaked[msg.sender];
        require(badgeToken.transfer(msg.sender, badgeAmount), "Transfer failed");
        ethStaked[msg.sender] = 0;
        stakeStartTime[msg.sender] = 0;
        attemptsLeft[msg.sender] = 0;
    }

    // Mint a new NFT (only owner)
    function mintNFT(address to, string memory tokenURI, uint256 power) public onlyOwner nonReentrant whenNotPaused {
        require(to != address(0), "Cannot mint to zero address");
        require(bytes(tokenURI).length > 0, "Token URI cannot be empty");
        require(nextTokenId <= maxSupply, "Max supply reached");
        require(power > 0 && power <= 100, "Power must be between 1 and 100");

        _safeMint(to, nextTokenId);
        _setTokenURI(nextTokenId, tokenURI);
        miningPower[nextTokenId] = power;
        emit NFTMinted(to, nextTokenId, tokenURI, power);
        nextTokenId++;
    }

    // Stake an NFT to boost mining power
    function stakeNFT(uint256 tokenId) public nonReentrant whenNotPaused {
        require(ownerOf(tokenId) == msg.sender, "You do not own this NFT");
        _transfer(msg.sender, address(this), tokenId);
        stakedNFTs[msg.sender].push(tokenId);
        totalStakedPower[msg.sender] += miningPower[tokenId];
        emit NFTStaked(msg.sender, tokenId);
    }

    // Unstake an NFT
    function unstakeNFT(uint256 tokenId) public nonReentrant whenNotPaused {
        require(ownerOf(tokenId) == address(this), "NFT is not staked");
        require(stakedNFTs[msg.sender].length > 0, "No staked NFTs found");
        _transfer(address(this), msg.sender, tokenId);
        totalStakedPower[msg.sender] -= miningPower[tokenId];
        _removeStakedNFT(msg.sender, tokenId);
        emit NFTUnstaked(msg.sender, tokenId);
    }

    // Attempt to mine a block for rewards
    function mineBlock() public nonReentrant whenNotPaused {
        require(attemptsLeft[msg.sender] > 0, "No attempts left");
        require(ethStaked[msg.sender] > 0, "Must stake ETH to play");
        require(block.timestamp >= lastMiningTime[msg.sender] + miningCooldown, "Mining cooldown active");

        uint256[] memory staked = stakedNFTs[msg.sender];
        require(staked.length > 0, "No staked NFTs found");

        uint256 totalPower = totalStakedPower[msg.sender];
        uint256 blockHash = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender)));
        difficulty += totalPower / 1000;

        lastMiningTime[msg.sender] = block.timestamp;
        attemptsLeft[msg.sender]--;

        if (blockHash % difficulty < totalPower) {
            require(badgeToken.balanceOf(address(this)) >= miningReward, "Insufficient reward balance");
            uint256 minerReward = miningReward * 60 / 100;
            uint256 validatorReward = miningReward * 30 / 100;
            uint256 delegatorReward = miningReward * 10 / 100;
            badgeToken.transfer(msg.sender, minerReward);
            validatorContract.distributeValidatorReward(msg.sender, validatorReward + delegatorReward);
            leaderboard[msg.sender] += miningReward;
            emit BlockMined(msg.sender, staked[0], miningReward);
        }
    }

    // Upgrade an NFT’s mining power by 10, costing 5 BADGE
    function upgradeNFT(uint256 tokenId) public nonReentrant whenNotPaused {
        address currentOwner = ownerOf(tokenId); // Check existence via ownerOf
        require(miningPower[tokenId] + 10 <= 100, "Power cannot exceed 100");
        require(badgeToken.transferFrom(msg.sender, address(this), upgradeCost), "Upgrade fee transfer failed");

        bool isStaked = currentOwner == address(this);

        if (isStaked) {
            for (uint256 i = 0; i < stakedNFTs[msg.sender].length; i++) {
                if (stakedNFTs[msg.sender][i] == tokenId) {
                    totalStakedPower[msg.sender] += 10;
                    break;
                }
            }
        }

        miningPower[tokenId] += 10;
        emit NFTUpgraded(tokenId, miningPower[tokenId]);
    }

    // Internal function to remove staked NFT
    function _removeStakedNFT(address user, uint256 tokenId) internal {
        uint256[] storage staked = stakedNFTs[user];
        for (uint256 i = 0; i < staked.length; i++) {
            if (staked[i] == tokenId) {
                staked[i] = staked[staked.length - 1];
                staked.pop();
                return;
            }
        }
        revert("Token ID not found in staked list");
    }

    // Internal function to determine required ETH stake based on NFT ownership
    function _getStakeAmount(address user) internal view returns (uint256) {
        for (uint256 i = 1; i < nextTokenId; i++) {
            if (ownerOf(i) == user) {
                return miningPower[i] > 75 ? 0.01 ether : 0.025 ether;
            }
        }
        return 0.05 ether;
    }

    // Pause game operations
    function pause() public onlyOwner {
        _pause();
    }

    // Resume game operations
    function unpause() public onlyOwner {
        _unpause();
    }

    // View staked NFTs for a player
    function getStakedNFTs(address user) public view returns (uint256[] memory) {
        return stakedNFTs[user];
    }
}
