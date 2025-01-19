# Foundry Account Generator & Activity Simulator

Foundry-based toolkit for deterministic account generation and transaction simulation.

## Features

- Deterministic account generation (n accounts)
- Chain-aware key derivation
- Fund distribution and consolidation
- Transaction simulation with temporal variance
- Output and export account keys for future usage

## Installation

```bash
git clone https://github.com/0xkieranwilliams/foundry-account-generator-and-activity-producer.git
cd foundry-account-generator-and-activity-producer

# Install dependencies
make install

# Setup environment
cp .env.example .env
```

Required `.env` configuration:
```bash
MASTER_KEY=                          # Root private key
CONSOLIDATION_TARGET=                # Consolidation address
RPC_URL=                             # RPC endpoint

# Script Paramater Configuration
ACCOUNTS_COUNT=50                    # number of accounts to create and have interact
MIN_TRANSFER=10000000000000000       # 0.01 ether in wei
ACTIVITY_ROUNDS=5                    # number of interaction rounds per account
```

## Usage

Generate accounts and export keys:
```bash
# Generate accounts
make gen-accounts

# Export all credentials as JSON
make export-keys    # -> accounts.json

# Export only private keys
make list-keys     # -> private_keys.txt
```

Fund management:
```bash
make distribute    # Distribute initial funds
make simulate     # Run transaction simulation
make consolidate  # Consolidate to target address
```

## Implementation Details

Core parameters:
```solidity
ACCOUNTS_COUNT = 50;        // Number of accounts
MIN_TRANSFER = 0.01 ether;  // Base transfer amount
ACTIVITY_ROUNDS = 5;        // Simulation rounds
```

Key derivation:
```solidity
bytes32 masterSeed = keccak256(abi.encodePacked(masterKey, block.chainid));
uint256 privateKey = uint256(keccak256(abi.encodePacked(masterSeed, i)));
```

## Output Formats

accounts.json:
```json
[
  {
    "index": 0,
    "address": "0x...",
    "privateKey": "0x..."
  }
]
```

private_keys.txt:
```
0x1234...
0x5678...
```

## Commands

```bash
make install         # Install dependencies
make build          # Compile contracts
make gen-accounts   # Generate accounts
make distribute     # Distribute funds
make simulate       # Run simulation
make consolidate    # Consolidate funds
make export-keys    # Export JSON credentials
make list-keys      # Extract private keys
```

## Dependencies

- Foundry (latest)
- Solidity ^0.8.19
- forge-std

## License

MIT
