// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {DeployHashCarve} from "../../script/DeployHashCarve.s.sol";
import {HashCarve} from "../../src/HashCarve.sol";

/**
 * @title MockCreateX
 * @notice A minimal mock of CreateX to facilitate deployment script testing.
 */
contract MockCreateX {
    /**
     * @dev Deploys a contract using CREATE2.
     */
    function deployCreate2(
        bytes32 salt,
        bytes calldata initCode
    ) external payable returns (address newContract) {
        bytes memory code = initCode;
        assembly {
            newContract := create2(callvalue(), add(code, 0x20), mload(code), salt)
        }
        require(newContract != address(0), "MockCreateX: deployment failed");
    }

    /**
     * @dev Computes the address of a contract deployed using CREATE2.
     */
    function computeCreate2Address(
        bytes32 salt,
        bytes32 initCodeHash
    ) external view returns (address predictedAddress) {
        predictedAddress =
            address(uint160(uint256(keccak256(abi.encodePacked(hex"ff", address(this), salt, initCodeHash)))));
    }
}

/**
 * @title DeployHashCarveTest
 * @notice Integration tests for the DeployHashCarve deployment script.
 */
contract DeployHashCarveTest is Test {
    DeployHashCarve public deployer;
    address public constant CREATEX_ADDRESS = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;

    function setUp() public {
        // Instantiate the script
        deployer = new DeployHashCarve();

        // Deploy the MockCreateX at the canonical address
        MockCreateX mockCreateX = new MockCreateX();
        vm.etch(CREATEX_ADDRESS, address(mockCreateX).code);

        // Ensure we are in a clean state (no code at predicted address)
        // (Actually, the script handles the 'already deployed' case, but for a fresh test we want clean)
    }

    function test_ScriptDeploymentIntegration() public {
        // Execute the script
        // Note: vm.broadcast() in the script will be ignored in the test environment (local simulation)
        address hashCarveAddress = deployer.run();

        // 1. Verify Deployment
        assertTrue(hashCarveAddress != address(0), "HashCarve address should not be zero");
        assertTrue(hashCarveAddress.code.length > 0, "HashCarve should have bytecode");

        // 2. Verify Address Consistency (Content-Addressability)
        bytes memory runtimeBytecode = type(HashCarve).runtimeCode;
        assertEq(keccak256(hashCarveAddress.code), keccak256(runtimeBytecode), "Deployed bytecode mismatch");

        // 3. Functional Test: Verify addressOf
        HashCarve hc = HashCarve(hashCarveAddress);
        bytes memory testPayload = hex"aabbcc";
        address predicted = hc.addressOf(testPayload);
        assertTrue(predicted != address(0), "predicted address should not be zero");

        // Try to carve something
        address carved = hc.carve(testPayload);
        assertEq(carved, predicted, "Carved address should match predicted address");
        assertEq(carved.code.length, testPayload.length, "Carved code length mismatch");
    }

    function test_SkipIfAlreadyDeployed() public {
        // Run once
        address firstRun = deployer.run();

        // Run again
        address secondRun = deployer.run();

        assertEq(firstRun, secondRun, "Subsequent runs should target the same address");
        assertTrue(firstRun.code.length > 0, "Contract should still exist");
    }
}
