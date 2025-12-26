# HashCarve

**HashCarve** is a gas-optimized, multichain-consistent deployer designed for **content-addressable runtime bytecode**.

By utilizing a deterministic "micro-constructor" wrapper, HashCarve ensures that a contract's address is a direct cryptographic commitment to its runtime logic, bypassing the variability of traditional Solidity initialization.

## Motivation

Traditional EVM deployment via `CREATE` or `CREATE2` relies on **initcode**. This code is executed once to produce the **runtime bytecode** that eventually lives on-chain. This introduces several "black box" variables:

1. **Constructor Logic:** Different constructor arguments or internal state changes during initialization can result in different addresses for the same logic.
2. **Compiler Metadata:** Minor differences in compiler versions or optimization settings change the initcode hash, breaking cross-chain determinism.
3. **Entropy:** The need for a manually managed `salt` in `CREATE2` is not relevant for content-addressable contracts, where the identifier is the code itself.

**HashCarve** flips this. It uses the **Runtime Bytecode as the Source of Truth**. The address is derived solely from the logic itself, making code truly content-addressable across any EVM-compatible network.

This shifts the paradigm toward **maximum reusability**. By ensuring that identical logic always lives at the same address, multiple projects can reuse the same deployed bytecode. This naturally enhances security, as common facets and libraries accumulate history, trust, and public audits over time.

## TLDR How to Use

Use **HashCarve** in your deployment scripts:

