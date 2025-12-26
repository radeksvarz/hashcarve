// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {HashCarve} from "../src/HashCarve.sol";

/**
 * @title ICreateX
 * @notice Mini-interface for CreateX factory.
 */
interface ICreateX {
    /**
     * @dev Deploys a contract using CREATE2.
     * @param magic_salt The magic_salt for the contract deployment.
     * @param initCode The initialization code of the contract to be deployed.
     * @return newContract The address of the deployed contract.
     */
    function deployCreate2(
        bytes32 magic_salt,
        bytes calldata initCode
    ) external payable returns (address newContract);

    /**
     * @dev Computes the address of a contract deployed using CREATE2.
     * @param magic_salt The magic_salt for the contract deployment.
     * @param initCodeHash The hash of the initialization code of the contract to be deployed.
     * @return predictedAddress The address of the deployed contract.
     */
    function computeCreate2Address(
        bytes32 magic_salt,
        bytes32 initCodeHash
    ) external view returns (address predictedAddress);
}

/**
 * @title DeployHashCarve
 * @notice Forge script to anchor the HashCarve factory at a consistent address across EVM chains using CreateX.
 */
contract DeployHashCarve is Script {
    /**
     * @dev Canonical CreateX address (SkyLab/pcaversaccio implementation).
     * Source: https://github.com/pcaversaccio/CreateX
     */
    address public constant CREATEX_ADDRESS = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;

    function run() public returns (address hashCarve) {
        // 1. Audit Environment Configuration
        _auditConfiguration();

        // 2. Prepare deployment data
        bytes memory initCode = type(HashCarve).creationCode;
        bytes32 magic_salt = keccak256("MEGVA071315");
        bytes32 initCodeHash = keccak256(initCode);

        // 3. Address Prediction
        address predicted = ICreateX(CREATEX_ADDRESS).computeCreate2Address(magic_salt, initCodeHash);

        console2.log("------------------------------------------------------------------");
        console2.log("HashCarve Deployment Script");
        console2.log("Chain ID:                   ", block.chainid);
        console2.log("CreateX factory:            ", CREATEX_ADDRESS);
        console2.log("HashCarve predicted address:", predicted);
        console2.log("------------------------------------------------------------------");

        if (predicted.code.length > 0) {
            console2.log("HashCarve already deployed at predicted address. Skipping.");
            return predicted;
        } else {
            console2.log("HashCarve not found at predicted address. Initiating deployment...");
            vm.startBroadcast();
            hashCarve = ICreateX(CREATEX_ADDRESS).deployCreate2(magic_salt, initCode);
            vm.stopBroadcast();

            if (hashCarve != predicted) {
                revert("Deployment address mismatch: resulting address does not match predicted address");
            }
            console2.log("Successfully deployed HashCarve to:", hashCarve);
        }

        // 4. Post-Deploy Smoke Test
        _smokeTest(hashCarve);

        console2.log("------------------------------------------------------------------");
        console2.log("Deployment and validation sequence completed successfully.");
        return hashCarve;
    }

    /**
     * @dev Validates the compiler and environment settings to ensure strict determinism.
     */
    function _auditConfiguration() internal view {
        // Read foundry.toml to verify settings
        // Note: fs_permissions must allow reading the root directory.
        string memory config = vm.readFile("foundry.toml");

        // Verify bytecode_hash = "none"
        if (!_contains(config, 'bytecode_hash = "none"')) {
            revert("Audit Failed: bytecode_hash must be explicitly set to 'none' in foundry.toml");
        }
        // Verify cbor_metadata = false
        if (!_contains(config, "cbor_metadata = false")) {
            revert("Audit Failed: cbor_metadata must be explicitly set to false in foundry.toml");
        }
        // Verify via_ir = true
        if (!_contains(config, "via_ir = true")) {
            revert("Audit Failed: via_ir must be explicitly set to true in foundry.toml");
        }
        // Verify Solc Version (0.8.33)
        if (!_contains(config, 'solc_version = "0.8.33"')) {
            revert("Audit Failed: solc_version must be explicitly set to '0.8.33' in foundry.toml");
        }

        // Verify HashCarve.sol pragma version
        string memory source = vm.readFile("src/HashCarve.sol");
        if (!_contains(source, "pragma solidity 0.8.33;")) {
            revert("Audit Failed: src/HashCarve.sol must use 'pragma solidity 0.8.33;'");
        }
    }

    /**
     * @dev Smoke test for the deployed HashCarve instance.
     */
    function _smokeTest(
        address hashCarve
    ) internal {
        // Confirm code existence at the target address
        require(hashCarve.code.length > 0, "Smoke Test Failed: Target address has no bytecode");

        // Verify the code at the address matches the expected runtime result.
        // For HashCarve, we compare against the local build's runtime bytecode.
        bytes memory expectedRuntime = type(HashCarve).runtimeCode;
        if (keccak256(hashCarve.code) != keccak256(expectedRuntime)) {
            revert("Smoke Test Failed: Bytecode integrity mismatch at target address");
        }

        // Call addressOfBytecode to ensure the logic (specifically the micro-constructor related computation) is
        // functional. We use a simple payload (STOP instruction) for testing.
        bytes memory testPayload = hex"00";
        try HashCarve(hashCarve).addressOfBytecode(testPayload) returns (address p) {
            console2.log('Smoke Test: addressOfBytecode(hex"00") returned:', p);

            // Manual calculation for comparison
            bytes memory microConstructor = hex"600B380380600B3D393DF3";
            bytes memory initCode = abi.encodePacked(microConstructor, testPayload);
            bytes32 initCodeHash = keccak256(initCode);
            address predicted = address(
                uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), hashCarve, bytes32(0), initCodeHash))))
            );

            console2.log("Smoke Test: Manual prediction address:  ", predicted);

            require(p == predicted, "Smoke Test Failed: addressOfBytecode result mismatch with manual calculation");
            require(p != address(0), "Smoke Test Failed: addressOfBytecode returned zero address");
            console2.log("Smoke Test: addressOfBytecode() functional test passed.");
        } catch {
            revert("Smoke Test Failed: call to addressOfBytecode() reverted");
        }
    }

    /**
     * @dev Internal helper for string searching within the config file.
     */
    function _contains(
        string memory haystack,
        string memory needle
    ) internal pure returns (bool) {
        return vm.indexOf(haystack, needle) != type(uint256).max;
    }
}
