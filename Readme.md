## Cairo FlashLoan Starknet

Flash loan which Implements EIP-7399 interface in which borrower smart contract borrow some amount from Lender smart contract with a condition such that amount is returned to lender contract with an additional fee charged by the lender contract

## Table of Contents

- [About](#-about)
- [Getting Started](#-getting-started)
  - [Dependencies](#dependencies)
- [Usage](#-usage)
  - [Runinng the Project](#running-the-project)
  - [Running Scarb from the CLI](#running-scarb-from-cli)
  - [Testing](#testing)
- [Documentation](#-documentation)
- [License](#%EF%B8%8F-license)

## 📖 About

A flash loan is a smart contract transaction in which a lender smart contract lends assets to a borrower smart contract with the condition that the assets are returned, plus an optional fee, before the end of the transaction.

This repository use the 0.8.0 version of [openzepplin docs](https://docs.openzeppelin.com/contracts-cairo/0.8.0/) and uses EIP-7399 standard which is wrapper for EIP-3156 Flash loan

## 🌅 Getting Started

### Dependencies

#### Required

These are needed in order to compile and use the project.

- [scarb 2.3.1](https://docs.swmansion.com/scarb/docs.html#installation)
- [cairo 2.3.1](https://book.cairo-lang.org/title-page.html)
- sierra 1.3.0

### Installing project dependencies

Cairo can be installed by simply downloading Scarb. Scarb bundles the Cairo compiler and the Cairo language server together in an easy-to-install package so that you can start writing Cairo code right away.

This will install the latest stable release of Scarb.

```bash
. curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh
```

We strongly recommend that you install Scarb via [asdf](https://docs.swmansion.com/scarb/download.html#install-via-asdf), a CLI tool that can manage multiple language runtime versions on a per-project basis.
This will ensure that the version of Scarb you use to work on a project always matches the one defined in the project settings, avoiding problems lead to version mismatch.

## 🚀 Usage

### Running the project

You can add the following to your Sacrb project's `Scarb.toml`:

```toml
openzeppelin = { git = "https://github.com/aerius-labs/cairo-flash-loan/" }
starknet = "2.3.1"
[[target.starknet-contract]]
casm = true
```

This will add the openzepplin documnetation in our scarb Project and [[target.starknet-contract]] is used to target the starknet contract.

### Running Scarb from CLI

To run Project from the command line, first compile the repository using Scarb:

```bash
scarb build
```

This will create a target/dev folder which later use for deployment of the contracts

### Testing

## 📚 Documentation

- Cairo Documentation: [Cairo docs](https://book.cairo-lang.org/title-page.html)
- Scarb Documentation: [Scarb](https://docs.swmansion.com/scarb/docs.html#installation)
- openzepplin Documentation: [openzepplin docs](https://docs.openzeppelin.com/contracts-cairo/0.8.0/)
- EIP-7399 Pull Request: [EIP-7399](https://github.com/ethereum/EIPs/pull/7400)
- ERC-3156: Flash Loans: [EIP-3156](https://eips.ethereum.org/EIPS/eip-3156)

## ⚖️ License
