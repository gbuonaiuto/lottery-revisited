// things not working:
// Fallback function does not send eth to jackpot (80% of msg.value)
// getLastWinAmount does not show last win amount - check if that's used for events as well?


pragma solidity ^0.4.24;

// Ethereum Lottery.
//
// - 1 out of 10 chance to win half of the JACKPOT! And every 999th ticket grabs 80% of the JACKPOT!
//
// - The house fee is 1% of the ticket price, 1% reserved for transactions.
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
    event bigWin(uint wonAmount);

    // Public variables
    uint public houseFee = 0;
    uint public jackpot = 0;
    address public lastWinner;
    uint public lastWinInWei = 0;
    uint public totalAmountWonInWei = 0;
    uint public totalNumberOfWins = 0;
    address[] public players;
    mapping (uint => address) public ticketToAddress;

    // Set odds as 1 divided by Odds variable
    uint public smallWinOdds = 10;
    uint public bigWinOdds = 100;

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
        require(msg.value == 0.01 ether);

        // House edge + Jackpot (2% is reserved for transactions)
        jackpot = safeAdd(jackpot, safeDiv(safeMul(msg.value, 98), 100));
        houseFee = safeAdd(houseFee, safeDiv(msg.value, 100));

        // Declare entrant as msg.sender as it's used several times and computing it only once saves Gas
        address entrant = msg.sender;

        // Owner does not participate in the play, only adds up to the JACKPOT
        if(entrant == manager) return;

        // Increasing the ticket number
        entryTicket++;

        // Adding address to players
        players.push(entrant);

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
            lastWinInWei = amountWon;
            totalNumberOfWins++;
            totalAmountWonInWei = safeAdd(totalAmountWonInWei, amountWonSpecialPrize);

            // Pay the winning
            entrant.transfer(amountWonSpecialPrize);

            // Call event
            emit callWinner(lastWinner);
            emit bigWin(amountWonSpecialPrize);

            return;
        } else {

            if(randomNumber % smallWinOdds == 0) {
                // We have a WINNER !!!

                // Calculate the prize money
                uint amountWon = safeDiv(safeMul(jackpot, 50), 100);
                if(safeSub(address(this).balance, houseFee) < amountWon) {
                    amountWon = safeDiv(safeMul(safeSub(address(this).balance, houseFee), 50), 100);
                }

                jackpot = safeSub(jackpot, amountWon);

                // Set the statistics
                lastWinner = entrant;
                lastWinInWei = amountWon;
                totalNumberOfWins++;
                totalAmountWonInWei = safeAdd(totalAmountWonInWei, amountWon);

                // Pay the winning
                entrant.transfer(amountWon);

                // Call event
                emit callWinner(lastWinner);
                emit smallWin(amountWon);
            }

            return;
        }
    }

    function () public payable {
      houseFee = safeAdd(houseFee, safeDiv(safeMul(msg.value, 20), 100));
      jackpot = safeAdd(jackpot, safeDiv(safeMul(msg.value, 80), 100));
    }

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

    function getPlayers() view public returns (address[]) {
        return players;
    }


    // Owner functions
    function gethouseFee() view public onlyOwner returns (uint256) {
        return houseFee;
    }

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

    function setBigWinOdds(uint bigOdds) public onlyOwner {
      bigWinOdds = bigOdds;
    }

    function killContract() public onlyOwner {
        selfdestruct(manager);
    }
}
