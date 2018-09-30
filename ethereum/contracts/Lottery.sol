pragma solidity ^0.4.24;

// Main issues: impossible to deploy contract due to excessive gas expenditure - fixing bugs in functions to be more gas efficient

// Ethereum State Lottery
//
// A revised version lottery - more similar to a scratcher -, working with different odds for different premium sizes.
// All of the premium sizes are more convenient (by orders of magnitude) compared to current state lotteries (also due to no taxes being levied on winnings),
// yet the creation of an ever increasing jackpot is possible thanks to the distribution mechanisms developed in the contract, that is,
// a part of the jackpot is never released - and thus continuously accrues to increase premium size.
//
// - 1 out of 10 chance to win 5% of the jackpot, 1 out of 100 chance to win 25% of the jackpot, 1 out of 10000 chance to win 80% of the jackpot.
//
// - The house fee is 1% of the ticket price, 1% reserved for gas transactions.
//
// - The winnings are distributed by the Smart Contract automatically.
//
// - Smart Contract address:
// - More details at: https://etherscan.io/address/
//
// - NOTE: Ensure sufficient gas limit for transaction to succeed. Gas limit 150000 should be sufficient.
//
// --- GOOD LUCK! ---
//


// Math operations with safety checks
contract SafeMath {
  function safeMul(uint a, uint b) pure internal returns (uint) {
    uint c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function safeDiv(uint a, uint b) pure internal returns (uint) {
    assert(b > 0);
    uint c = a / b;
    assert(a == b * c + a % b);
    return c;
  }

  function safeSub(uint a, uint b) pure internal returns (uint) {
    assert(b <= a);
    return a - b;
  }

  function safeAdd(uint a, uint b) pure internal returns (uint) {
    uint c = a + b;
    assert(c>=a && c>=b);
    return c;
  }
}

contract Lottery is SafeMath {

    // Events declaration
    event callWinner(address winnerAddress);
    event smallWin(uint wonAmount);
    event mediumWin(uint wonAmount);
    event bigWin(uint wonAmount);

    // Public variables
    uint public houseFee = 0;
    uint public jackpot = 0;
    address public lastWinner;
    uint public lastWinInWei = 0;
    uint public totalAmountWonInWei = 0;
    uint public totalNumberOfWins = 0;
    uint public players = 0;
    mapping (uint => address) public ticketToAddress;
    address[] public winners;
    mapping (address => string) public winnersType;
    mapping (address => uint) public winnersAmount;
    uint public ticketSizeRequested = 0.01 ether;

    // Keep track of wins
    uint public smallWins = 0;
    uint public mediumWins = 0;
    uint public bigWins = 0;

    // Set odds as 1 divided by Odds variable
    uint public smallWinOdds = 10;
    uint public mediumWinOdds = 100;
    uint public bigWinOdds = 10000;

    // Internal variables
    bool private gameOn = true;
    address private manager;
    uint private entryTicket = 0;
    uint private value = 0;

    constructor() public {
        manager = msg.sender;
    }

    modifier onlyOwner() {
     require(msg.sender == manager, "Only the manager of the contract is authorized to send this transaction.");
     _;
    }

    function enterLottery() public payable {
        // Only accept ticket purchases if the game is ON
        require(gameOn == true);

        // Price of the ticket is 0.01 ETH
        require(msg.value == ticketSizeRequested);

        // House edge + Jackpot (2% is reserved for transactions)
        jackpot = safeAdd(jackpot, safeDiv(safeMul(msg.value, 98), 100));
        houseFee = safeAdd(houseFee, safeDiv(msg.value, 100));

        // Declare entrant as msg.sender as it's used several times and computing it only once saves Gas
        address entrant = msg.sender;

        // Owner does not participate in the play, only adds up to the JACKPOT
        if(entrant == manager) return;

        // Increasing the ticket number
        entryTicket++;

        // Updating players count
        players++;

        // Adding address to mapping
        ticketToAddress[entryTicket] = entrant;

        // Get the lucky number
        uint randomNumber = uint(keccak256(abi.encodePacked(safeAdd(block.number, uint(lastWinner)), blockhash(block.number))));

        // Let's see if the ticket is the 999th...
        if(randomNumber % bigWinOdds == 0) {
            // We have a WINNER !!!

            // Calculate the prize money
            uint amountWonSpecialPrize = safeDiv(safeMul(jackpot, 80), 100);
            jackpot = safeSub(jackpot, amountWonSpecialPrize);

            // Set the statistics
            lastWinner = entrant;
            lastWinInWei = amountWonSpecialPrize;
            totalNumberOfWins++;
            totalAmountWonInWei = safeAdd(totalAmountWonInWei, amountWonSpecialPrize);
            bigWins++;
            winners.push(entrant);
            winnersType[entrant] = "Big Win";
            winnersAmount[entrant] = amountWonSpecialPrize;

            // Pay the winning
            entrant.transfer(amountWonSpecialPrize);

            // Call event
            emit callWinner(lastWinner);
            emit bigWin(amountWonSpecialPrize);

            return;

            } else if(randomNumber % mediumWinOdds == 0) {
                    // We have a WINNER !!!

                    // Calculate the prize money
                    uint amountWonMediumPrize = safeDiv(safeMul(jackpot, 25), 100);
                    if(safeSub(address(this).balance, houseFee) < amountWonMediumPrize) {
                        amountWonMediumPrize = safeDiv(safeMul(safeSub(address(this).balance, houseFee), 50), 100);
                    }

                    jackpot = safeSub(jackpot, amountWonMediumPrize);

                    // Set the statistics
                    lastWinner = entrant;
                    lastWinInWei = amountWonMediumPrize;
                    totalNumberOfWins++;
                    totalAmountWonInWei = safeAdd(totalAmountWonInWei, amountWonMediumPrize);
                    mediumWins++;
                    winners.push(entrant);
                    winnersType[entrant] = "Medium Win";
                    winnersAmount[entrant] = amountWonMediumPrize;

                    // Pay the winning
                    entrant.transfer(amountWonMediumPrize);

                    // Call event
                    emit callWinner(lastWinner);
                    emit mediumWin(amountWonMediumPrize);

                    return;

        } else if(randomNumber % smallWinOdds == 0) {
                // We have a WINNER !!!

                // Calculate the prize money
                uint amountWonSmallPrize = safeDiv(safeMul(jackpot, 5), 100);
                if(safeSub(address(this).balance, houseFee) < amountWonSmallPrize) {
                    amountWonSmallPrize = safeDiv(safeMul(safeSub(address(this).balance, houseFee), 50), 100);
                }

                jackpot = safeSub(jackpot, amountWonSmallPrize);

                // Set the statistics
                lastWinner = entrant;
                lastWinInWei = amountWonSmallPrize;
                totalNumberOfWins++;
                totalAmountWonInWei = safeAdd(totalAmountWonInWei, amountWonSmallPrize);
                smallWins++;
                winners.push(entrant);
                winnersType[entrant] = "Small Win";
                winnersAmount[entrant] = amountWonSmallPrize;

                // Pay the winning
                entrant.transfer(amountWonSmallPrize);

                // Call event
                emit callWinner(lastWinner);
                emit smallWin(amountWonSmallPrize);

                return;

            } else {

            return;
        }
    }

    function () public payable {}
      // jackpot = safeAdd(jackpot, safeDiv(safeMul(msg.value, 80), 100));
      // houseFee = safeAdd(houseFee, safeDiv(safeMul(msg.value, 20), 100));

    function getBalance() view public returns (uint256) {
        return address(this).balance;
    }

    function getTotalTickets() view public returns (uint256) {
        return entryTicket;
    }

    function getLastWinAmount() view public returns (uint256) {
        return lastWinInWei;
    }

    function getLastWinner() view public returns (address) {
        return lastWinner;
    }

    function getTotalAmountWon() view public returns (uint256) {
        return totalAmountWonInWei;
    }

    function getTotalWinsCount() view public returns (uint256) {
        return totalNumberOfWins;
    }

    function getNumOfPlayers() view public returns (uint256) {
        return players;
    }


    // Owner functions

    function stopGame() public onlyOwner {
        gameOn = false;
        return;
    }

    function startGame() public onlyOwner {
        gameOn = true;
        return;
    }

    function transferhouseFee(uint amount) public onlyOwner payable {
        require(amount <= houseFee);
        require(safeSub(address(this).balance, amount) > 0);

        manager.transfer(amount);
        houseFee = houseFee - amount;
    }

    function setSmallWinOdds(uint smallOdds) public onlyOwner {
      smallWinOdds = smallOdds;
    }

    function setMediumWinOdds(uint mediumOdds) public onlyOwner {
      mediumWinOdds = mediumOdds;
    }

    function setBigWinOdds(uint bigOdds) public onlyOwner {
      bigWinOdds = bigOdds;
    }

    function seTicketSizeRequested(uint requestedWei) public {
      ticketSizeRequested = uint(requestedWei);
    }

    function killContract() private onlyOwner {
        selfdestruct(manager);
    }
}
