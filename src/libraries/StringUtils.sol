// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

library StringUtils {
    function toString(uint256 n) internal pure returns (string memory) {
        if (n == 0) {
            return "0";
        }
        uint256 len;
        for (uint256 j = n; j != 0; j /= 10) {
            len++;
        }
        bytes memory res = new bytes(len);
        for (uint256 k = len; n != 0; (n /= 10, k--)) {
            res[k - 1] = bytes1(uint8(48 + (n % 10))); // '0' = 48
        }
        return string(res);
    }
}
