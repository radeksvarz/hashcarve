// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title HashCarve
 * @author @radeksvarz (@radk)
 * @notice Gas-optimized, multichain-consistent deployer for content-addressable runtime bytecode.
 *         Suitable for ERC 2535 Diamond facets, other libraries, factories and zero storage contracts.
 * @dev Deployed permissionlessly via CreateX to ensure the same address across all chains.
 *
 * Usage:
 * 1. Calculate and predict the address of your contract based on its raw runtime bytecode using addressOfBytecode().
 * 2. Deploy the contract using carveBytecode(runtimeBytecode).
 *    - No constructor code is executed; the provided bytecode becomes the runtime code.
 *    - The address is deterministically based on the runtime bytecode.
 *    - Multichain consistency is guaranteed if HashCarve is deployed at the same address on all chains.
 */
import {IHashCarve} from "./IHashCarve.sol";

contract HashCarve is IHashCarve {
    /**
     * @dev Micro-constructor (11 bytes)
     * When prepended to runtime bytecode, this prefix deploys the code exactly
     * as provided, bypassing initialization. Compatible with EVM Paris for maximum compatibility.
     *
     * MICRO_CONSTRUCTOR = hex"600B_38_03_80_600B_3D_39_3D_f3"
     *
     * Breakdown:
     * 600b       - PUSH1 0x0B (11) // [constructor size]
     * 38         - CODESIZE // [codesize, constructor size]
     * 03         - SUB (runtime_size = CODESIZE - 11) // [runtime_size]
     * 80         - DUP1 (runtime_size) // [runtime_size, runtime_size]
     * 600b       - PUSH1 0x0b (11) // [constructor size, runtime_size, runtime_size]
     * 3d         - RETURNDATASIZE (destOffset 0x00) // [0x00, constructor size, runtime_size, runtime_size]
     * 39         - CODECOPY (0, 11, runtime_size) // [runtime_size]
     * 3d         - RETURNDATASIZE (destOffset 0x00) // [0x00,runtime_size]
     * f3         - RETURN (offset, size) -> return(0, runtime_size)
     */
    /**
     * @notice Deploys the provided runtime bytecode as a content-addressable contract.
     * @dev The identity (resultant address) is determined by every byte of the input runtimeBytecode array,
     *      including any compiler CBOR metadata if attached by the compiler as of the configuration.
     * @param runtimeBytecode The raw runtime bytecode to deploy.
     * @return addr The address of the deployed contract.
     */
    function carveBytecode(
        bytes calldata runtimeBytecode
    ) external returns (address addr) {
        assembly {
            // Memory layout (deployment payload):
            // [0x00:0x0b] = 11-byte micro-constructor
            // [0x0b:...]  = runtimeBytecode
            mstore(0x00, 0x600B380380600B3D393DF3000000000000000000000000000000000000000000)

            // Copy runtimeBytecode to memory offset 11
            calldatacopy(0x0b, runtimeBytecode.offset, runtimeBytecode.length)

            // value = 0 // no value transfer to the target contract
            // memory pointer = 0
            // size = runtimeBytecode.length + 0x0b (micro_constructor.length)
            // salt = 0
            addr := create2(0, 0, add(0x0b, runtimeBytecode.length), 0)

            // Verify deployment: address must be non-zero, size must be non-zero and match input length.
            let carvedSize := extcodesize(addr)
            if or(iszero(addr), or(iszero(carvedSize), sub(carvedSize, runtimeBytecode.length))) {
                // DeploymentFailed() selector: 0x30116425
                mstore(0x00, 0x30116425)
                revert(0x1c, 0x04)
            }

            // Return addr directly from assembly
            mstore(0x00, addr)
            return(0x00, 0x20)
        }
    }

    /**
     * @notice Predicts the address of a contract deployed with the given runtime bytecode.
     * @dev The identity (resultant address) is determined by every byte of the input runtimeBytecode array,
     *      including any compiler CBOR metadata if attached by the compiler as of the configuration.
     * @param runtimeBytecode The raw runtime bytecode.
     * @return addr The predicted deterministic CREATE2 address.
     */
    function addressOfBytecode(
        bytes calldata runtimeBytecode
    ) external view returns (address) {
        assembly {
            // 1. Calculate initcode hash: keccak256(MICRO_CONSTRUCTOR ++ runtimeBytecode)
            // Store MICRO_CONSTRUCTOR (11 bytes) at memory 0
            mstore(0x00, 0x600B380380600B3D393DF3000000000000000000000000000000000000000000)
            calldatacopy(0x0b, runtimeBytecode.offset, runtimeBytecode.length)
            let initcodeHash := keccak256(0x00, add(0x0b, runtimeBytecode.length))

            // 2. Prepare CREATE2 calculation buffer (85 bytes)
            // Layout:
            // [0x00:0x01] 0xff
            // [0x01:0x15] address(this) (20 bytes)
            // [0x15:0x35] 0x00 salt (32 bytes)
            // [0x35:0x55] initcodeHash (32 bytes)
            mstore8(0x00, 0xff)
            mstore(0x01, shl(96, address()))
            mstore(0x15, 0)
            mstore(0x35, initcodeHash)

            // Compute final address, store at 0x00 and return
            mstore(0x00, and(keccak256(0x00, 85), 0xffffffffffffffffffffffffffffffffffffffff))
            return(0x00, 0x20)
        }
    }
}
