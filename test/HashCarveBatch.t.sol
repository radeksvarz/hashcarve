// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {HashCarve} from "../src/HashCarve.sol";
import {IHashCarve} from "../src/IHashCarve.sol";

contract HashCarveBatchTest is Test {
    HashCarve public carver;

    function setUp() public {
        carver = new HashCarve();
    }

    /**
     * @notice Test carveBatch with multiple bytecodes.
     */
    function test_CarveBatch() public {
        bytes[] memory runtimes = new bytes[](3);
        runtimes[0] = hex"602a60005260206000f3"; // 42
        runtimes[1] = hex"602b60005260206000f3"; // 43
        runtimes[2] = hex"602c60005260206000f3"; // 44

        address[] memory deployed = carver.carveBatch(runtimes);

        assertEq(deployed.length, 3, "Should have deployed 3 contracts");

        for (uint256 i = 0; i < 3; i++) {
            address predicted = carver.addressOfBytecode(runtimes[i]);
            assertEq(deployed[i], predicted, "Address mismatch");
            assertNotEq(deployed[i], address(0), "Deployment failed");
            assertEq(deployed[i].code, runtimes[i], "Code mismatch");
            assertTrue(carver.isCarved(deployed[i]), "Should be verified as carved");
        }
    }

    /**
     * @notice Test carveBatch reverts atomically if one deployment fails.
     */
    function test_CarveBatchAtomicRevert() public {
        bytes[] memory runtimes = new bytes[](2);
        runtimes[0] = hex"602a60005260206000f3"; // 42
        // Same bytecode as [0], should fail on second deployment due to collision
        runtimes[1] = hex"602a60005260206000f3";

        vm.expectRevert(IHashCarve.DeploymentFailed.selector);
        carver.carveBatch(runtimes);
    }

    /**
     * @notice Test carveBatch with empty array.
     */
    function test_CarveBatchEmpty() public {
        bytes[] memory runtimes = new bytes[](0);
        address[] memory deployed = carver.carveBatch(runtimes);
        assertEq(deployed.length, 0, "Should return empty array");
    }

    /**
     * @notice Test that if batch deployment fails partialy due to Out-Of-Gas,
     *         it reverts atomically and can be retried.
     */
    function test_CarveBatchOutOfGasRetry() public {
        bytes[] memory runtimes = new bytes[](3);
        runtimes[0] = hex"602a60005260206000f3"; // 42
        runtimes[1] = hex"602b60005260206000f3"; // 43
        runtimes[2] = hex"602c60005260206000f3"; // 44

        // Predict addresses
        address[] memory predicted = new address[](3);
        for (uint256 i = 0; i < 3; i++) {
            predicted[i] = carver.addressOfBytecode(runtimes[i]);
        }

        // 1. Attempt batch deployment with insufficient gas
        // Enough for maybe 1 or 2, but not all 3.
        // Heuristic: ~30k per deploy + overhead. Try 50k.
        (bool success,) = address(carver).call{gas: 60000}(abi.encodeCall(HashCarve.carveBatch, (runtimes)));

        // Expect failure
        assertFalse(success, "Should have failed due to OOG");

        // Verify validity of "partial failure atomic revert"
        // ALL contracts should NOT be deployed
        for (uint256 i = 0; i < 3; i++) {
            assertEq(predicted[i].code.length, 0, "Should not be deployed after atomic failure");
        }

        // 2. Retry with full gas
        address[] memory deployed = carver.carveBatch(runtimes);

        // Verify success
        assertEq(deployed.length, 3, "Retry deployment count mismatch");
        for (uint256 i = 0; i < 3; i++) {
            assertEq(deployed[i], predicted[i], "Address mismatch after retry");
            assertEq(deployed[i].code, runtimes[i], "Code mismatch after retry");
        }
    }
}
