# Style Guide

This document outlines the coding style and conventions used in this repository.

## General

- **License**: All files must start with `// SPDX-License-Identifier: MIT`.
- **Formatter**: The code should be formatted according to the Foundry formatter.

## Naming Conventions

### Contracts & Events
- Use **PascalCase** for contract names, events, errors, and structs.

### Constants
- Use **UPPER_CASE** with underscores for constants.
- Private constants should have a leading underscore.

### Functions & Variables
- Use **camelCase** for function names, function arguments, and local variables.

### Assembly Variables
- Use **snake_case** for variables defined within `assembly` blocks.

### Test Functions
- Use the pattern `test_Description_Condition` or `test_Description`.
- Use `test_RevertIf_Condition` for negative tests.
- Use fuzzing intensely and by default, do not name fuzz tests as `testFuzz`

## Documentation (NatSpec)

- Use **NatSpec** format for documenting contracts, functions, events, and errors.
- Include `@notice` for user-facing explanations.
- Include `@dev` for developer-facing details.
- Include `@author` tags where appropriate.

## Testing

- Use **Foundry** (`forge-std`) for testing.
- Test contracts should inherit from `Test`.
- Use named imports for dependencies (e.g., `import {Test} from "forge-std/Test.sol";`).
- Leverage **Fuzz Testing** by adding parameters to test functions.
- Verify events using `vm.expectEmit`.
- Verify reverts using `vm.expectRevert` with custom errors.

## Assembly / Yul

- Use `assembly` blocks for gas optimizations or low-level operations (e.g., `delegatecall`, specific storage slots).
- **Comment heavily** inside assembly blocks to explain the logic and stack operations.
- Explicitly handle memory and storage pointers.

## Imports

- Use **named imports** to be explicit about what is being imported (e.g., `import {Test} from "forge-std/Test.sol";`).
