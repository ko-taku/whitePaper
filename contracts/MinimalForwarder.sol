// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

interface IMinimalForwarder {
    function execute(
        address to,
        uint256 value,
        bytes calldata data
    ) external returns (bytes memory);

    function isTrustedForwarder(address forwarder) external view returns (bool);

    function verify(
        address signer,
        address to,
        uint256 value,
        bytes calldata data,
        bytes calldata signature
    ) external view returns (bool);
}

contract MinimalForwarder is IMinimalForwarder, ERC165 {
    using Address for address;
    using SignatureChecker for address;

    // The trusted forwarders that can relay transactions to the forwarder
    mapping(address => bool) private trustedForwarders;

    constructor() {
        trustedForwarders[address(this)] = true; // Ensure the contract itself can forward
    }

    /**
     * @dev Executes a transaction on behalf of a user.
     * @param to Target address of the transaction
     * @param value Value to send
     * @param data Data to send with the transaction
     */
    function execute(
        address to,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes memory) {
        require(to != address(0), "Invalid target address");

        (bool success, bytes memory returnData) = to.call{value: value}(data);
        require(success, "Transaction failed");

        return returnData;
    }

    /**
     * @dev Allows the owner to add trusted forwarders.
     * @param forwarder The address of the trusted forwarder
     */
    function addTrustedForwarder(address forwarder) external {
        trustedForwarders[forwarder] = true;
    }

    /**
     * @dev Allows the owner to remove trusted forwarders.
     * @param forwarder The address of the trusted forwarder
     */
    function removeTrustedForwarder(address forwarder) external {
        trustedForwarders[forwarder] = false;
    }

    /**
     * @dev Returns whether the address is a trusted forwarder.
     * @param forwarder Address of the forwarder
     */
    function isTrustedForwarder(
        address forwarder
    ) external view override returns (bool) {
        return trustedForwarders[forwarder];
    }

    /**
     * @dev Verifies that the signature is valid for the provided data.
     * @param signer The address that signed the message
     * @param to The target address of the transaction
     * @param value The value sent with the transaction
     * @param data The data to be sent
     * @param signature The signature to verify
     * @return bool Whether the signature is valid
     */
    function verify(
        address signer,
        address to,
        uint256 value,
        bytes calldata data,
        bytes calldata signature
    ) external view override returns (bool) {
        // Create the hash of the data to be signed
        bytes32 hash = keccak256(abi.encodePacked(to, value, data));

        // Check the signature
        return signer.isValidSignatureNow(hash, signature);
    }

    // Ensure that the contract can handle incoming ETH
    receive() external payable {}

    // Override ERC165 to support the IMinimalForwarder interface
    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return
            interfaceId == type(IMinimalForwarder).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
