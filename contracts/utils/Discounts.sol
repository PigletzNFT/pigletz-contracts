// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @dev Parsing and Validation of Discount Codes
 *
 */
library Discounts {
    using ECDSA for bytes32;
    using ECDSA for bytes;

    function parseDiscountCode(bytes memory code)
        internal
        pure
        returns (
            uint16 magic,
            uint16 aff,
            uint8 id,
            uint16 start,
            uint16 end,
            uint16 nonce,
            address signer
        )
    {
        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            magic := mload(add(code, 0x02))
            aff := mload(add(code, 0x04))
            id := mload(add(code, 0x05))
            start := mload(add(code, 0x07))
            end := mload(add(code, 0x09))
            nonce := mload(add(code, 0x0B))
            r := mload(add(code, 0x2B))
            s := mload(add(code, 0x4B))
            v := mload(add(code, 0x4C))
        }

        bytes32 hash = keccak256(abi.encodePacked(magic, aff, id, start, end, nonce)).toEthSignedMessageHash();
        signer = hash.recover(v, r, s);
    }
}
