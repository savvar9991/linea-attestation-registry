// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { RouterManager } from "./RouterManager.sol";
// solhint-disable-next-line max-line-length
import { ERC165CheckerUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165CheckerUpgradeable.sol";
import { AbstractPortalV2 } from "./abstracts/AbstractPortalV2.sol";
import { DefaultPortalV2 } from "./DefaultPortalV2.sol";
import { Portal } from "./types/Structs.sol";
import { IRouter } from "./interfaces/IRouter.sol";
import { uncheckedInc256 } from "./Common.sol";

/**
 * @title Portal Registry
 * @author Consensys
 * @notice This contract aims to manage the Portals used by attestation issuers
 */
contract PortalRegistry is RouterManager {
  IRouter public router;

  mapping(address id => Portal portal) private portals;

  mapping(address issuerAddress => bool isIssuer) private issuers;

  /// @dev Deprecated: The `portalAddresses` variable is no longer used. It was used to store the portals addresses.
  address[] private portalAddresses;

  bool private isTestnet;

  /// @notice Error thrown when the Router address remains unchanged
  error RouterAlreadyUpdated();
  /// @notice Error thrown when attempting to set an issuer that is already set
  error IssuerAlreadySet();
  /// @notice Error thrown when the testnet flag remains unchanged
  error TestnetStatusAlreadyUpdated();
  /// @notice Error thrown when a non-allowlisted user tries to call a forbidden method
  error OnlyAllowlisted();
  /// @notice Error thrown when attempting to register a Portal twice
  error PortalAlreadyExists();
  /// @notice Error thrown when attempting to register a Portal that is not a smart contract
  error PortalAddressInvalid();
  /// @notice Error thrown when attempting to register a Portal with an empty name
  error PortalNameMissing();
  /// @notice Error thrown when attempting to register a Portal with an empty description
  error PortalDescriptionMissing();
  /// @notice Error thrown when attempting to register a Portal with an empty owner name
  error PortalOwnerNameMissing();
  /// @notice Error thrown when attempting to register a Portal that does not implement IPortal interface
  error PortalInvalid();
  /// @notice Error thrown when attempting to get a Portal that is not registered
  error PortalNotRegistered();
  /// @notice Error thrown when an invalid address is given
  error AddressInvalid();

  /// @notice Event emitted when a Portal is registered
  event PortalRegistered(string name, string description, address portalAddress);
  /// @notice Event emitted when a new issuer is added
  event IssuerAdded(address issuerAddress);
  /// @notice Event emitted when the issuer is removed
  event IssuerRemoved(address issuerAddress);
  /// @notice Event emitted when a Portal is revoked
  event PortalRevoked(address portalAddress);
  /// @notice Event emitted when the `isTestnet` flag is updated
  event IsTestnetUpdated(bool isTestnet);

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /**
   * @notice Contract initialization with testnet status
   * @param _isTestnet Boolean indicating if the deployment is on a testnet
   */
  function initialize(bool _isTestnet) public initializer {
    __Ownable_init();
    isTestnet = _isTestnet;
  }

  /**
   * @dev Changes the address for the Router
   * @param _router the new Router address
   */
  function _setRouter(address _router) internal override {
    if (_router == address(router)) revert RouterAlreadyUpdated();

    router = IRouter(_router);
  }

  /**
   * @notice Registers an address as an issuer
   * @param issuer the address to register as an issuer
   */
  function setIssuer(address issuer) public onlyOwner {
    if (issuer == address(0)) revert AddressInvalid();
    if (issuers[issuer]) revert IssuerAlreadySet();

    issuers[issuer] = true;
    emit IssuerAdded(issuer);
  }

  /**
   * @notice Update the testnet status
   * @param _isTestnet the flag defining the testnet status
   */
  function setIsTestnet(bool _isTestnet) public onlyOwner {
    if (isTestnet == _isTestnet) revert TestnetStatusAlreadyUpdated();

    isTestnet = _isTestnet;
    emit IsTestnetUpdated(_isTestnet);
  }

  /**
   * @notice Revokes issuer status from an address
   * @param issuer the address to be revoked as an issuer
   */
  function removeIssuer(address issuer) public onlyOwner {
    issuers[issuer] = false;
    // Emit event
    emit IssuerRemoved(issuer);
  }

  /**
   * @notice Checks if a given address is an issuer
   * @return A flag indicating whether the given address is an issuer
   */
  function isIssuer(address issuer) public view returns (bool) {
    return issuers[issuer];
  }

  /**
   * @notice Checks if the caller is allowlisted.
   * @param user the user address
   */
  modifier onlyAllowlisted(address user) {
    if (!isAllowlisted(user)) revert OnlyAllowlisted();
    _;
  }

  /**
   * @notice Registers a Portal to the PortalRegistry
   * @param id the portal address
   * @param name the portal name
   * @param description the portal description
   * @param isRevocable whether the portal issues revocable attestations
   * @param ownerName name of this portal's owner
   */
  function register(
    address id,
    string memory name,
    string memory description,
    bool isRevocable,
    string memory ownerName
  ) public onlyAllowlisted(msg.sender) {
    // Check if portal already exists
    if (portals[id].id != address(0)) revert PortalAlreadyExists();

    // Check if portal is a smart contract
    if (!isContractAddress(id)) revert PortalAddressInvalid();

    // Check if name is not empty
    if (bytes(name).length == 0) revert PortalNameMissing();

    // Check if description is not empty
    if (bytes(description).length == 0) revert PortalDescriptionMissing();

    // Check if the owner's name is not empty
    if (bytes(ownerName).length == 0) revert PortalOwnerNameMissing();

    // Check if portal has implemented AbstractPortalV2
    if (!ERC165CheckerUpgradeable.supportsInterface(id, type(AbstractPortalV2).interfaceId)) revert PortalInvalid();

    // Get the array of modules implemented by the portal
    address[] memory modules = AbstractPortalV2(id).getModules();

    // Add portal to mapping
    Portal memory newPortal = Portal(id, msg.sender, modules, isRevocable, name, description, ownerName);
    portals[id] = newPortal;

    // Emit event
    emit PortalRegistered(name, description, id);
  }

  /**
   * @notice Revokes a Portal from the PortalRegistry
   * @param id the portal address
   * @dev Only the registry owner can call this method
   */
  function revoke(address id) public onlyOwner {
    if (!isRegistered(id)) revert PortalNotRegistered();

    delete portals[id];

    emit PortalRevoked(id);
  }

  /**
   * @notice Deploys and registers a clone of default portal V2
   * @param modules the modules addresses
   * @param name the portal name
   * @param description the portal description
   * @param ownerName name of this portal's owner
   */
  function deployDefaultPortal(
    address[] calldata modules,
    string calldata name,
    string calldata description,
    bool isRevocable,
    string calldata ownerName
  ) external onlyAllowlisted(msg.sender) {
    DefaultPortalV2 defaultPortal = new DefaultPortalV2(modules, address(router));
    register(address(defaultPortal), name, description, isRevocable, ownerName);
  }

  /**
   * @notice Get a Portal by its address
   * @param id The address of the Portal
   * @return The Portal
   */
  function getPortalByAddress(address id) public view returns (Portal memory) {
    if (!isRegistered(id)) revert PortalNotRegistered();
    return portals[id];
  }

  /**
   * @notice Get the owner address of a Portal
   * @param portalAddress The address of the Portal
   * @return The Portal owner address
   */
  function getPortalOwner(address portalAddress) external view returns (address) {
    if (!isRegistered(portalAddress)) revert PortalNotRegistered();
    return portals[portalAddress].ownerAddress;
  }

  /**
   * @notice Get a Portal's revocability
   * @param portalAddress The address of the Portal
   * @return The Portal revocability
   */
  function getPortalRevocability(address portalAddress) external view returns (bool) {
    if (!isRegistered(portalAddress)) revert PortalNotRegistered();
    return portals[portalAddress].isRevocable;
  }

  /**
   * @notice Check if a Portal is registered
   * @param id The address of the Portal
   * @return True if the Portal is registered, false otherwise
   */
  function isRegistered(address id) public view returns (bool) {
    return portals[id].id != address(0);
  }

  /**
   * @notice Checks if the caller is allowlisted.
   * @return A flag indicating whether the Verax instance is running on testnet
   */
  function getIsTestnet() public view returns (bool) {
    return isTestnet;
  }

  /**
   * @notice Checks if a user is allowlisted.
   * @param user the user address
   * @return A flag indicating whether the given address is allowlisted
   */
  function isAllowlisted(address user) public view returns (bool) {
    return isTestnet || isIssuer(user);
  }

  /**
   * Check if address is smart contract and not EOA
   * @param contractAddress address to be verified
   * @return the result as true if it is a smart contract else false
   */
  function isContractAddress(address contractAddress) internal view returns (bool) {
    return contractAddress.code.length > 0;
  }
}
