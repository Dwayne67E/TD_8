// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract TicketingSystem {
    // VARIABLES AND STRUCTS
    //An artist as a name, a category and has an address
    struct artist {
        string name;
        uint256 artistCategory;
        address owner;
        uint256 totalTicketSold;
    }

    struct venue {
        string name;
        uint256 capacity;
        uint256 standardComission;
        address payable owner;
    }

    struct concert {
        uint256 artistId;
        uint256 venueId;
        uint256 concertDate;
        uint256 ticketPrice;
        //not declared by user
        bool validatedByArtist;
        bool validatedByVenue;
        uint256 totalSoldTicket;
        uint256 totalMoneyCollected;
    }

    struct ticket {
        uint256 concertId;
        address payable owner;
        bool isAvailable;
        bool isAvailableForSale;
        uint256 amountPaid;
    }

    //Counts number of artists created
    uint256 public artistCount = 0;
    //Counts the number of venues
    uint256 public venueCount = 0;
    //Counts the number of concerts
    uint256 public concertCount = 0;

    uint256 public ticketCount = 0;

    //MAPPINGS & ARRAYS
    mapping(uint256 => artist) public artistsRegister;
    mapping(string => uint256) private artistsID;

    mapping(uint256 => venue) public venuesRegister;
    mapping(string => uint256) private venuesID;

    mapping(uint256 => concert) public concertsRegister;

    mapping(uint256 => ticket) public ticketsRegister;

    mapping(uint256 => bytes32) private redeemCodes;

    //EVENTS
    event CreatedArtist(string name, uint256 id);
    event ModifiedArtist(string name, uint256 id, address sender);
    event CreatedVenue(string name, uint256 id);
    event ModifiedVenue(string name, uint256 id);
    event CreatedConcert(uint256 concertDate, string name, uint256 id);
    event ConcertValidated(uint256 id);
    event TicketBought(uint256 concertId, address buyer, uint256 ticketId);
    event TicketTransferred(uint256 ticketId, address owner, address newOwner); 
    event ConcertCashOut(uint256 concertId, uint256 artistAmount, uint256 venueCommission);


    constructor() {}

    //FUNCTIONS TEST 1 -- ARTISTS

    function createArtist(string memory _name, uint256 _artistCategory) public {
        artistCount ++;
        artistsRegister[artistCount] = artist(_name, _artistCategory, msg.sender, 0);
        artistsID[_name] = artistCount;
        emit CreatedArtist(_name, artistCount);
    }

    function getArtistId(string memory _name) public view returns (uint256 ID) {
        return artistsID[_name];
    }

    function modifyArtist(uint256 _artistId, string memory _name, uint256 _artistCategory/*, address payable _newOwner*/)
        public
    {
        require(msg.sender == artistsRegister[_artistId].owner, "Only owner can modify artist profile"); // Ensure only owner can modify
        artistsRegister[_artistId].name = _name; // Update name
        artistsRegister[_artistId].artistCategory = _artistCategory; // Update artist category
        emit ModifiedArtist(_name, _artistId, msg.sender); // Emit event
    }

    //FUNCTIONS TEST 2 -- VENUES
    function createVenue(string memory _name, uint256 _capacity, uint256 _standardComission) public {
    venueCount++; // Increment venue count
    venuesRegister[venueCount] = venue(_name, _capacity, _standardComission, payable(msg.sender)); // Create venue entry
    venuesID[_name] = venueCount; // Map venue name to ID
    emit CreatedVenue(_name, venueCount); // Emit event
    }

    function getVenueId(string memory _name) public view returns (uint256 ID) {
        return venuesID[_name];
    }

    function modifyVenue(
        uint256 _venueId,
        string memory _name,
        uint256 _capacity,
        uint256 _standardComission,
        address payable _newOwner
    ) public {
        require(msg.sender == venuesRegister[_venueId].owner, "Only owner can modify venue profile"); // Ensure only owner can modify
        venuesRegister[_venueId].name = _name; // Update name
        venuesRegister[_venueId].capacity = _capacity; // Update capacity
        venuesRegister[_venueId].standardComission = _standardComission; // Update standard commission
        venuesRegister[_venueId].owner = _newOwner; // Update owner
        emit ModifiedVenue(_name, _venueId); // Emit event
    }

    //FUNCTIONS TEST 3 -- CONCERTS
    function createConcert(
        uint256 _artistId, 
        uint256 _venueId, 
        uint256 _concertDate, 
        uint256 _ticketPrice
    ) public {
        require(_artistId > 0 && _artistId <= artistCount, "Invalid artist ID");
        require(_venueId > 0 && _venueId <= venueCount, "Invalid venue ID");
        
        // Vérifier que l'artiste et le lieu sont validés
        require(artistsRegister[_artistId].owner != address(0), "Artist does not exist");
        require(venuesRegister[_venueId].owner != address(0), "Venue does not exist");
        
        // Créer un nouvel identifiant pour le concert
        concertCount++;
        uint256 newConcertId = concertCount;
        
        // Enregistrer le concert dans le registre des concerts
        concertsRegister[newConcertId] = concert({
            artistId: _artistId,
            venueId: _venueId,
            concertDate: _concertDate,
            ticketPrice: _ticketPrice,
            validatedByArtist: false,
            validatedByVenue: false,
            totalSoldTicket: 0,
            totalMoneyCollected: 0
        });
        
        // Émettre un événement pour signaler la création du concert
        emit CreatedConcert(_concertDate, venuesRegister[_venueId].name, newConcertId);
    }

    function validateConcert(uint256 _concertId) public {
        // Vérifie que le concert existe
        require(_concertId <= concertCount, "Invalid concert ID");

        // Vérifie que le msg.sender est l'artiste du concert
        require(msg.sender == artistsRegister[concertsRegister[_concertId].artistId].owner, "Only artist can validate concert");

        // Valide le concert en mettant à jour le champ validatedByArtist à true
        concertsRegister[_concertId].validatedByArtist = true;

        // Si le concert est également validé par le lieu, il est prêt à avoir lieu
        if (concertsRegister[_concertId].validatedByVenue) {
            // Émettre un événement pour indiquer que le concert a été validé
            emit ConcertValidated(_concertId);
        }
    }

    //Creation of a ticket, only artists can create tickets
    function emitTicket(uint256 _concertId, address payable _ticketOwner) public {
        // Vérifie que l'artiste est celui qui émet le billet
        require(msg.sender == artistsRegister[concertsRegister[_concertId].artistId].owner, "Only artist can emit ticket");

        // Incrémente le compteur de billets
        ticketCount++;

        // Crée un nouvel objet billet
        ticketsRegister[ticketCount] = ticket(
            _concertId, 
            _ticketOwner, 
            true, // Le billet est disponible
            true, // Le billet est disponible à la vente
            concertsRegister[_concertId].ticketPrice // Montant payé pour le billet
        );
    }

    function useTicket(uint256 _ticketId) public {
        // Vérifie que le billet existe
        require(_ticketId <= ticketCount, "Invalid ticket ID");

        // Vérifie que le billet est utilisable
        require(ticketsRegister[_ticketId].isAvailable, "Ticket is not available");

        // Vérifie que le propriétaire du billet est celui qui utilise le billet
        require(msg.sender == ticketsRegister[_ticketId].owner, "You are not the owner of this ticket");

        // Vérifie que le concert est dans les 24 heures suivant la date du concert
        require(concertsRegister[ticketsRegister[_ticketId].concertId].concertDate - block.timestamp <= 24 hours, "Ticket can only be used within 24 hours before the concert");

        // Marque le billet comme utilisé
        ticketsRegister[_ticketId].isAvailable = false;
    }

    //FUNCTIONS TEST 4 -- BUY/TRANSFER
    function buyTicket(uint256 _concertId) public payable {
        // Vérifier que le concert existe
        require(_concertId <= concertCount, "Invalid concert ID");

        // Vérifier que le montant envoyé est suffisant pour acheter un ticket
        require(msg.value >= concertsRegister[_concertId].ticketPrice, "Insufficient funds");

        // Créer un nouveau ticket
        ticketCount++;
        ticketsRegister[ticketCount] = ticket(_concertId, payable(msg.sender), true, false, msg.value);

        // Mettre à jour le nombre total de tickets vendus pour ce concert
        concertsRegister[_concertId].totalSoldTicket++;

        // Mettre à jour le montant total collecté pour ce concert
        concertsRegister[_concertId].totalMoneyCollected += msg.value;

        // Émettre un événement pour indiquer l'achat de ticket
        emit TicketBought(_concertId, msg.sender, ticketCount);
    }

    function transferTicket(uint256 _ticketId, address payable _newOwner) public {
        // Vérifier que le ticket existe
        require(_ticketId <= ticketCount, "Invalid ticket ID");

        // Vérifier que le msg.sender est le propriétaire du ticket
        require(msg.sender == ticketsRegister[_ticketId].owner, "Only ticket owner can transfer");

        // Mettre à jour le propriétaire du ticket
        ticketsRegister[_ticketId].owner = _newOwner;

        // Émettre un événement pour indiquer le transfert de ticket
        emit TicketTransferred(_ticketId, msg.sender, _newOwner);
    }

    //FUNCTIONS TEST 5 -- CONCERT CASHOUT
    function cashOutConcert(uint256 _concertId) public {
        // Vérifier que le concert existe
        require(_concertId <= concertCount, "Invalid concert ID");

        // Vérifier que le concert est terminé
        require(block.timestamp > concertsRegister[_concertId].concertDate, "Concert not yet finished");

        // Vérifier que le concert n'a pas déjà été encaissé
        require(!concertsRegister[_concertId].validatedByArtist && !concertsRegister[_concertId].validatedByVenue, "Concert already cashed out");

        // Calculer le montant total collecté pour le concert
        uint256 totalAmountCollected = concertsRegister[_concertId].totalMoneyCollected;

        // Calculer la commission standard de la salle
        uint256 venueCommission = (totalAmountCollected * venuesRegister[concertsRegister[_concertId].venueId].standardComission) / 100;

        // Calculer le montant restant pour l'artiste après la commission de la salle
        uint256 artistAmount = totalAmountCollected - venueCommission;

        // Envoyer la commission à la salle
        venuesRegister[concertsRegister[_concertId].venueId].owner.transfer(venueCommission);

        // Envoyer le montant restant à l'artiste
        payable(artistsRegister[concertsRegister[_concertId].artistId].owner).transfer(artistAmount);

        // Marquer le concert comme encaissé par l'artiste et la salle
        concertsRegister[_concertId].validatedByArtist = true;
        concertsRegister[_concertId].validatedByVenue = true;

        // Émettre un événement pour indiquer l'encaissement du concert
        emit ConcertCashOut(_concertId, artistAmount, venueCommission);
    }

    //FUNCTIONS TEST 6 -- TICKET SELLING
    // Fonction pour échanger un ticket contre de l'argent
    function tradeTicketForMoney(uint256 _ticketId, uint256 _sellingPrice) public payable {
        // Vérifier que le ticket existe
        require(_ticketId <= ticketCount, "Invalid ticket ID");

        // Récupérer les détails du ticket
        ticket memory ticketToSell = ticketsRegister[_ticketId];

        // Vérifier que le ticket est disponible à la vente
        require(ticketToSell.isAvailableForSale, "Ticket not available for sale");

        // Vérifier que le prix de vente est inférieur ou égal au prix d'achat
        require(_sellingPrice <= ticketToSell.amountPaid, "Selling price cannot exceed purchase price");

        // Vérifier que l'acheteur a envoyé suffisamment d'argent
        require(msg.value >= _sellingPrice, "Insufficient funds sent");

        // Transférer le ticket au nouvel acheteur
        ticketToSell.owner = payable(msg.sender);
        ticketToSell.isAvailable = false;
        ticketToSell.isAvailableForSale = false;
        ticketToSell.amountPaid = _sellingPrice;

        // Mettre à jour le registre des tickets
        ticketsRegister[_ticketId] = ticketToSell;

        // Rembourser l'excédent d'argent à l'acheteur
        if (msg.value > _sellingPrice) {
            payable(msg.sender).transfer(msg.value - _sellingPrice);
        }

        // Envoyer l'argent au vendeur du ticket
        ticketToSell.owner.transfer(_sellingPrice);
    }

    function setRedeemCode(uint256 _ticketId, string memory _code) public {
    // Vérifie que le ticket existe
    require(_ticketId <= ticketCount, "Invalid ticket ID");

    // Vérifie que le msg.sender est autorisé à définir le code de rachat pour ce ticket
    require(msg.sender == ticketsRegister[_ticketId].owner, "Only ticket owner can set redeem code");

    // Définir le code de rachat pour le ticket donné
    redeemCodes[_ticketId] = keccak256(abi.encodePacked(_code));
    }

    // Fonction pour échanger des tickets distribués
   function redeemTicket(uint256 _ticketId, string memory _redeemCode) public {
    // Vérifier que le ticket existe
    require(_ticketId <= ticketCount, "Invalid ticket ID");

    // Récupérer les détails du ticket
    ticket storage ticketToRedeem = ticketsRegister[_ticketId];

    // Vérifier que le ticket est disponible et n'est pas déjà utilisé
    require(ticketToRedeem.isAvailable, "Ticket not available for redemption");
    require(!ticketToRedeem.isAvailableForSale, "Ticket cannot be redeemed after sale");

    // Vérifier que le code de rachat correspond
    require(keccak256(abi.encodePacked(_redeemCode)) == redeemCodes[_ticketId], "Invalid redeem code");

    // Marquer le ticket comme utilisé
    ticketToRedeem.isAvailable = false;

    // Mettre à jour le registre des tickets
    ticketsRegister[_ticketId] = ticketToRedeem;
    }
}
