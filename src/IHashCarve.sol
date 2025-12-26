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
     * @param runtimeBytecode The raw runtime bytecode to deploy.
     * @return addr The address of the deployed contract.
     */
    function carve(
        bytes calldata runtimeBytecode
    ) external returns (address addr);

    /**
     * @notice Predicts the address of a contract deployed with the given runtime bytecode.
     * @param runtimeBytecode The raw runtime bytecode.
     * @return addr The predicted deterministic address.
     */
    function addressOf(
        bytes calldata runtimeBytecode
    ) external view returns (address addr);
}
