# Arenaton Smart Contracts

## Introduction

This repository hosts the Arenaton Smart Contracts, designed for our decentralized betting platform built on the Ethereum blockchain. The smart contracts facilitate a transparent, secure, and fair betting system using a Parimutuel model, comprehensive NFT integration, and sophisticated stablecoin mechanics.
Features

- Parimutuel Betting System: Bets are pooled together, with dynamically adjusting odds based on collective stakes.
- Commission Sharing: Incentivizes token holders by distributing a portion of platform earnings.
- NFT Integration: Enhances user engagement through staking mechanisms and rewards.
- Stablecoin Mechanics: Ensures smooth and secure transaction processes within the platform.

## Prerequisites

    Foundry
    Solidity 0.8.x or higher

## Setup

To set up and run this project, follow these steps:
Installing Foundry

Foundry is a fast, portable, and modular toolkit for Ethereum application development written in Rust. Install Foundry using the following command:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

## Cloning the Repository

```bash

git clone https://github.com/XelHaku/arenaton-smart-contracts.git
cd arenaton-smart-contracts
```

## Installing Dependencies

Foundry uses forge to manage Solidity projects. Initialize your project (if necessary) and install any dependencies:

```bash

forge init
forge install
```

Building and Testing

Compile the smart contracts and run tests to ensure everything is working correctly:

```bash

forge build
forge test
```

## Usage

After setting up the project, you can deploy the contracts to a local testnet or live network using:

```bash

forge create --rpc-url <RPC_URL> src/Contract.sol:ContractName
```

Replace <RPC_URL> with your Ethereum node's URL and ContractName with the actual contract name.
Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are greatly appreciated.

```
    Fork the Project
    Create your Feature Branch (git checkout -b feature/YourAmazingFeature)
    Commit your Changes (git commit -m 'Add some AmazingFeature')
    Push to the Branch (git push origin feature/YourAmazingFeature)
    Open a Pull Request
```

## License

Distributed under the GPL-3.0 License. See LICENSE for more information.

Contact

```
    Juan Tamez - juantamez@arenaton.com
   https://github.com/XelHaku/arenaton-smart-contracts
```
