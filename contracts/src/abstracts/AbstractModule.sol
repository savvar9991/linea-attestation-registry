// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { AttestationPayload } from "../types/Structs.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/**
 * @title Abstract Module
 * @author Consensys
 * @notice Deprecated. Use the AbstractModuleV2 contract instead.
 */
abstract contract AbstractModule is ERC165 {
  /// @notice Error thrown when someone else than the portal's owner is trying to revoke
  error OnlyPortalOwner();

  /**
   * @notice Executes the module's custom logic.
   * @param attestationPayload The incoming attestation data.
   * @param validationPayload Additional data required for verification.
   * @param txSender The transaction sender's address.
   * @param value The transaction value.
   */
  function run(
    AttestationPayload memory attestationPayload,
    bytes memory validationPayload,
    address txSender,
    uint256 value
  ) public virtual;

  /**
   * @notice Checks if the contract implements the Module interface.
   * @param interfaceID The ID of the interface to check.
   * @return A boolean indicating interface support.
   */
  function supportsInterface(bytes4 interfaceID) public view virtual override returns (bool) {
    return interfaceID == type(AbstractModule).interfaceId || super.supportsInterface(interfaceID);
  }
}