* **Foundry:** [Foundry deployment script](#1-with-foundry)
* **Hardhat:** [Hardhat deployment script](#2-with-hardhat)

## Key Features

* **Pure Determinism:** `Target contract address = f(RuntimeBytecode ++ constants)`. No user salts, no constructor arguments, no hidden state.
* **Multichain Consistency:** Designed to be deployed via [CreateX](https://github.com/pcaversaccio/createx) at a fixed address. This follows the CreateX philosophy of **extensibility**, where the system can be used to deploy other types of deterministic deployer factories like **HashCarve**, ensuring consistent logic across every chain.
* **Diamond-Ready:** Optimized for [EIP-2535 Diamond Facets](https://eips.ethereum.org/EIPS/eip-2535). Since facets are stateless logic providers, they are the perfect candidate for content-addressing.
* **Gas Efficient:** Uses a minimal Yul-based micro-constructor to minimize deployment overhead.

### Compatibility

The target EVM version for **HashCarve** compilation is set to **Paris**. Neither the contract creation bytecode of HashCarve nor the returned runtime bytecode contains a `PUSH0` instruction, ensuring maximum usability and compatibility among EVM-compatible chains.

## HashCarve in the Diamond Context

In the [EIP-2535 Diamond Standard](https://eips.ethereum.org/EIPS/eip-2535), facets are often stateless logic providers. Traditionally, managing facet addresses across multiple chains can be cumbersome.

Saying **"I'm using HashCarve to deploy the facets"** carries a profound architectural implication: **facets are pointable and addressable by the hash of their bytecode.**

This property transforms how Diamonds are managed:

*   **Logical Immutability:** A facet at a HashCarve address is guaranteed to contain exactly the logic defined by its hash.
*   **Canonical Facets:** The community can converge on "canonical" facet addresses for common logic (e.g., Ownership, DiamondLoupe), as the address will be identical for everyone using HashCarve on any chain.
*   **Verification by Hash:** Users can verify the logic of a Diamond simply by checking if the facet addresses match the expected HashCarve derivation of the source code.

## Technical Specification

### The Formula

The deployment address is calculated using the CREATE2 opcode:

```
Address = keccak256(
    0xff ++ 
    HashCarveAddress ++ 
    0x0000000000000000000000000000000000000000000000000000000000000000 ++ 
    keccak256(MICRO_CONSTRUCTOR ++ RuntimeBytecode)
)[12:]
```
Where the **MicroConstructor** is a constant 11-byte sequence that returns the appended runtime bytecode.

### Related Discussions

* **EIP Discussion:** [Deterministic Pure Runtime Bytecode Deployment](https://ethereum-magicians.org/t/eip-potential-proposal-deterministic-pure-runtime-bytecode-deployment/23070)
* **EIP-2535:** [Diamond Standard](https://eips.ethereum.org/EIPS/eip-2535)

---

## Security Warnings ⚠️

### 1. No Initialization

**HashCarve** bypasses the Solidity constructor. This means:

* **Immutable variables** cannot be set at deployment time.
* The `constructor` block in your Solidity source will **not** be executed.
* Internal state variables cannot be initialized during deployment.
**Solution:** Use the `initializer` pattern (e.g., OpenZeppelin Initializable) if the contract requires state setup, though this is discouraged for pure Diamond facets.

### 2. Static Analysis Bypass

Because the code is deployed as raw bytecode, some basic block explorers or security scanners might fail to automatically link the source code unless the runtime bytecode matches the compiled output of the source exactly (metadata stripped).

### 3. Non-Standard Deployment

Ensure the runtime bytecode provided is valid and includes a proper `STOP` or `REVERT` sequence. Deploying "junk" data is possible but will result in a broken contract address that cannot be interacted with.

---

## Usage

### 1. With Foundry

Foundry users can interact with HashCarve directly using Solidity scripts or tests.

```solidity
import {console} from "forge-std/console.sol";

interface IHashCarve {
    error DeploymentFailed();
    function carve(bytes calldata runtimeBytecode) external returns (address addr);
    function addressOf(bytes calldata runtimeBytecode) external view returns (address addr);
}

contract DeployScript {
    // HashCarve canonical address (once deployed)
    IHashCarve constant HASH_CARVE = IHashCarve(0x...);

    function run() external {
        // Check if HashCarve is deployed on this chain (checking bytecode integrity)
        // Note: Hash depends on compiler version 0.8.33 and specific settings
        bytes32 expectedHash = 0x9c2d10f8df8ac735f1a284a7d811205bdaffb2776b944ffb28bca38b6c71ab01;
        if (address(HASH_CARVE).codehash != expectedHash) {
            revert("HashCarve not found at expected address or bytecode mismatch. Please deploy it first.");
        }

        // Use .runtimeCode for the code that should live on-chain
        bytes memory runtimeBytecode = type(MyContract).runtimeCode;

        // Predict address
        address predicted = HASH_CARVE.addressOf(runtimeBytecode);

        // Deploy if not already present
        if (predicted.code.length == 0) {
            address deployed = HASH_CARVE.carve(runtimeBytecode);
            console.log(
                string.concat("Deployed to: ", vm.toString(deployed), " hash: ", vm.toString(deployed.codehash))
            );
        } else {
            console.log(
                string.concat(
                    "Already deployed at: ", vm.toString(predicted), " hash: ", vm.toString(predicted.codehash)
                )
            );
        }
    }
}
```

### 2. With Hardhat

In Hardhat, you can use `ethers.js` to interact with the factory. Ensure you are using the **runtime** bytecode (also known as `deployedBytecode` in Hardhat/Truffle artifacts).

```javascript
const { ethers } = require("hardhat");

async function main() {
  const hashCarveAddress = "0x..."; // HashCarve canonical address
  const hashCarve = await ethers.getContractAt("IHashCarve", hashCarveAddress);

  // Check if HashCarve is deployed on this chain (checking bytecode integrity)
  const expectedHash = "0x9c2d10f8df8ac735f1a284a7d811205bdaffb2776b944ffb28bca38b6c71ab01";
  const factoryCode = await ethers.provider.getCode(hashCarveAddress);
  if (ethers.keccak256(factoryCode) !== expectedHash) {
    throw new Error("HashCarve not found at expected address or bytecode mismatch.");
  }

  // Read the artifact of the contract you want to deploy
  const artifact = await artifacts.readArtifact("MyContract");
  const runtimeBytecode = artifact.deployedBytecode;

  // Predict
  const predicted = await hashCarve.addressOf(runtimeBytecode);

  // Check if deployed
  const code = await ethers.provider.getCode(predicted);
  if (code === "0x") {
    const tx = await hashCarve.carve(runtimeBytecode);
    await tx.wait();
    const finalCode = await ethers.provider.getCode(predicted);
    console.log(`Deployed to: ${predicted} hash: ${ethers.keccak256(finalCode)}`);
  } else {
    console.log(`Already deployed at: ${predicted} hash: ${ethers.keccak256(code)}`);
  }
}
```

## License

[MIT](https://www.google.com/search?q=LICENSE)

---

Created with love by **BeerFi Prague** web3 builders community 🍻
