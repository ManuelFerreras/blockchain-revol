// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import { ERC1155URIStorageUpgradeable, ERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Revol} from "./Revol.sol";

contract PFNfts is Initializable, ERC1155Upgradeable, OwnableUpgradeable, ERC1155BurnableUpgradeable, ERC1155SupplyUpgradeable, ERC1155URIStorageUpgradeable, UUPSUpgradeable {
    ///////// STATE VARIABLES
    struct Campaign {
        uint256 price;
        uint256 discountPercentage;
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
    uint256 private constant MINCAMPAIGNTIME = 7 days;

    uint256 private maxBuybackFeePercentage = 5;
    uint256 private buybackFeePercentage = 20;

    address private _revolAddress;

    ///////// EVENTS
    event CampaignCreated(uint256 id, string name);

    ///////// MODIFIERS
    modifier onlyCreatedCampaign(uint256 id) {
        require(_batchIdToCampaign[id].id == id, "Invalid Campaign.");
        _;
    }

    modifier onlyCampaignOwner(uint256 id) {
        require(_batchIdToCampaign[id].campaignOwner == msg.sender || msg.sender == owner(), "Not the campaign owner.");
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

    function initialize(address initialOwner, address currency_, address revolAddress_, uint256 maxBuybackFeePercentage_) initializer public {
        __ERC1155_init("PFNfts");
        __Ownable_init(initialOwner);
        __ERC1155Burnable_init();
        __ERC1155Supply_init();
        __UUPSUpgradeable_init();
        _currency = IERC20(currency_);
        _revolAddress = revolAddress_;
        maxBuybackFeePercentage = maxBuybackFeePercentage_;
    }

    ///////// OWNER FUNCTIONS
    function setRevolAddress(address revolAddress_) external onlyOwner {
        _revolAddress = revolAddress_;
    }

    function setCurrencyAddress(address currency_) external onlyOwner {
        _currency = IERC20(currency_);
    }

    function setMaxBuybackFeePercentage(uint256 percentage) external onlyOwner {
        require(percentage <= 100, "Invalid percentage.");
        maxBuybackFeePercentage = percentage;
    }

    function setBuybackFeePercentage(uint256 percentage) external onlyOwner {
        require(percentage <= 100, "Invalid percentage.");
        buybackFeePercentage = percentage;
    }


    ///////// PUBLIC READABLE FUNCTIONS
    function getAllCampaigns() external view returns(Campaign[] memory) {
        Campaign[] memory campaigns = new Campaign[](_nextCampaignId - 1);

        for (uint256 i = 0; i < _nextCampaignId - 1; i++) 
        {
            campaigns[i] = _batchIdToCampaign[i + 1];
        }

        return campaigns;
    }

    function getCampaign(uint256 id) external view returns(Campaign memory) {
        return _batchIdToCampaign[id];
    }

    function checkIfParticipatedInCampaign(uint256 id, address participant) external view returns (uint256) {
        return _participatedInCampaign[id][participant];
    }

    ///////// PUBLIC CALLABLE FUNCTIONS
    function createCampaign(
        uint256 _price,
        uint256 _discountPercentage,
        uint256 _finishDate,
        uint256 _maxSupply,
        string memory _name,
        string memory _description,
        string memory _uri,
        address _campaignOwner
    )
        external
    {
        require(_price > 0, "Invalid price.");
        require(_finishDate >= block.timestamp + MINCAMPAIGNTIME, "Invalid finish date.");
        require(_maxSupply > 0, "Invalid max supply.");
        require(keccak256(abi.encodePacked(_name)) != keccak256(abi.encodePacked("")), "Invalid name.");
        require(_campaignOwner != address(0), "Invalid Owner Address");

        Campaign memory _newCampaign = Campaign(_price, _discountPercentage, _finishDate, _nextCampaignId, _maxSupply, 0, _name, _description, _campaignOwner);
        _batchIdToCampaign[_nextCampaignId] = _newCampaign;
        _setURI(_nextCampaignId, _uri);
        emit CampaignCreated(_nextCampaignId, _name);

        _nextCampaignId++;
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
        Campaign memory _campaign = _batchIdToCampaign[id];

        uint256 _discount = (_campaign.price * amount) * _campaign.discountPercentage / 100;
        uint256 _fee = _discount * buybackFeePercentage / 100;

        if (_fee > (_campaign.price * amount) * maxBuybackFeePercentage / 100) {
            _fee = (_campaign.price * amount) * maxBuybackFeePercentage / 100;
        }

        uint256 _returnedAmount = _discount - _fee;
        uint256 _ownerAmount = (_campaign.price * amount) - _discount;

        // Transfer funds.
        _currency.transferFrom(account, address(this), _discount);
        _currency.transferFrom(account, _campaign.campaignOwner, _ownerAmount);

        _currency.approve(_revolAddress, _discount);
        Revol(_revolAddress).buyRevolWithFee(_returnedAmount, account, _fee);

        // Update Campaign details.
        _campaign.mintedSupply += amount;

        // Mint NFTs.
        _mint(account, id, amount, data);
        _participatedInCampaign[id][account] += amount;
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

    function setURI(uint256 _campaignId, string memory _newURI) public onlyCampaignOwner(_campaignId) {
        _setURI(_campaignId, _newURI);
    }

    ///////// OVERRIDE FUNCTIONS
    /// @notice returns full token URI, including baseURI and token metadata URI
    /// @param tokenId The token id to get URI for
    /// @return tokenURI the URI of the token
    function uri(uint256 tokenId)
        public
        view
        override(ERC1155Upgradeable, ERC1155URIStorageUpgradeable)
        returns (string memory tokenURI)
    {
        return ERC1155URIStorageUpgradeable.uri(tokenId);
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