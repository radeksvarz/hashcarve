// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {HashCarve} from "../src/HashCarve.sol";
import {IHashCarve} from "../src/IHashCarve.sol";

contract HashCarveTest is Test {
    HashCarve public carver;

    function setUp() public {
        carver = new HashCarve();
    }

    /**
     * @notice Test that carve correctly deploys a contract and predicts its address.
     */
    function test_Carve() public {
        // Simple runtime bytecode: PUSH1 0x2a, PUSH1 0, MSTORE, PUSH1 0x20, PUSH1 0, RETURN
        // This returns 42 (0x2a) padded to 32 bytes.
        bytes memory runtime = hex"602a60005260206000f3";

        address predicted = carver.addressOfBytecode(runtime);
        address deployed = carver.carveBytecode(runtime);

        assertEq(deployed, predicted, "Address mismatch");
        assertNotEq(deployed, address(0), "Deployment failed");

        // Verify the deployed contract's code matches the runtime bytecode
        assertEq(deployed.code, runtime, "Code mismatch");

        // Verify the contract execution
        (bool success, bytes memory data) = deployed.staticcall("");
        assertTrue(success, "Staticcall failed");
        assertEq(abi.decode(data, (uint256)), 42, "Incorrect return value from deployed contract");
    }

    /**
     * @notice Test that address prediction is consistent and independent of deployment.
     */
    function test_AddressOfConsistency() public {
        bytes memory runtime = hex"600160005260206000f3";

        address addr1 = carver.addressOfBytecode(runtime);
        address addr2 = carver.addressOfBytecode(runtime);

        assertEq(addr1, addr2, "Address should be deterministic");

        address deployed = carver.carveBytecode(runtime);
        assertEq(deployed, addr1, "Deployed address does not match predicted address");
    }

    /**
     * @notice Test that carving the same bytecode twice fails with correct selector.
     */
    function test_RevertOnDuplicate() public {
        bytes memory runtime = hex"60ff60005260206000f3";
        carver.carveBytecode(runtime);

        vm.expectRevert(IHashCarve.DeploymentFailed.selector);
        carver.carveBytecode(runtime);
    }

    /**
     * @notice Test that carve reverts when runtime bytecode starts with 0xEF (EIP-3541).
     */
    function test_RevertOnEFPrefix() public {
        bytes memory runtime = hex"ef001122";
        vm.expectRevert(IHashCarve.DeploymentFailed.selector);
        carver.carveBytecode(runtime);
    }

    /**
     * @notice Test with empty bytecode.
     */
    function test_EmptyBytecode() public {
        bytes memory runtime = hex"";
        vm.expectRevert(IHashCarve.DeploymentFailed.selector);
        carver.carveBytecode(runtime);
    }

    /**
     * @notice Fuzz test to ensure addressOf always matches carve.
     * @param runtime Random runtime bytecode.
     */
    function testFuzz_CarveConsistency(
        bytes calldata runtime
    ) public {
        vm.assume(runtime.length > 0);

        // Bound length to valid contract size limit (24576 bytes)
        uint256 len = bound(runtime.length, 1, 24576);
        bytes memory boundedRecord = runtime[0:len];

        // EIP-3541: Forbidden prefix 0xEF (reserved for EOF)
        vm.assume(boundedRecord[0] != 0xEF);

        address predicted = carver.addressOfBytecode(boundedRecord);
        address deployed = carver.carveBytecode(boundedRecord);

        assertEq(deployed, predicted, "Fuzz match failed");
        assertEq(deployed.code, boundedRecord, "Fuzz code failed");
    }

    /**
     * @notice Test that address prediction is independent of the factory state.
     */
    function test_StaticPrediction() public {
        bytes memory runtime = hex"604260005260206000f3";
        address predictedBefore = carver.addressOfBytecode(runtime);

        carver.carveBytecode(runtime);

        address predictedAfter = carver.addressOfBytecode(runtime);
        assertEq(predictedBefore, predictedAfter, "Prediction should be static");
    }

    /**
     * @notice Test with exactly 32 bytes of runtime bytecode.
     */
    function test_Exactly32Bytes() public {
        bytes memory runtime = hex"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20";

        address predicted = carver.addressOfBytecode(runtime);
        address deployed = carver.carveBytecode(runtime);

        assertEq(deployed, predicted, "Address mismatch (32 bytes)");
        assertEq(deployed.code, runtime, "Code mismatch (32 bytes)");
    }

    /**
     * @notice Test with more than 32 bytes of runtime bytecode (e.g. 64 bytes).
     */
    function test_LongerThan32Bytes() public {
        bytes memory runtime = bytes.concat(
            hex"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20",
            hex"2122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f40"
        );

        address predicted = carver.addressOfBytecode(runtime);
        address deployed = carver.carveBytecode(runtime);

        assertEq(deployed, predicted, "Address mismatch (64 bytes)");
        assertEq(deployed.code, runtime, "Code mismatch (64 bytes)");
    }
}
