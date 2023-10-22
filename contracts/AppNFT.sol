// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@tableland/evm/contracts/utils/SQLHelpers.sol";
import "@tableland/evm/contracts/utils/TablelandDeployments.sol";
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import {AppNFTGenerator} from "./AppNFTGenerator.sol";

interface IAppNFTGenerator {
    function getUserAttendanceCounterPerDao(
        address _user,
        address _daoAddress
    ) external view returns (uint256);
}

/**
 * @dev A dynamic NFT, built with Tableland and Chainlink VRF for mutating an NFT at some time interval
 */
contract AppNFT is ERC721, IERC721Receiver, Ownable, AutomationCompatible {
    // General dNFT and Chainlink data
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter; // Counter for the current token ID

    address public daoAddress;
    address public nftGenerator;

    // uint256 lastTimeStamp; // Most recent timestamp at which the collection was updated
    // uint256 interval; // Time (in seconds) for how frequently the NFTs should change

    mapping(uint256 => uint256) public stage; // Track the token ID to its current stage
    
    // Tableland-specific information
    uint256 private _levelsTableId; // A table ID -- stores NFT attributes
    uint256 private _tokensTableId; // A table ID -- stores the token ID and its current stage
    string private constant _levelS_TABLE_PREFIX = "levels"; // Table prefix for the levels table
    string private constant _TOKENS_TABLE_PREFIX = "tokens"; // Table prefix for the tokens table
    string private _baseURIString; // The Tableland gateway URL

    // constructor(string memory baseURIString) ERC721("dNFTs", "dNFT") {
    //     interval = 30; // Hardcode some interval value (in seconds) for when the dynamic NFT should "grow" into the next stage
    //     lastTimeStamp = block.timestamp; // Track the most recent timestamp for when a dynamic VRF update occurred
    //     _baseURIString = baseURIString;
    // }

    constructor(string memory baseURIString, address _daoAddress) ERC721("dNFTs", "dNFT") {
        // interval = 30; // Hardcode some interval value (in seconds) for when the dynamic NFT should "grow" into the next stage
        // lastTimeStamp = block.timestamp; // Track the most recent timestamp for when a dynamic VRF update occurred
        _baseURIString = baseURIString;
        daoAddress = _daoAddress;
    }

    /**
     * @dev Initializes Tableland tables that track & compose NFT metadata
     */
    function initTables() public onlyOwner {
        // Create a "levels" table to track a predefined set of NFT traits, which will be composed based on VRF-mutated `stage`
        _levelsTableId = TablelandDeployments.get().create(
            address(this),
            SQLHelpers.toCreateFromSchema(
                "id int primary key," // An ID for the trait row
                "stage text not null," // The trait for what level growth stage (seed, purple_seedling, purple_blooms)
                "color text not null," // The value of the trait's color (unknown, purple, etc.)
                "cid text not null", // For each trait's image, store a pointer to the IPFS CID
                _levelS_TABLE_PREFIX // Prefix (human readable name) for the table
            )
        );
        // Initalize values for the levels table -- do this by creating an array of comma separated string values for each row
        string[] memory values = new string[](3);
        values[0] = "0,'seed','unknown','QmNpAiQZjkoLCb3MRR8jFJEDpw7YWcSSGMPLzyU5rvNTNg'"; // Notice the single quotes around text
        values[1] = "1,'purple_seedling','purple','QmRkq5EeKE5wKAuZNjaDFxtqpLQP3cFJVVWNu3sqy452uA'";
        values[2] = "2,'purple_blooms','purple','QmRkq5EeKE5wKAuZNjaDFxtqpLQP3cFJVVWNu3sqy452uA'";

        // Insert these values into the levels table
        TablelandDeployments.get().mutate(
            address(this),
            _levelsTableId,
            SQLHelpers.toBatchInsert(
                _levelS_TABLE_PREFIX,
                _levelsTableId,
                "id,stage,color,cid", // Columns to insert into, as a comma separated string of column names
                // Data to insert, where each array value is a comma-separated table row
                values
            )
        );
        // Create a "tokens" table to track the NFT token ID and its corresponding level stage ID
        _tokensTableId = TablelandDeployments.get().create(
            address(this),
            SQLHelpers.toCreateFromSchema(
                "id int primary key," // Track the NFT token ID
                "stage_id int not null", // Dynamically track the current seed stage; maps to the "levels" table
                _TOKENS_TABLE_PREFIX
            )
        );
    }

    /**
     * @dev Chainlink VRF function that gets called upon a defined time interval within Chainlink's Upkeep setup
     */
    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        uint256 userCount = IAppNFTGenerator(nftGenerator).getUserAttendanceCounterPerDao(ownerOf(_tokenIdCounter) , daoAddress);
        upkeepNeeded = userCount == 5 || userCount == 10;
    }

    /**
     * @dev If the conditions in `checkUpkeep` are met, then `performUpkeep` gets called and mutates the NFT's value
     */
    function performUpkeep(
        bytes calldata /* performData */
    ) external {
        // Revalidate the upkeep

        uint256 userCount = IAppNFTGenerator(nftGenerator).getUserAttendanceCounterPerDao(ownerOf(_tokenIdCounter) , daoAddress);

        if (upkeepNeeded = userCount == 5 || userCount == 10) {
            upgradeLevel(_tokenIdCounter);
        }
    }

    /**
     * @dev If the conditions in `checkUpkeep` are met, then `performUpkeep` gets called and mutates the NFT's value
     * 
     * to - the address the NFT should be minted to
     */
    function mint(address to) external {
        // Get the current value for the token supply and increment it
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        // Mint the NFT to the `to` address
        _safeMint(to, tokenId);
        // Insert the metadata into the "tokens" Tableland table with a default "seed" value
        // The seed is in the "levels" table with a stage ID of `0` -- insert the token ID and this stage ID
        TablelandDeployments.get().mutate(
            address(this),
            _tokensTableId,
            SQLHelpers.toInsert(
                _TOKENS_TABLE_PREFIX,
                _tokensTableId,
                "id," // Token ID column
                "stage_id", // level stage column (i.e., it starts as a seed and then grows)
                // Data to insert -- the `tokenId` and `stage` as comma separated values
                string.concat(
                    Strings.toString(tokenId),
                    ",",
                    Strings.toString(0) // Value of `seed` is at `stage_id` `0`
                )
            )
        );
    }

    /**
     * @dev Grow the level -- that is, mutate the NFT's `stage` to the next available stage
     * 
     * _tokenId - the token ID to mutate
     */
    function upgradeLevel(uint256 _tokenId) public {
        // The maximum number of stages is set to `2`, so don't mutate an NFT if it's already hit its capacity
        if (stage[_tokenId] >= 2) {
            return;
        }
        // Get the current stage of the level, and add 1, which moves it to the next stage
        uint256 newVal = stage[_tokenId] + 1;
        // Update the stage within the `stage` mapping
        stage[_tokenId] = newVal;
        // Update the stage within the Tableland "tokens" table, where the `stage_id` will change the `tokenURI` metadata response
        TablelandDeployments.get().mutate(
            address(this),
            _tokensTableId,
            SQLHelpers.toUpdate(
                _TOKENS_TABLE_PREFIX,
                _tokensTableId,
                string.concat("stage_id=", Strings.toString(newVal)), // Column to update
                // token to update
                string.concat(
                    "id=",
                    Strings.toString(_tokenId)
                )
            )
        );
    }

    /**
     * @dev Returns the base URI for NFT token metadata, which is set to the Tableland hosted gateway
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseURIString;
    }

    /**
     * @dev Allows the contract's owner to update the `_baseURIString`, if needed
     */
    function setBaseURI(string memory baseURIString) external onlyOwner {
        _baseURIString = baseURIString;
    }

    /**
     * @dev Returns the NFT's metadata
     * 
     * tokenId - the token ID for metadata retrieval
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        // Ensure the token exists
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        // Set the `baseURI`
        string memory baseURI = _baseURI();
        if (bytes(baseURI).length == 0) {
            return "";
        }

        /**
         * A SQL query to JOIN two tables and compose the metadata across a 'tokens' and 'levels' table in ERC-721 compliant schema
         * 
         * Essentially, the metadata is built for each NFT using the tables. As values get updated via `upgradeLevel`,
         * the associated metadata query will automatically read those values from the table; this `tokenURI` query
         * is future-proof upon table mutations.
         * 
         * The query forms a `json_object` with two nested `json_object` values in a `json_array`. The top-level metadata fields include
         * the `name`, `image`, and `attributes`, where the `attributes` hold the composed data from the "tokens" and "levels" tables.
         * For the `image`, there were images previously uploaded to IPFS and stored in the format `<IPFS_CID>/<stage>.jpg`.
         *
         *   select 
         *   json_object(
         *       'name', 'Friendship Seed #' || <tokens_table>.id,
         *       'image', 'ipfs://' || cid || '/' || stage || '.jpg',
         *       'attributes', json_array(
         *           json_object(
         *               'display_type','string',
         *               'trait_type','level Stage',
         *               'value',stage
         *           ),
         *           json_object(
         *               'display_type','string',
         *               'trait_type','level Color',
         *               'value',color
         *           )
         *       )
         *   ) 
         *   from 
         *   <tokens_table>
         *   join <levels_table> on <tokens_table>.stage_id = <levels_table>.id
         *   where <tokens_table>.id = <tokenId>
         *
         * The <tokens_table> and <levels_table> are places in which the *actual* table name (`prefix_tableId_chainId`)
         * should be used. The rest of the statement should be URL encoded to ensure proper support from marketplaces 
         * and browsers -- the end result of performing these steps is what is assigned to `query`.
         */

        // Create references to the Tableland table names (`prefix_tableId_chainId`) for the "tokens" and "levels" tables
        string memory tokensTable = SQLHelpers.toNameFromId(_TOKENS_TABLE_PREFIX, _tokensTableId);
        string memory levelsTable = SQLHelpers.toNameFromId(_levelS_TABLE_PREFIX, _levelsTableId);
        // Create the read query noted above, which forms the ERC-721 compliant metadata
        string memory query = string.concat(
            "select%20json_object%28'name'%2C'Friendship%20Seed%20%23'%7C%7C",
            tokensTable,
            ".id%2C'image'%2C'ipfs%3A%2F%2F'%7C%7Ccid%7C%7C'%2F'%7C%7Cstage%7C%7C'.jpg'%2C'attributes'%2Cjson_array%28json_object%28'display_type'%2C'string'%2C'trait_type'%2C'level%20Stage'%2C'value'%2Cstage%29%2Cjson_object%28'display_type'%2C'string'%2C'trait_type'%2C'level%20Color'%2C'value'%2Ccolor%29%29%29%20from%20",
            tokensTable,
            "%20join%20",
            levelsTable,
            "%20on%20",
            tokensTable,
            ".stage_id%20%3D%20",
            levelsTable,
            ".id%20where%20",
            tokensTable,
            ".id%3D"
        );
        // Return the `baseURI` with the appended query string, which composes the token ID with its metadata attributes
        return
            string(
                abi.encodePacked(
                    baseURI,
                    query,
                    Strings.toString(tokenId),
                    "%20group%20by%20",
                    tokensTable,
                    ".id"
                )
            );
    }

    /**
     * @dev Returns the total supply for the collection
     */
    function totalSupply() external view returns(uint256) {
        return _tokenIdCounter.current();
    }

    /**
     * @dev Required in order for the contract to own the Tableland tables, which are ERC-721 tokens
     */
    function onERC721Received(address, address, uint256, bytes calldata) override external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}