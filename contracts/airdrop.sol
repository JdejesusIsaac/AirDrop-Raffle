// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract VibraPawn is VRFConsumerBaseV2, KeeperCompatibleInterface {
    VRFCoordinatorV2Interface COORDINATOR;

    uint64 s_subscriptionId;
    address vrfCoordinator = 0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D;
    bytes32 keyHash = 0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;
    uint32 callbackGasLimit = 500000;
    uint16 requestConfirmations = 3;
    uint256[] public stagedContests;
    address s_owner;
    mapping(uint256 => uint256) s_requestIdToContestIndex;
    uint256 public requestCounter;
    mapping(uint256 => uint256) private remaining;    
    mapping(uint256 => uint256) private movedIndices;
    //bytes32 public merkleRoot;
    //string public provenanceHash = '';
 
    event WinnerEvent(address[] winners);
    event AddedContestant(address contestant, uint256 index);
    event RemovedContestant(address contestant, uint256 index);
    event CreatedCampaign(address contestIndex);
    event RemovedCampaign(address contestIndex);

    struct AirDropCampaign {
        string contestName;
        uint256 numberOfWinners;
        address[] contestantsAddresses;
        uint256[] winners;
        uint256 announcementDate;
        bool contestDone;
        string imageURL;
        uint256 prizeWorth;
        uint256 randomSeed;
        bool contestStaged;
        uint contestantSettlement; // 0 = offchain, 1 = onchain
    } 

    AirDropCampaign[] public airdropCampaigns;
    
    // 1 Configure airdrop campaign - (UNIX Timestamp of September 23, 2022 = 1663892265)
    // 2 Add contestants - ["0xF0f21f80FC665cc6C042A68Ff76381E12eF2243b", "0x9f326a8c853664c65a483820135118a4e5807bf8", "0xd33c6fadc43519548f9bce7f61f19b5fc55025a1", "0xc2bebdef7bb0361bc7a50f4ff1e3c90877704f2d", "0x9f326a8c853664c65a483820135118a4e5807bf8", "0x9ffa78acff5363ff64ccf3a358c53de12422b1c3"]
    // 3 Stop contest
    // 4 Draw contest
    
    constructor(uint64 subscriptionId) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_owner = msg.sender;
        s_subscriptionId = subscriptionId;
    }
    
    modifier onlyOwner() {
        require(msg.sender == s_owner);
        _;
    }

    /**
    function setProvenanceHash(string memory _provenanceHash) public onlyOwner {
        require(bytes(provenanceHash).length == 0, "The provenance hash can be set only once");
        provenanceHash = _provenanceHash;
    }

    function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function merkleProof(bytes32[] calldata _merkleProof) public view returns(bool) {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(_merkleProof, merkleRoot, leaf), "Invalid proof!");
        return true;
        //whitelistClaimed[_msgSender()] = true;
        //_safeMint(_msgSender(), _mintAmount);
    }
    **/

    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory performData ) {
        if (stagedContests.length > 0) {
            upkeepNeeded = true;
            if (block.timestamp < airdropCampaigns[stagedContests[0]].announcementDate) {
                performData = abi.encodePacked(stagedContests[0]);
            } else { 
                upkeepNeeded = false;
                performData = abi.encodePacked("0x");
            }
        } else {
            upkeepNeeded = false;
            performData = abi.encodePacked("0x");
        } 
        return (upkeepNeeded, performData);
    }

    function performUpkeep(bytes calldata performData) external override {
        if (stagedContests.length > 0) {
            (uint256 contestIndex) = abi.decode(performData, (uint256));
            stagedContests[0] = stagedContests[stagedContests.length - 1];
            stagedContests.pop();
            // airdropCampaigns[contestIndex].winners = tempWinners;
            for (uint i = 0; i < remaining[contestIndex] - 1; i++) {
                airdropCampaigns[contestIndex].winners[i] = _draw(contestIndex);
            }
        }
    }

    // Configure Contestants and number of winners and Name Of Airdrop Campaign, AnnouncementDate
    function configureNewAirdrop(string memory nameOfContest, uint256 winnersCount, address[] memory contestantAddressArray, uint256 dateOfAnnouncement, string memory imageURL, uint256 prizeWorth, uint contestantSettlement) external onlyOwner {
        //require(contestantSettlement >= 0, "settlement strategy required. select 0 or 1");
        uint256[] memory _winners;
        uint256 _randomSeed;
        AirDropCampaign memory campaign = AirDropCampaign(nameOfContest, winnersCount, contestantAddressArray, _winners, dateOfAnnouncement, false, imageURL, prizeWorth, _randomSeed, false, contestantSettlement);
        airdropCampaigns.push(campaign);
        requestCounter += 1;
    }

    // Stop the contest so that contestants can no longer be added to the campaign
    function stopContest(uint256 contestIndex) external onlyOwner {
        require(airdropCampaigns[contestIndex].randomSeed == 0, "RandomSeed cannot be overwritten");
        require(airdropCampaigns[contestIndex].contestStaged == false, "Cannot stop a contest more than once");
        uint256 requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            1
        );
        s_requestIdToContestIndex[requestId] = airdropCampaigns.length - 1;
        airdropCampaigns[contestIndex].contestDone = true;
        remaining[contestIndex] = airdropCampaigns[contestIndex].contestantsAddresses.length;
    }
  
    function fulfillRandomWords(
        uint256 requestId, 
        uint256[] memory randomWords
    ) internal override {
        uint256 contestIndexFromRequestId = s_requestIdToContestIndex[requestId];
        airdropCampaigns[contestIndexFromRequestId].randomSeed = randomWords[0];
        airdropCampaigns[contestIndexFromRequestId].contestStaged = true;
        stagedContests.push(contestIndexFromRequestId);
    }

    function isContestant(uint contestIndex, address contestant )  public view returns (bool)  {
        require(contestIndex < airdropCampaigns.length , "Out of bounds");
        bool result = false;
        uint length = airdropCampaigns[contestIndex].contestantsAddresses.length;
        for (uint i = 0; i < length; i++){
            if(airdropCampaigns[contestIndex].contestantsAddresses[i] == contestant){
            	result=true;
            	break;
            }
        }
        return result;
    }

    function removeContestant(uint contestIndex, address contestantAddress) external onlyOwner {
        require(contestIndex < airdropCampaigns.length , "Out of bounds");
        require(airdropCampaigns[contestIndex].contestDone == false , "Contest Ended");
        uint length = airdropCampaigns[contestIndex].contestantsAddresses.length;
        address[] memory addressesOfThisContest = new address[](length-1);
        uint k=0;
        for (uint i = 0; i < length; i++){
            if(airdropCampaigns[contestIndex].contestantsAddresses[i] != contestantAddress){
            addressesOfThisContest[k] = airdropCampaigns[contestIndex].contestantsAddresses[i];
            k++;
            }
        }
        airdropCampaigns[contestIndex].contestantsAddresses = addressesOfThisContest;
    }

    function addContestant(uint contestIndex, address contestantAddress) external onlyOwner {
        require(airdropCampaigns[contestIndex].contestDone == false, "Contest Ended");
        require(contestIndex < airdropCampaigns.length, "Out of bounds");
        bool doesListContainElement = false;
        address[] memory list = airdropCampaigns[contestIndex].contestantsAddresses;
        for (uint i=0; i < list.length; i++) {
        if (contestantAddress == list[i]) {
            doesListContainElement = true;
            break;
            }
        }
        require(doesListContainElement == false, "Contestant already registered for this contest");
        airdropCampaigns[contestIndex].contestantsAddresses.push(contestantAddress);
    }

    function _drawContest() public view returns(uint256, uint256[] memory) {
        require(stagedContests.length > 0, "No contests staged");
        uint256 contestIndex = stagedContests[0];
        require(airdropCampaigns[contestIndex].winners.length == 0 , "Winners already drawn");
        require(contestIndex < airdropCampaigns.length , "Contest out of bounds");
        require(airdropCampaigns[contestIndex].contestStaged == true, "Contest not staged");
        
        uint256[] memory shuffled;

        if (airdropCampaigns[contestIndex].contestantSettlement == 0) {
            shuffled = _shuffle(airdropCampaigns[contestIndex].contestantsAddresses.length - 1, airdropCampaigns[contestIndex].randomSeed);
        } else if (airdropCampaigns[contestIndex].contestantSettlement == 1) {
            shuffled = _shuffle(airdropCampaigns[contestIndex].contestantsAddresses.length - 1, airdropCampaigns[contestIndex].randomSeed);
        }

        uint256[] memory tempWinners = new uint256[](airdropCampaigns[contestIndex].numberOfWinners);

        for (uint256 i = 0; i < airdropCampaigns[contestIndex].numberOfWinners; i++) {
            tempWinners[i] = shuffled[i] - 1;
        }

        return (contestIndex, tempWinners);
    }

    function _shuffle(uint size, uint entropy) private pure returns (uint[] memory) {
        uint[] memory result = new uint[](size); 

        for (uint i = 0; i < size; i++) {
            result[i] = i + 1;
        }
        
        bytes32 random = keccak256(abi.encodePacked(entropy));
        
        uint last_item = size - 1;
        
        for (uint i = 1; i < size - 1; i++) {
            uint selected_item = uint(random) % last_item;
            uint aux = result[last_item];
            result[last_item] = result[selected_item];
            result[selected_item] = aux;
            last_item --;
            random = keccak256(abi.encodePacked(random));
        }
        return result;
    }

    function _indexAt(uint256 i) private view returns (uint256) {
        if (movedIndices[i] != 0) {
            return movedIndices[i];
        } else {
            return i;
        }
    }

    // Draw another "card" without replacement
    function _draw(uint256 contestIndex) private returns (uint256) {
        require(remaining[contestIndex] > 0, "All cards drawn");
        uint256 i = airdropCampaigns[contestIndex].randomSeed;
        uint256 outIndex = _indexAt(i);
        movedIndices[i] = _indexAt(remaining[contestIndex] - 1);
        movedIndices[remaining[contestIndex] - 1] = 0;
        remaining[contestIndex] -= 1;
        return outIndex;
    }

    function removeAirDropCampaign(uint contestIndex) external onlyOwner {
        require(contestIndex < airdropCampaigns.length, "Out of bounds");
        for (uint i = contestIndex; i < airdropCampaigns.length-1; i++){
            airdropCampaigns[i] = airdropCampaigns[i+1];
        }
        airdropCampaigns.pop();
    }

    function getWinnersIndex(uint contestIndex) external view returns(address[] memory) {
        require(airdropCampaigns[contestIndex].contestDone == true, "Contest not drawn yet");
        address[] memory tempWinners = new address[](airdropCampaigns[contestIndex].numberOfWinners);
        for (uint256 i = 0; i < airdropCampaigns[contestIndex].numberOfWinners; i++) {
            tempWinners[i] = airdropCampaigns[contestIndex].contestantsAddresses[airdropCampaigns[contestIndex].winners[i]];
            }
        return tempWinners;
    }

    function getWinnersPublicKeysOnChain(uint contestIndex) external view returns(address[] memory) {
        require(airdropCampaigns[contestIndex].contestDone == true, "Contest not drawn yet");
        address[] memory tempPublicKeys;
        for (uint i=0; i < airdropCampaigns[contestIndex].winners.length; i++) {
            uint256 _winner = airdropCampaigns[contestIndex].winners[i];
            tempPublicKeys[i] = (airdropCampaigns[contestIndex].contestantsAddresses[_winner]);  
        }
        return tempPublicKeys;
    }

    function getContestantAddresses(uint256 contestIndex) external view returns(address[] memory contestantsAddresses) {
        contestantsAddresses = airdropCampaigns[contestIndex].contestantsAddresses;
        return contestantsAddresses;
    } 
}