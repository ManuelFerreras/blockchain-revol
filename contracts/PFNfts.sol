// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PFNfts is Initializable, ERC1155Upgradeable, OwnableUpgradeable, ERC1155BurnableUpgradeable, ERC1155SupplyUpgradeable, UUPSUpgradeable {
    ///////// STATE VARIABLES
    struct Campaign {
        uint256 price;
        uint256 finishDate;
        uint256 id;
        uint256 maxSupply;
        uint256 mintedSupply;
        string name;
        string description;
        address campaignOwner;
    }

    mapping (uint256 => Campaign) private _batchIdToCampaign;
    mapping (uint256 => mapping (address => uint256)) private _participatedInCampaign;

    IERC20 private _currency;

    uint256 private _nextCampaignId = 1;
    uint256 private _trasuryFee = 0;
    uint256 private _liquidityFee = 0;
    uint256 private constant MINCAMPAIGNTIME = 7 days;

    address private _treasuryAddress;
    address private _liquidityAddress;

    ///////// EVENTS
    event CampaignCreated(uint256 id, string name);

    ///////// MODIFIERS
    modifier onlyCreatedCampaign(uint256 id) {
        require(_batchIdToCampaign[id].id == id, "Invalid Campaign.");
        _;
    }

    modifier onlyOngoingCampaign(uint256 id) {
        require(_batchIdToCampaign[id].finishDate >= block.timestamp, "Campaign has already ended.");
        _;
    }

    modifier onlyEnoughSupply(uint256 id, uint256 amount) {
        require(_batchIdToCampaign[id].mintedSupply + amount <= _batchIdToCampaign[id].maxSupply);
        _;
    }

    ///////// INITIALIZER
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner, address currency) initializer public {
        __ERC1155_init("PFNfts");
        __Ownable_init(initialOwner);
        __ERC1155Burnable_init();
        __ERC1155Supply_init();
        __UUPSUpgradeable_init();
        _currency = IERC20(currency);
    }

    ///////// OWNER FUNCTIONS
    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }
    

    ///////// PUBLIC READABLE FUNCTIONS
    function getAllCampaigns() public view returns(Campaign[] memory) {
        Campaign[] memory campaigns = new Campaign[](_nextCampaignId - 1);

        for (uint256 i = 0; i < _nextCampaignId; i++) 
        {
            campaigns[i] = _batchIdToCampaign[i];
        }

        return campaigns;
    }

    function getCampaign(uint256 id) public view returns(Campaign memory) {
        return _batchIdToCampaign[id];
    }


    ///////// PUBLIC CALLABLE FUNCTIONS
    function createCampaign(
        uint256 _price,
        uint256 _finishDate,
        uint256 _maxSupply,
        string memory _name,
        string memory _description,
        address _campaignOwner
    )
        external
    {
        require(_price > 0, "Invalid price.");
        require(_finishDate >= block.timestamp + MINCAMPAIGNTIME, "Invalid finish date.");
        require(_maxSupply > 0, "Invalid max supply.");
        require(keccak256(abi.encodePacked(_name)) != keccak256(abi.encodePacked("")), "Invalid name.");
        require(_campaignOwner != address(0), "Invalid Owner Address");

        Campaign memory _newCampaign = Campaign(_price, _finishDate, _nextCampaignId, _maxSupply, 0, _name, _description, _campaignOwner);
        _batchIdToCampaign[_nextCampaignId] = _newCampaign;
        _nextCampaignId++;

        emit CampaignCreated(_nextCampaignId, _name);
    }

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) 
        external
        onlyCreatedCampaign(id)
        onlyOngoingCampaign(id)
        onlyEnoughSupply(id, amount)
    {
        uint256 _price = _batchIdToCampaign[id].price * amount;
        
        // Calculate fees.
        uint256 _liquidityAmount = _price * _liquidityFee / 100;
        uint256 _treasuryAmount = _price * _trasuryFee / 100;
        uint256 _ownerAmount = _price - _liquidityAmount - _treasuryAmount;

        // Transfer funds.
        _currency.transferFrom(account, _batchIdToCampaign[id].campaignOwner, _ownerAmount);
        _currency.transferFrom(account, _liquidityAddress, _liquidityAmount);
        _currency.transferFrom(account, _treasuryAddress, _treasuryAmount);

        // TODO: Buyback Revol and return to the user.

        // Update Campaign details.
        _batchIdToCampaign[id].mintedSupply += amount;

        // Mint NFTs.
        _mint(account, id, amount, data);
        _participatedInCampaign[id][msg.sender] += amount;
    }

    function usePFNft(uint256 batch, uint256 amount) external {
        // Prepare Data.
        uint256[] memory _batchList = new uint256[](1);
        uint256[] memory _amountList = new uint256[](1);
        _batchList[0] = batch;
        _amountList[0] = amount;

        // Burn NFTs.
        burnBatch(msg.sender, _batchList, _amountList);
    } 

    ///////// INTERNAL FUNCTIONS
    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155Upgradeable, ERC1155SupplyUpgradeable)
    {
        super._update(from, to, ids, values);
    }
}