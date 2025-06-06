// SPDX-License-Identifier: WTFPL
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {VyperDeployer} from "utils/VyperDeployer.sol";

import {BytesLib} from "solidity-bytes-utils/BytesLib.sol";

import {IECDSA} from "./interfaces/IECDSA.sol";

/**
 * @dev Error that occurs when the signature length is invalid.
 * @param emitter The contract that emits the error.
 */
error InvalidSignatureLength(address emitter);

/**
 * @dev Error that occurs when the signature value `s` is invalid.
 * @param emitter The contract that emits the error.
 */
error InvalidSignatureSValue(address emitter);

contract ECDSATest is Test {
    using BytesLib for bytes;

    uint256 private constant _MALLEABILITY_THRESHOLD =
        57_896_044_618_658_097_711_785_492_504_343_953_926_418_782_139_537_452_191_302_581_570_759_080_747_168;

    VyperDeployer private vyperDeployer = new VyperDeployer();

    // solhint-disable-next-line var-name-mixedcase
    IECDSA private ECDSA;

    address private self = address(this);
    address private zeroAddress = address(0);

    /**
     * @dev Transforms a standard signature into an EIP-2098
     * compliant signature.
     * @param signature The secp256k1 64/65-bytes signature.
     * @return short The 64-bytes EIP-2098 compliant signature.
     */
    function to2098Format(bytes memory signature) internal view returns (bytes memory) {
        if (signature.length != 65) revert InvalidSignatureLength(self);
        if (uint8(signature[32]) >> 7 == 1) revert InvalidSignatureSValue(self);
        bytes memory short = signature.slice(0, 64);
        uint8 parityBit = uint8(short[32]) | ((uint8(signature[64]) % 27) << 7);
        short[32] = bytes1(parityBit);
        return short;
    }

    function setUp() public {
        ECDSA = IECDSA(vyperDeployer.deployContract("src/snekmate/utils/mocks/", "ecdsa_mock"));
    }

    function testRecoverWithValidSignature() public {
        /**
         * @dev Standard signature check.
         */
        (address alice, uint256 key) = makeAddrAndKey("alice");
        bytes32 hash = keccak256("WAGMI");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, hash);
        bytes memory signature = abi.encodePacked(r, s, v);
        assertEq(alice, ECDSA.recover_sig(hash, signature));

        /**
         * @dev EIP-2098 signature check.
         */
        bytes memory signature2098 = to2098Format(signature);
        assertEq(alice, ECDSA.recover_sig(hash, signature2098));
    }

    function testRecoverWithTooShortSignature() public {
        /**
         * @dev Standard signature check.
         */
        bytes32 hash = keccak256("WAGMI");
        bytes memory signature = "0x0123456789";
        assertEq(ECDSA.recover_sig(hash, signature), zeroAddress);

        /**
         * @dev EIP-2098 signature check.
         */
        vm.expectRevert(abi.encodeWithSelector(InvalidSignatureLength.selector, self));
        to2098Format(signature);
    }

    function testRecoverWithTooLongSignature() public {
        /**
         * @dev Standard signature check.
         */
        bytes32 hash = keccak256("WAGMI");
        bytes memory signature = bytes(
            "0x012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789"
        );
        vm.expectRevert();
        ECDSA.recover_sig(hash, signature);

        /**
         * @dev EIP-2098 signature check.
         */
        vm.expectRevert(abi.encodeWithSelector(InvalidSignatureLength.selector, self));
        to2098Format(signature);
    }

    function testRecoverWithArbitraryMessage() public {
        /**
         * @dev Standard signature check.
         */
        (address alice, uint256 key) = makeAddrAndKey("alice");
        bytes32 hash = bytes32("0x5741474d49");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, hash);
        bytes memory signature = abi.encodePacked(r, s, v);
        assertEq(alice, ECDSA.recover_sig(hash, signature));

        /**
         * @dev EIP-2098 signature check.
         */
        bytes memory signature2098 = to2098Format(signature);
        assertEq(alice, ECDSA.recover_sig(hash, signature2098));
    }

    function testRecoverWithWrongMessage() public {
        /**
         * @dev Standard signature check.
         */
        (address alice, uint256 key) = makeAddrAndKey("alice");
        bytes32 hashCorrect = keccak256("WAGMI");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, hashCorrect);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes32 hashWrong = keccak256("WAGMI1");
        address recoveredAddress = ECDSA.recover_sig(hashWrong, signature);
        assertTrue(alice != recoveredAddress);

        /**
         * @dev EIP-2098 signature check.
         */
        bytes memory signature2098 = to2098Format(signature);
        assertTrue(alice != ECDSA.recover_sig(hashWrong, signature2098));
    }

    function testRecoverWithInvalidSignature() public {
        /**
         * @dev Standard signature check.
         */
        (, uint256 key) = makeAddrAndKey("alice");
        bytes32 hash = keccak256("WAGMI");
        (, bytes32 r, bytes32 s) = vm.sign(key, hash);
        bytes memory signatureInvalid = abi.encodePacked(r, s, bytes1(0xa0));
        vm.expectRevert(bytes("ecdsa: invalid signature"));
        ECDSA.recover_sig(hash, signatureInvalid);
    }

    function testRecoverWith0x00Value() public {
        /**
         * @dev Standard signature check.
         */
        (, uint256 key) = makeAddrAndKey("alice");
        bytes32 hash = keccak256("WAGMI");
        (, bytes32 r, bytes32 s) = vm.sign(key, hash);
        bytes memory signatureWithoutVersion = abi.encodePacked(r, s);
        bytes1 version = 0x00;
        vm.expectRevert(bytes("ecdsa: invalid signature"));
        ECDSA.recover_sig(hash, abi.encodePacked(signatureWithoutVersion, version));
    }

    function testRecoverWithWrongVersion() public {
        /**
         * @dev Standard signature check.
         */
        (, uint256 key) = makeAddrAndKey("alice");
        bytes32 hash = keccak256("WAGMI");
        (, bytes32 r, bytes32 s) = vm.sign(key, hash);
        bytes memory signatureWithoutVersion = abi.encodePacked(r, s);
        bytes1 version = 0x02;
        vm.expectRevert(bytes("ecdsa: invalid signature"));
        ECDSA.recover_sig(hash, abi.encodePacked(signatureWithoutVersion, version));
    }

    function testRecoverWithCorrectVersion() public {
        /**
         * @dev Standard signature check.
         */
        (address alice, uint256 key) = makeAddrAndKey("alice");
        bytes32 hash = keccak256("WAGMI");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, hash);
        bytes memory signatureWithoutVersion = abi.encodePacked(r, s);
        assertEq(alice, ECDSA.recover_sig(hash, abi.encodePacked(signatureWithoutVersion, v)));

        /**
         * @dev EIP-2098 signature check.
         */
        bytes memory signature2098 = to2098Format(abi.encodePacked(signatureWithoutVersion, v));
        assertEq(alice, ECDSA.recover_sig(hash, signature2098));
    }

    function testRecoverWithTooHighSValue() public {
        /**
         * @dev Standard signature check.
         */
        (, uint256 key) = makeAddrAndKey("alice");
        bytes32 hash = keccak256("WAGMI");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, hash);
        uint256 sTooHigh = uint256(s) + _MALLEABILITY_THRESHOLD;
        bytes memory signature = abi.encodePacked(r, bytes32(sTooHigh), v);
        vm.expectRevert(bytes("ecdsa: invalid signature `s` value"));
        ECDSA.recover_sig(hash, signature);

        /**
         * @dev EIP-2098 signature check.
         */
        vm.expectRevert(abi.encodeWithSelector(InvalidSignatureSValue.selector, self));
        to2098Format(signature);
    }

    function testFuzzRecoverWithValidSignature(string calldata signer, string calldata message) public {
        /**
         * @dev Standard signature check.
         */
        (address alice, uint256 key) = makeAddrAndKey(signer);
        bytes32 hash = keccak256(abi.encode(message));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, hash);
        bytes memory signature = abi.encodePacked(r, s, v);
        assertEq(alice, ECDSA.recover_sig(hash, signature));

        /**
         * @dev EIP-2098 signature check.
         */
        bytes memory signature2098 = to2098Format(signature);
        assertEq(alice, ECDSA.recover_sig(hash, signature2098));
    }

    function testFuzzRecoverWithWrongMessage(string calldata signer, string calldata message, bytes32 digest) public {
        /**
         * @dev Standard signature check.
         */
        (address alice, uint256 key) = makeAddrAndKey(signer);
        bytes32 hashCorrect = keccak256(abi.encode(message));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, hashCorrect);
        bytes memory signature = abi.encodePacked(r, s, v);
        address recoveredAddress = ECDSA.recover_sig(digest, signature);
        assertTrue(alice != recoveredAddress);

        /**
         * @dev EIP-2098 signature check.
         */
        bytes memory signature2098 = to2098Format(signature);
        assertTrue(alice != ECDSA.recover_sig(digest, signature2098));
    }

    function testFuzzRecoverWithInvalidSignature(bytes calldata signature, string calldata message) public {
        vm.assume(signature.length < 64);
        /**
         * @dev Standard signature check.
         */
        bytes32 hash = keccak256(abi.encode(message));
        address recoveredAddress = ECDSA.recover_sig(hash, signature);
        assertEq(recoveredAddress, zeroAddress);

        /**
         * @dev EIP-2098 signature check.
         */
        vm.expectRevert(abi.encodeWithSelector(InvalidSignatureLength.selector, self));
        to2098Format(signature);
    }

    function testFuzzRecoverWithTooLongSignature(bytes calldata signature, string calldata message) public {
        vm.assume(signature.length > 65);
        /**
         * @dev Standard signature check.
         */
        bytes32 hash = keccak256(abi.encode(message));
        vm.expectRevert();
        ECDSA.recover_sig(hash, signature);

        /**
         * @dev EIP-2098 signature check.
         */
        vm.expectRevert(abi.encodeWithSelector(InvalidSignatureLength.selector, self));
        to2098Format(signature);
    }
}
