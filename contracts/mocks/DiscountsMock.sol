// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4;

import "../utils/Discounts.sol";

/**
 * @dev Parsing and Validation of Discount Codes
 *
 */
contract DiscountsMock {
    using Discounts for bytes;

    function parseDiscountCode(bytes memory code)
        external
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
        return code.parseDiscountCode();
    }
}
