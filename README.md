# MiningSimulationGameV2

A blockchain-based simulation game ecosystem built on Ethereum with Solidity 0.8.27 and Foundry. Players stake ETH weekly to mine BADGE rewards using NFTs, with validators and delegators sharing profits. Funded by a 5,555 NFT launch at 0.05555 ETH each (~$693,000), it aims for a sustainable $10,000+ daily surplus.

## Project Structure

- **src/**: Contracts
  - `IBadgeToken.sol`: Shared BADGE interface.
  - `BadgeToken.sol`: ERC-20 token for rewards/transactions.
  - `BadgeTokenWithNFT.sol`: NFT staking/mining game.
  - `ValidatorContract.sol`: Validator staking/reward distribution.
  - `DelegatorContract.sol`: Passive BADGE delegation.
  - `TransactionContract.sol`: BADGE transactions with fees.
- **test/**: Test files (to be added).

## Setup Instructions

### Prerequisites

- **Node.js**: Install from [nodejs.org](https://nodejs.org/).
- **Git**: Verify with `git --version`.
- **VS Code**: Install with Solidity extension (`JuanBlanco.solidity`).
- **Foundry**: Install via `curl -L https://foundry.paradigm.xyz | bash` then `foundryup`.

### Installation

```bash
# Clone repository
git clone <your-repo-url>
cd MiningSimulationGameV2

# Install dependencies
forge install OpenZeppelin/openzeppelin-contracts@v5.0.2 --no-commit
forge install foundry-rs/forge-std@v1.9.2 --no-commit.
