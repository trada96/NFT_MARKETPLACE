const Auction = artifacts.require("AuctionContract");
const truffleAssert = require('truffle-assertions');
require('dotenv').config();

contract("Land Auction TestCase",async ([account_owner, account_one, account_two, account_three, account_four]) => {
    beforeEach(async () => {
        contract = await Auction.new(process.env.LANDNFT_ADDRESS, account_owner, process.env.AUCTION_FEE, process.env.EXTRA_TIME, process.env.PERCENT_PRICE);

    });


    function sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
    // =============================
    it("Aution By Owner", async () => {
        await contract.createAuction(1, 1 , 2, 3, {from: account_owner});
        await contract.createAuction(2, 1 , 2, 3, {from: account_owner});
        await contract.createAuction(3, 1 , 2, 3, {from: account_owner});

        const aution1 =  await contract.auctions(1);
        const aution2 =  await contract.auctions(2);
        const aution3 =  await contract.auctions(3);


        assert.equal(aution1.seller, account_owner);
        assert.equal(aution2.seller, account_owner);
        assert.equal(aution3.seller, account_owner);

    });

    // =============================
    it("Aution By Other", async () => {
        await truffleAssert.reverts(contract.createAuction(1, 1 , 2, 3, {from: account_one}), "Reason given: Ownable: caller is not the owner");
        await truffleAssert.reverts(contract.createAuction(1, 1 , 2, 3, {from: account_two}), "Reason given: Ownable: caller is not the owner");
        await truffleAssert.reverts(contract.createAuction(1, 1 , 2, 3, {from: account_three}), "Reason given: Ownable: caller is not the owner");
    });

    // =============================
    it("Aution By Require", async () => {
        await truffleAssert.reverts(contract.createAuction(1, 0 , 2, 3, {from: account_owner}), "Auction: startTime must be granter than zero");
        await truffleAssert.reverts(contract.createAuction(1, 1 , 0, 3, {from: account_owner}), "Auction: endTime must be granter than zero");
        await truffleAssert.reverts(contract.createAuction(1, 1 , 2, 0, {from: account_owner}), "Auction: price must be granter than zero");
        await truffleAssert.reverts(contract.createAuction(100, 1 , 1, 100, {from: account_owner}), "Auction: endTime must be granter than startTime");

        await contract.createAuction(1, 1 , 2, 3, {from: account_owner});
        await truffleAssert.reverts(contract.createAuction(1, 10 , 200, 1000000, {from: account_owner}), "Auction: token is exist");
    });

    // =============================
    it("Bid Token", async () => {
        var unix = Math.round(+new Date()/1000);
        await contract.createAuction(1, unix - 10 , unix + 10, 3, {from: account_owner});
        await contract.bidOnToken(1, {from: account_one, value: 100});

        let maxBidInfo = await contract.getMaxBid(1);
        assert.equal(maxBidInfo.bidder, account_one);
    });
    // =============================
    it("Bid Token", async () => {
        var unix = Math.round(+new Date()/1000);

        await contract.createAuction(1, unix + 3 , unix + 8, 3, {from: account_owner});
        
        // Bid before startTime
        await truffleAssert.reverts(contract.bidOnToken(1, {from: account_one, value: 10}), "Auction: wait to start");

        await sleep(6000);

        // Check auction  < previous Price
        await contract.bidOnToken(1, {from: account_one, value: 100});
        // Case 1
        await truffleAssert.reverts(contract.bidOnToken(1, {from: account_two, value: 100}), "Auction: your bid amount must be greater highest");

        // add bid amount
        await contract.bidOnToken(1, {from: account_one, value: 200});
        const bidInfo = await contract.getBidByUser(1, account_one);
        
        assert.equal(bidInfo.bidAmount, 300);

        // Case 2
        await contract.bidOnToken(1, {from: account_two, value: 5000});
        await truffleAssert.reverts(contract.bidOnToken(1, {from: account_one, value: 300}), "Auction: your bid amount must be greater highest");
        
        await sleep(10000);
        
        // Bid when ended
        await truffleAssert.reverts(contract.bidOnToken(1, {from: account_one, value: 50000}), "Auction: ended");

    });

    // =============================
    it("Remove Bid", async () => {
        var unix = Math.round(+new Date()/1000);

        const amount1 = 500;
        const amount2 = 1500;
        const amount3 = 5000;

        await contract.createAuction(1, unix -1, unix + 5, 3, {from: account_owner});
        
        // let balance0 = await web3.eth.getBalance(account_one);

        await contract.bidOnToken(1, {from: account_one, value: amount1});
        var bid1 = await contract.getBidByUser(1, account_one);

        assert.equal(bid1.bidder, account_one);
        assert.equal(bid1.bidAmount, amount1);

        await contract.bidOnToken(1, {from: account_two, value: amount2});
        var bid2 = await contract.getBidByUser(1, account_two);
       

        assert.equal(bid2.bidder, account_two);
        assert.equal(bid2.bidAmount, amount2);
        
        await contract.bidOnToken(1, {from: account_three, value: amount3});
        var bid3 = await contract.getBidByUser(1, account_three);
       
        assert.equal(bid3.bidder, account_three);
        assert.equal(bid3.bidAmount, amount3);
        
        console.log("accs", [account_one, account_two, account_three]);
        var biddes = await contract.getAllBidder(1);
        console.log("Bidder0", biddes);
        
        await contract.removeBid(1, {from: account_three});
        bid3 = await contract.getBidByUser(1, account_three);
        assert.equal(bid3.bidAmount, 0);

        biddes = await contract.getAllBidder(1);
        console.log("Bidder1", biddes);

        await contract.removeBid(1, {from: account_one});
        bid1 = await contract.getBidByUser(1, account_one);
        assert.equal(bid1.bidAmount, 0);

        biddes = await contract.getAllBidder(1);
        console.log("Bidder2", biddes);

        await contract.removeBid(1, {from: account_two});
        bid2 = await contract.getBidByUser(1, account_two);
        assert.equal(bid2.bidAmount, 0);

        biddes = await contract.getAllBidder(1);
        console.log("Bidder3", biddes);

        
        // let balance2 = await web3.eth.getBalance(account_one);

    });

    // =============================
    it.only("Claim Bid Token", async () => {
        var unix = Math.round(+new Date()/1000);

        await contract.createAuction(1, unix -1, unix + 5, 3, {from: account_owner});
        
        // Check auction  < previous Price
        await contract.bidOnToken(1, {from: account_one, value: 100});
        await contract.bidOnToken(1, {from: account_two, value: 500});
        await contract.bidOnToken(1, {from: account_three, value: 5000});

        await sleep(10000);

        await contract.claimBidAmount(1, {from: account_one});
        await contract.claimBidAmount(1, {from: account_two});

        await contract.mintNFT(1, {from: account_three});

        const res = await contract.OwnerNFT(1);
        console.log("rest", res, account_three);


    });


});
