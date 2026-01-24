// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import {HashCarve} from "../src/HashCarve.sol";

contract MockRuntime {
    function id() external pure returns (uint256) {
        return 42;
    }
}

contract MockRuntime2 {
    function id() external pure returns (uint256) {
        return 67;
    }
}

contract MockRuntime3 {
    function id() external pure returns (uint256) {
        return 0xc64;
    }
}

contract HashCarveFromTest is Test {
    HashCarve public hashCarve;
    MockRuntime public sourceContract;
    bytes public runtimeCode;

    function setUp() public {
        hashCarve = new HashCarve();
        sourceContract = new MockRuntime();
        runtimeCode = address(sourceContract).code;
    }

    function test_CarveFrom() public {
        address predicted = hashCarve.addressOfBytecode(runtimeCode);

        address carved = hashCarve.carveFrom(address(sourceContract));

        assertEq(carved, predicted, "Carved address should match predicted address");
        assertTrue(hashCarve.isCarved(carved), "isCarved should return true");

        // Check if code matches (excluding metadata hash nuances if any, but exact copy is expected)
        assertEq(carved.code, address(sourceContract).code, "Runtime code should match source");
    }

    function test_CarveFromBatch() public {
        address[] memory sources = new address[](2);
        sources[0] = address(sourceContract);

        MockRuntime2 source2Contract = new MockRuntime2();
        sources[1] = address(source2Contract);

        address[] memory deployed = hashCarve.carveFromBatch(sources);

        assertEq(deployed.length, 2);

        address predicted1 = hashCarve.addressOfBytecode(address(sourceContract).code);
        address predicted2 = hashCarve.addressOfBytecode(address(source2Contract).code);

        assertEq(deployed[0], predicted1);
        assertEq(deployed[1], predicted2);
    }

    function test_CarveFromBatchEmpty() public {
        address[] memory sources = new address[](0);
        address[] memory deployed = hashCarve.carveFromBatch(sources);
        assertEq(deployed.length, 0, "Should return empty array");
    }

    function test_CarveFromRevertIfEmpty() public {
        // Create an empty address (no code) because we are in foundry
        // address(0) has no code.
        vm.expectRevert(bytes4(0x30116425)); // DeploymentFailed
        hashCarve.carveFrom(address(0));

        // Also just a random address that has no code
        address random = address(0x1234567890123456789012345678901234567890);
        vm.expectRevert(bytes4(0x30116425));
        hashCarve.carveFrom(random);
    }

    function test_CarveFromOutOfGasRetry() public {
        address predicted = hashCarve.addressOfBytecode(runtimeCode);

        // 1. Attempt deployment with insufficient gas
        (bool success,) =
            address(hashCarve).call{gas: 5000}(abi.encodeCall(HashCarve.carveFrom, (address(sourceContract))));

        // Expect failure
        assertFalse(success, "Should have failed due to OOG");

        // Verify NOT deployed
        assertEq(predicted.code.length, 0, "Should not be deployed after failure");

        // 2. Retry with full gas
        address carved = hashCarve.carveFrom(address(sourceContract));

        // Verify success
        assertEq(carved, predicted, "Address mismatch after retry");
        assertEq(carved.code, runtimeCode, "Runtime code should match source");
    }

    function test_CarveFromBatchOutOfGasRetry() public {
        address[] memory sources = new address[](3);

        // Source 1
        sources[0] = address(sourceContract);

        // Source 2
        MockRuntime2 source2Contract = new MockRuntime2();
        sources[1] = address(source2Contract);

        // Source 3
        MockRuntime3 source3Contract = new MockRuntime3();
        sources[2] = address(source3Contract);

        // Predict addresses
        address[] memory predicted = new address[](3);
        predicted[0] = hashCarve.addressOfBytecode(address(sourceContract).code);
        predicted[1] = hashCarve.addressOfBytecode(address(source2Contract).code);
        predicted[2] = hashCarve.addressOfBytecode(address(source3Contract).code);

        // 1. Attempt batch deployment with insufficient gas
        // Enough for maybe 1 or 2, but not all 3.
        (bool success,) = address(hashCarve).call{gas: 100000}(abi.encodeCall(HashCarve.carveFromBatch, (sources)));

        // Expect failure
        assertFalse(success, "Should have failed due to OOG");

        // Verify validity of "partial failure atomic revert"
        // ALL contracts should NOT be deployed
        for (uint256 i = 0; i < 3; i++) {
            assertEq(predicted[i].code.length, 0, "Should not be deployed after atomic failure");
        }

        // 2. Retry with full gas
        address[] memory deployed = hashCarve.carveFromBatch(sources);

        // Verify success
        assertEq(deployed.length, 3, "Retry deployment count mismatch");
        for (uint256 i = 0; i < 3; i++) {
            assertEq(deployed[i], predicted[i], "Address mismatch after retry");
            assertEq(deployed[i].code, sources[i].code, "Code mismatch after retry");
        }
    }
}
