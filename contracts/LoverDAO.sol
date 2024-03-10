// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/governance/GovernorUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorSettingsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorCountingSimpleUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LoverDAO is Initializable, GovernorUpgradeable, GovernorSettingsUpgradeable, GovernorCountingSimpleUpgradeable, GovernorStorageUpgradeable, GovernorVotesUpgradeable, GovernorVotesQuorumFractionUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(IVotes _token, address initialOwner) initializer public {
        __Governor_init("Lover DAO");
        __GovernorSettings_init(0 /* 0 day */, 302400 /* 1 week */, 0);
        __GovernorCountingSimple_init();
        __GovernorStorage_init();
        __GovernorVotes_init(_token);
        __GovernorVotesQuorumFraction_init(4);
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    // The following functions are overrides required by Solidity.

    function votingDelay()
        public
        view
        override(GovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(GovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function quorum(uint256 blockNumber)
        public
        view
        override(GovernorUpgradeable, GovernorVotesQuorumFractionUpgradeable)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    function proposalThreshold()
        public
        view
        override(GovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function _propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description, address proposer)
        internal
        override(GovernorUpgradeable, GovernorStorageUpgradeable)
        returns (uint256)
    {
        return super._propose(targets, values, calldatas, description, proposer);
    }

    struct ContributionProposal {
        address to;
        uint256 amount;
        uint256 average;
        bool executed;
    }

    mapping(uint256 => ContributionProposal) public contributionProposals;

    function proposeCompensation (
        string memory description,
        uint256 amount
    ) public virtual returns (uint256) {
        require(amount > 0, "LoverDAO: Invalid amount");

        // create real proposal with no actions.
        address[] memory targets = new address[](1);
        targets[0] = msg.sender;
        uint256 proposalId = propose(targets, new uint256[](1), new bytes[](1), description);

        // Save contribution proposal.
        contributionProposals[proposalId] = ContributionProposal(targets[0], amount, 0, false);

        return proposalId;
    }

    function castContributionVote(uint256 proposalId, uint8 support, uint8 percentageApproved) public returns (uint256) {
        require(percentageApproved <= 100, "LoverDAO: Invalid percentage");

        // We cast a real vote to ensure all checks are done.
        address voter = _msgSender();
        uint256 weight = _castVote(proposalId, voter, support, "");

        // Add to the average of the proposal in a linear way, where percentageApproved is total amount of tokens approved by the voter * 100. if vote is against, then it is 0.
        contributionProposals[proposalId].average += support == 1 ? percentageApproved * weight : 0;

        return weight;
    }

    function executeCompensation(uint256 _proposalId) public payable {
        // Execute the real proposal. This ensures that all proposal checks are done before executing the contribution proposal.
        execute(_proposalId);
    
        // Get the votes for the proposal.
        (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) = proposalVotes(_proposalId);
        ContributionProposal memory proposal = contributionProposals[_proposalId];

        // Take the amount and multiply by the average percentage of votes for the proposal.
        uint256 totalVotes = againstVotes + forVotes + abstainVotes;
        uint256 contributionAmount = (proposal.amount * (proposal.average / totalVotes)) / 100;

        // Check if the DAO has enough funds to execute the proposal.
        uint256 availableDaoBalance = IERC20(address(token())).balanceOf(address(this));
        require(availableDaoBalance >= contributionAmount, "LoverDAO: Not enough funds to execute proposal");

        // Transfer the funds to the proposer.
        contributionProposals[_proposalId].executed = true;
        IERC20(address(token())).transfer(proposal.to, contributionAmount);
    }
}