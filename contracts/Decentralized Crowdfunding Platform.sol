// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Project {
    struct Campaign {
        address payable creator;
        string title;
        string description;
        uint256 goalAmount;
        uint256 raisedAmount;
        uint256 deadline;
        bool isActive;
        bool goalReached;
        mapping(address => uint256) contributions;
        address[] contributors;
    }

    mapping(uint256 => Campaign) public campaigns;
    uint256 public campaignCount;
    uint256 public platformFee = 25; // 2.5% platform fee (25/1000)

    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        string title,
        uint256 goalAmount,
        uint256 deadline
    );

    event ContributionMade(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );

    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 amount
    );

    event RefundClaimed(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );

    modifier campaignExists(uint256 _campaignId) {
        require(_campaignId < campaignCount, "Campaign does not exist");
        _;
    }

    modifier onlyCreator(uint256 _campaignId) {
        require(
            campaigns[_campaignId].creator == msg.sender,
            "Only campaign creator can call this function"
        );
        _;
    }

    // Core Function 1: Create a new crowdfunding campaign
    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _goalAmount,
        uint256 _durationInDays
    ) public returns (uint256) {
        require(_goalAmount > 0, "Goal amount must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");
        require(bytes(_title).length > 0, "Title cannot be empty");

        uint256 campaignId = campaignCount;
        Campaign storage newCampaign = campaigns[campaignId];
        
        newCampaign.creator = payable(msg.sender);
        newCampaign.title = _title;
        newCampaign.description = _description;
        newCampaign.goalAmount = _goalAmount;
        newCampaign.raisedAmount = 0;
        newCampaign.deadline = block.timestamp + (_durationInDays * 1 days);
        newCampaign.isActive = true;
        newCampaign.goalReached = false;

        campaignCount++;

        emit CampaignCreated(
            campaignId,
            msg.sender,
            _title,
            _goalAmount,
            newCampaign.deadline
        );

        return campaignId;
    }

    // Core Function 2: Contribute funds to a campaign
    function contribute(uint256 _campaignId) 
        public 
        payable 
        campaignExists(_campaignId) 
    {
        Campaign storage campaign = campaigns[_campaignId];
        
        require(campaign.isActive, "Campaign is not active");
        require(block.timestamp < campaign.deadline, "Campaign has ended");
        require(msg.value > 0, "Contribution must be greater than 0");
        require(
            msg.sender != campaign.creator,
            "Creator cannot contribute to their own campaign"
        );

        // Track new contributors
        if (campaign.contributions[msg.sender] == 0) {
            campaign.contributors.push(msg.sender);
        }

        campaign.contributions[msg.sender] += msg.value;
        campaign.raisedAmount += msg.value;

        // Check if goal is reached
        if (campaign.raisedAmount >= campaign.goalAmount) {
            campaign.goalReached = true;
        }

        emit ContributionMade(_campaignId, msg.sender, msg.value);
    }

    // Core Function 3: Withdraw funds (for successful campaigns) or claim refunds (for failed campaigns)
    function withdrawFunds(uint256 _campaignId) 
        public 
        campaignExists(_campaignId) 
    {
        Campaign storage campaign = campaigns[_campaignId];
        
        if (msg.sender == campaign.creator) {
            // Creator withdrawal logic
            require(campaign.goalReached, "Goal not reached");
            require(campaign.raisedAmount > 0, "No funds to withdraw");
            require(campaign.isActive, "Campaign already finalized");

            uint256 totalAmount = campaign.raisedAmount;
            uint256 feeAmount = (totalAmount * platformFee) / 1000;
            uint256 creatorAmount = totalAmount - feeAmount;

            campaign.raisedAmount = 0;
            campaign.isActive = false;

            // Transfer funds to creator
            campaign.creator.transfer(creatorAmount);

            emit FundsWithdrawn(_campaignId, campaign.creator, creatorAmount);
        } else {
            // Contributor refund logic
            require(
                block.timestamp >= campaign.deadline,
                "Campaign still active"
            );
            require(!campaign.goalReached, "Campaign was successful");
            require(
                campaign.contributions[msg.sender] > 0,
                "No contribution found"
            );

            uint256 refundAmount = campaign.contributions[msg.sender];
            campaign.contributions[msg.sender] = 0;
            campaign.raisedAmount -= refundAmount;

            payable(msg.sender).transfer(refundAmount);

            emit RefundClaimed(_campaignId, msg.sender, refundAmount);
        }
    }

    // View functions
    function getCampaignDetails(uint256 _campaignId)
        public
        view
        campaignExists(_campaignId)
        returns (
            address creator,
            string memory title,
            string memory description,
            uint256 goalAmount,
            uint256 raisedAmount,
            uint256 deadline,
            bool isActive,
            bool goalReached,
            uint256 contributorsCount
        )
    {
        Campaign storage campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.title,
            campaign.description,
            campaign.goalAmount,
            campaign.raisedAmount,
            campaign.deadline,
            campaign.isActive,
            campaign.goalReached,
            campaign.contributors.length
        );
    }

    function getContribution(uint256 _campaignId, address _contributor)
        public
        view
        campaignExists(_campaignId)
        returns (uint256)
    {
        return campaigns[_campaignId].contributions[_contributor];
    }

    function getCampaignContributors(uint256 _campaignId)
        public
        view
        campaignExists(_campaignId)
        returns (address[] memory)
    {
        return campaigns[_campaignId].contributors;
    }

    // Check if campaign deadline has passed
    function isCampaignExpired(uint256 _campaignId)
        public
        view
        campaignExists(_campaignId)
        returns (bool)
    {
        return block.timestamp >= campaigns[_campaignId].deadline;
    }

    // Get platform fee percentage
    function getPlatformFee() public view returns (uint256) {
        return platformFee;
    }
}
