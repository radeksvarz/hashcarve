// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/**
 * @title IHashCarve
 * @author @radeksvarz (@radk)
 * @notice Interface for HashCarve, a gas-optimized, multichain-consistent deployer for content-addressable runtime
 * bytecode.
 */
interface IHashCarve {
    /**
     * @notice Thrown when the deployment of the contract fails.
     *         Possible reasons: salt collision, invalid bytecode, etc.
     */
    error DeploymentFailed();

    /**
     * @notice Deploys the provided runtime bytecode as a content-addressable contract.
     * @dev The identity (resultant address) is determined by every byte of the input runtimeBytecode array,
     *      including any compiler CBOR metadata if attached by the compiler as of the configuration.
     * @param runtimeBytecode The raw runtime bytecode to deploy.
     * @return addr The address of the deployed contract.
     */
    function carveBytecode(
        bytes calldata runtimeBytecode
    ) external returns (address addr);

    /**
     * @notice Predicts the address of a contract deployed with the given runtime bytecode.
     * @dev The identity (resultant address) is determined by every byte of the input runtimeBytecode array,
     *      including any compiler CBOR metadata if attached by the compiler as of the configuration.
     * @param runtimeBytecode The raw runtime bytecode.
     * @return addr The predicted deterministic address.
     */
    function addressOfBytecode(
        bytes calldata runtimeBytecode
    ) external view returns (address addr);

    /**
     * @notice Checks if the contract at address target was deployed via HashCarve.
     * @dev Bytecode Identity Validation: This verifies that the code at `target` matches the
     *      content-addressable derivation from its own runtime bytecode + HashCarve micro-constructor.
     *      NOTE: This is NOT "Source Code Verification" (like Etherscan). It validates the *origin* and *integrity*
     *      of the deployed bytecode, not the Solidity source.
     * @param target The address to check.
     * @return true if the contract at target address was deployed via HashCarve.
     */
    function isCarved(
        address target
    ) external view returns (bool);
}
