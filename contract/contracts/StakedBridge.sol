// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract StakedBridge {
    uint256 public constant USER_AMOUNT = 1e16; // 0.01 eth registration fee
    uint256 public constant BRIDGE_AMOUNT = 1e17; // 0.1 eth stake
    uint256 public constant AMT_PER_BLOCK = 30 gwei; // the amount that the bridges will get per block of providing their services

    mapping(uint32 => bool) users;
    mapping(address => Bridge) bridges;

    event NewUser(uint32 indexed ip, address user);
    event NewBridge(uint32 indexed ip);

    // avg rating under 2 with atleast 20 votes is a bad rating
    struct Rating {
        uint32 ratingSum;
        uint32 totalRatings;
    }

    struct Bridge {
        uint32 ip;
        uint256 lastClaimBlock;
        Rating rating;
    }

    address owner;

    constructor() {
        owner = msg.sender;
    }

    function registerAsUser(uint32 ip) public payable {
        require(msg.value == USER_AMOUNT, "Insufficient ETH sent");
        users[ip] = true;
        emit NewUser(ip, msg.sender);
    }

    function registerAsBridge(uint32 ip) public payable {
        require(msg.value == BRIDGE_AMOUNT, "Insufficient ETH sent");

        bridges[msg.sender] = Bridge(ip, block.number, Rating(0, 0));

        emit NewBridge(ip);
    }

    function rateBridge(address bridgeAddress, uint8 rating) public {
        require(rating > 0 && rating <= 5, "Rating out of range");
        require(bridges[bridgeAddress].ip != 0, "Invalid bridge");

        Rating memory bridgeRating = bridges[bridgeAddress].rating;
        bridgeRating.ratingSum += rating;
        bridgeRating.totalRatings += 1;

        // avg rating is less than 2, remove bridge and consume its stake
        if (bridgeRating.ratingSum < 2 * bridgeRating.totalRatings) {
            delete bridges[bridgeAddress];
        }
    }

    function claimRewards() public {
        require(bridges[msg.sender].ip != 0, "You are not a bridge");

        uint256 blocksElapsed = block.number -
            bridges[msg.sender].lastClaimBlock;

        bridges[msg.sender].lastClaimBlock = block.number; // prevent reentrancy attack by placing this block above the pay tx
        payable(msg.sender).transfer(blocksElapsed * AMT_PER_BLOCK);
    }

    function withdrawFunds() public {
        require(msg.sender == owner, "Only the owner can withdraw funds");
        payable(owner).transfer(address(this).balance);
    }
}
