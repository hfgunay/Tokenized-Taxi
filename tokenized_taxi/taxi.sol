// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract TaxiInvestment {

    // address of contractOwner
    address public contractOwner;

    // current total money in cotract that has not been distributed
    uint balance;

    uint maintenanceFee;

    uint lastMaintenanceTime;

    // last divident pay time
    uint lastDividentPay;

    uint participationFee;

    // the 32 digit number ID of car
    uint32 carID;

    address payable carDealer;
    
    // proposal for a new car by the car dealer
    Proposal proposedCar;

    // proposal for car repurchase by the car dealer
    Proposal proposedRepurchase;

    // current driver of taxi
    Driver taxiDriver;


    // list of addresses of participants for use while vote counting
    address[] participantsInGroup;

    mapping (address => Participant) participants;

    // votes for checks user whether voted or not
    mapping (address => bool) driverVotes;
    mapping (address => bool) carVotes;
    mapping (address => bool) repurchaseVotes;

  
    /*
    struct for participants

    holds address, balance and boolean joined
    */
    struct Participant{
        address adr;
        uint balance;
        bool joined;
    }
    /*
    struct for drivers

    holds drivers address,salary, currentBalance, approvalState and lastSalaryTime
    */

    struct Driver{
        address payable driverAddress;
        uint salary;
        uint currentBalance;
        uint approvalState;
        bool isApproved;
        uint lastSalaryTime;
    }
    /*
    struct for propasal

    holds 32 digit id, price, valid time and approval state
    */

    struct Proposal {
        uint32 id;
        uint price;
        uint validTime;
        uint approvalState;
    }
    // modifier to check participant wheter joined to business or not

    modifier isJoined() {
        require(!participants[msg.sender].joined, "You already joined" );
        _;
    }
    // modifier to check if caller is contractOwner
    modifier isContractOwner {
        require(msg.sender == contractOwner, "Caller is not contractOwner");
        _;
    }
    // modifier to check if caller is car dealer

    modifier isCarDealer() {
        require(msg.sender == carDealer, "Caller is not car dealer");
        _;
    }

    // modifier to check if caller is participant
    modifier isParticipant() {
        require(participants[msg.sender].joined, "Caller is not participant");
        _;
    }
    // modifier to check approved situation wheter a taxi driver approved or not
    modifier anyTaxiDriver() {
        require(!taxiDriver.isApproved, "There is a approved Taxi Driver already");
        _;
    }
    // modifier to check if caller is driver
    modifier isDriver() {
        require(msg.sender == taxiDriver.driverAddress, "Caller is not driver");
        _;
    }

    

    constructor() {
        contractOwner = msg.sender;
        balance = 0;
        lastMaintenanceTime = block.timestamp;
        lastDividentPay = block.timestamp;
        maintenanceFee = 10 ether;
        participationFee = 40 ether;
    }

    /*
     max 9 participants can join
     caller of this function must pay ether
     
    */

    function join() public payable isJoined{
        require(participantsInGroup.length < 10, "No more place to join");
        require(msg.value >= participationFee, "Not enough ether to join");
        participants[msg.sender] = Participant(msg.sender, 0 ether, true);
        participantsInGroup.push(msg.sender);
        balance += participationFee;
        uint refund = msg.value - participationFee;
        if (refund >= 0 ) payable(msg.sender).transfer(refund);

    }

    /*
     only manager can call this function
     sets carDealer
    */
    function setCarDealer(address payable dealer) public isContractOwner {
        carDealer = dealer;
    }

    /*
     proposes car to business
     only car dealer can call this function
    */

    function carProposeToBusiness(uint32 id, uint price, uint validTime) public isCarDealer {
        require(carID == 0, "There is already a car");
        proposedCar = Proposal(id, price, validTime, 0);
        for(uint i = 0; i < participantsInGroup.length; i++){
            carVotes[participantsInGroup[i]] = false;
        }
    }



    function approvePurchaseCar() public isParticipant {
        require(!carVotes[msg.sender], "You already voted for car");
        proposedCar.approvalState += 1;
        carVotes[msg.sender] = true;
    }

    /*
     purchases proposed car and sends ether to car dealer
     only contractOwner can call this function
    */

    function purchaseCar() public isContractOwner {
        require(balance >= proposedCar.price, "The group don't have enough ether");
        require(block.timestamp <= proposedCar.validTime, "The valid time exceeded");
        require(proposedCar.approvalState > (participantsInGroup.length / 2), "The proposal didn't approved more than half of the group");
        balance -= proposedCar.price;
        if(!carDealer.send(proposedCar.price)){
            balance += proposedCar.price;
            revert();
        }
        carID = proposedCar.id;
    }

     /*
     the car dealer proposes a repurchase
     only car dealer can call this function
     resets votes
     */

    function repurchaseCarPropose(uint32 id, uint price, uint validTime) public isCarDealer{
        require(carID == id, "This is not the owned car");
        proposedRepurchase = Proposal(id, price, validTime, 0);
         for(uint i = 0; i < participantsInGroup.length; i++){
            repurchaseVotes[participantsInGroup[i]] = false;
        }
    }
    /*
     approves repurchase proposal
     only participants can call this function
    */

    function approveSellProposal() public isParticipant {
        require(!repurchaseVotes[msg.sender], "You already voted");
        proposedRepurchase.approvalState += 1;
        repurchaseVotes[msg.sender] = true;
    }

    /**
     repurchases current car
     only car dealer can call this function
     */

    function repurchaseCar() public payable isCarDealer {
        require(block.timestamp <= proposedRepurchase.validTime, "The valid time exceeded");
        require(proposedRepurchase.approvalState > (participantsInGroup.length / 2), "The proposal didn't approved more than half of the business");
        require(msg.value >= proposedRepurchase.price, "Value is not enough");
        uint refund =  msg.value - proposedRepurchase.price;
        if(refund >= 0) payable(msg.sender).transfer(refund);
        balance += msg.value - refund;
        delete carID;
    }

     /*
     proposes a driver
     only contractOwner can call this function
     resets votes
     */

    function proposeDriver(address payable driverAddress, uint salary) public isContractOwner anyTaxiDriver{
        taxiDriver = Driver(driverAddress, salary, 0, 0, false, block.timestamp);
        for(uint i = 0; i < participantsInGroup.length; i++){
            driverVotes[participantsInGroup[i]] = false;
        }
    }
    function approveDriver() public isParticipant {
        require(!driverVotes[msg.sender], "You already voted");
        taxiDriver.approvalState += 1;
        driverVotes[msg.sender] = true;
    }

    function setDriver() public isContractOwner anyTaxiDriver{
        require(taxiDriver.driverAddress != address(0), "There is no driver");
        require(taxiDriver.approvalState > (participantsInGroup.length / 2), "The driver didn't approved more than half of the participants");
        taxiDriver.isApproved = true;
    }
    // fires current driver and sends his/her balance
    // only contractOwner can call this function

    function fireDriver() public isContractOwner  {
        require(taxiDriver.isApproved, "There is no driver!");
        balance -= taxiDriver.salary;
        if(!taxiDriver.driverAddress.send(taxiDriver.salary)){
            balance += taxiDriver.salary;
            revert();
        }
        
        delete taxiDriver;
    }

    // customers call this function to pay charge

    function getCharge() public payable {
        balance += msg.value;
    }

    /*
     adds monthly salary to drivers balance
     only contractOwner can call this function
    */


    function releaseSalary() public isContractOwner {
        require(taxiDriver.isApproved, "There is no taxi driver");
        require(balance >= taxiDriver.salary, "Not enough balance to pay driver salary");
        require(block.timestamp - taxiDriver.lastSalaryTime >= 2629743, "It must be 1 month after the last payment");
        balance -= taxiDriver.salary;
        taxiDriver.currentBalance += taxiDriver.salary;
        taxiDriver.lastSalaryTime = block.timestamp;
    }
    
    /*
     sends the drivers salary to drivers account
     only driver can call this function
    */
    function getSalary() public isDriver {
        require(taxiDriver.currentBalance > 0, "There is no ether in driver balance");
        taxiDriver.driverAddress.transfer(taxiDriver.currentBalance);
        taxiDriver.currentBalance = 0;
    }

     /*
     pays 10 ether to car dealer every 6 month
     only contractOwner can call this function
     */

    function payCarExpenses() public isContractOwner {
        require(block.timestamp - lastMaintenanceTime >= 15778463, "It must be 6 month after the last payment");
        require(carID != 0, "There is no car to pay expense");
        require(balance >= maintenanceFee, "Not enough balance to pay expenses");
        balance -= maintenanceFee;
        if(!carDealer.send(maintenanceFee)){
            balance += maintenanceFee;
            revert();
        }
        lastMaintenanceTime = block.timestamp;
    }
    /**
     * sends dividend to each participants for every 6 months
     * only contractOwner can call this function
     */

    function payDividend() public isContractOwner {
        require(block.timestamp - lastDividentPay >= 15778463, "Dividends paid already");
        require(balance > 0, "Not enough balance");
        require(balance > participationFee * participantsInGroup.length, "There is no profit right now");
        uint dividend = (balance - (participationFee * participantsInGroup.length)) / participantsInGroup.length;
        for(uint i = 0; i < participantsInGroup.length; i++){
            participants[participantsInGroup[i]].balance += dividend;
        }
        balance = 0;
        lastDividentPay = block.timestamp;
    }
    /*
     participants can get their dividend to own account 
     only participants can call this function
    */

    function getDividend() public payable isParticipant {
        require(participants[msg.sender].balance > 0, "There is no ether in your balance");
        if(!payable(msg.sender).send(participants[msg.sender].balance)){
            revert();
        }
        participants[msg.sender].balance = 0;
    }

    // fallback and receive functions

    fallback () external payable {
    }
    receive() external payable {
        
    }

}