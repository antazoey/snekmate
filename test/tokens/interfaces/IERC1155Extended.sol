// SPDX-License-Identifier: WTFPL
pragma solidity ^0.8.30;

import {IERC1155MetadataURI} from "openzeppelin/token/ERC1155/extensions/IERC1155MetadataURI.sol";

interface IERC1155Extended is IERC1155MetadataURI {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    event RoleMinterChanged(address indexed minter, bool status);

    function set_uri(uint256 id, string calldata tokenUri) external;

    function exists(uint256 id) external view returns (bool);

    function total_supply(uint256 id) external view returns (uint256);

    function burn(address owner, uint256 id, uint256 amount) external;

    function burn_batch(address owner, uint256[] calldata ids, uint256[] calldata amounts) external;

    function is_minter(address account) external view returns (bool);

    function safe_mint(address owner, uint256 id, uint256 amount, bytes calldata data) external;

    function _customMint(address owner, uint256 id, uint256 amount) external;

    function safe_mint_batch(
        address owner,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;

    function set_minter(address minter, bool status) external;

    function owner() external view returns (address);

    function transfer_ownership(address newOwner) external;

    function renounce_ownership() external;
}
