// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/token/ERC721/IERC721.sol";
import "@openzeppelin/token/ERC721/extensions/IERC721Metadata.sol";

interface IAppNFT is IERC721, IERC721Metadata {
    function safeMint(address to) external;
}
