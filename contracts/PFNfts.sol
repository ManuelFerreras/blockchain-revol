// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PFNfts is ERC1155, Ownable {
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

    uint256 private _nextCampaignId = 0;
    uint256 private _trasuryFee = 0;
    uint256 private _liquidityFee = 0;

    address private _treasuryAddress;
    address private _liquidityAddress;


    ///////// CONSTRUCTOR
    constructor(address initialOwner, address currency) ERC1155("PFNfts") Ownable(initialOwner) {
        _currency = IERC20(currency);
    }


    ///////// EVENTS
    event CampaignCreated(uint256 id, string name);


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
        
        uint256 _liquidityAmount;
        uint256 _treasuryAmount;
        uint256 _ownerAmount;

        _mint(account, id, amount, data);
        _participatedInCampaign[id][msg.sender] += amount;
    }

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
        require(_finishDate >= block.timestamp, "Invalid finish date.");
        require(_maxSupply > 0, "Invalid max supply.");
        require(keccak256(abi.encodePacked(_name)) != keccak256(abi.encodePacked("")), "Invalid name.");
        require(_campaignOwner != address(0), "Invalid Owner Address");

        Campaign memory _newCampaign = Campaign(_price, _finishDate, _nextCampaignId, _maxSupply, 0, _name, _description, _campaignOwner);
        _batchIdToCampaign[_nextCampaignId] = _newCampaign;
        _nextCampaignId++;

        emit CampaignCreated(_nextCampaignId, _name);
    }

    // Function to call when using an NFT in a store.
    function usePFNft(uint256 batch, uint256 amount) external {
        _burn()
    } 


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
}