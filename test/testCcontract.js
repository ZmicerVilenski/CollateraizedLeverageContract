const CLC = artifacts.require("CollateralizedLeverage");
const TokenX = artifacts.require("TokenX");
const TokenA = artifacts.require("TokenA");
const helper = require('./utils/utils.js');

contract("CollateralizedLeverage", (accounts) => {

  const deployer = accounts[0];
  const lender1 = accounts[1];
  const lender2 = accounts[2];
  const borrower1 = accounts[3];
  const borrower2 = accounts[4];
  let tokenX_Address, tokenA_Address, clc_Address, tokenX, tokenA, clc;

  const changeTime = async (sec) => {
    const originalBlock = await web3.eth.getBlock('latest');
    await helper.advanceTimeAndBlock(sec); // 
    const newBlock = await web3.eth.getBlock('latest');

    console.log('---------------TIME CHANGING---------------');
    console.log('  before: ', originalBlock.timestamp);
    console.log('  after: ', newBlock.timestamp);
  }

  it("Deploy Tokens and lending contract. Check the owners", async () => {

    console.log('Deployer: ', deployer);

    tokenX = await TokenX.deployed();
    tokenX_Address = tokenX.address;
    tokenA = await TokenA.deployed();
    tokenA_Address = tokenA.address;
    clc = await CLC.deployed();
    clc_Address = clc.address;
    console.log('Token X address: ', tokenX_Address);
    console.log('Token A address: ', tokenA_Address);
    console.log('CLC address: ', clc_Address);

    const ownerX = await tokenX.owner.call();
    console.log('Token X Owner: ', ownerX);
    assert.equal(ownerX, deployer, "Owner not Deployer");

    const ownerA = await tokenA.owner.call();
    console.log('Token A Owner: ', ownerA);
    assert.equal(ownerA, deployer, "Owner not Deployer");

    const ownerCLC = await clc.owner.call();
    console.log('CLC Owner: ', ownerCLC);
    assert.equal(ownerCLC, deployer, "Owner not Deployer");

    // Check balances
    let balOfDeployerA = await tokenA.balanceOf(deployer);
    console.log('Balance of Deployer. Token A: ', BigInt(balOfDeployerA));
    let balOfDeployerX = await tokenX.balanceOf(deployer);
    console.log('Balance of Deployer. Token X: ', BigInt(balOfDeployerX));

  });

  it("Send token to Lenders & Borrowers from the Token Owner", async () => {

    const amount = web3.utils.toWei('1000000', 'ether');
    await tokenX.transfer(lender1, amount, { from: deployer });
    await tokenX.transfer(lender2, amount, { from: deployer });
    // Check Lenders balances
    let balOflender1 = await tokenX.balanceOf(lender1);
    console.log('Balance of lender 1. Token X: ', BigInt(balOflender1));
    let balOflender2 = await tokenX.balanceOf(lender2);
    console.log('Balance of lender 2. Token X: ', BigInt(balOflender2));

    await tokenA.transfer(borrower1, amount, { from: deployer });
    await tokenA.transfer(borrower2, amount, { from: deployer });
    // Check Lenders balances
    let balOfborrower1 = await tokenA.balanceOf(borrower1);
    console.log('Balance of borrower 1. Token A: ', BigInt(balOfborrower1));
    let balOfborrower2 = await tokenA.balanceOf(borrower2);
    console.log('Balance of borrower 2. Token X: ', BigInt(balOfborrower2));

  });

  it("Allowance to CLC for tokens A and X", async () => {

    const amount = web3.utils.toWei('1000000', 'ether');
    await tokenX.approve(clc_Address, amount, { from: lender1 });
    await tokenX.approve(clc_Address, amount, { from: lender2 });
    await tokenA.approve(clc_Address, amount, { from: borrower1 });
    await tokenA.approve(clc_Address, amount, { from: borrower2 });
    const allowanceXL1 = await tokenX.allowance(lender1, clc_Address);
    const allowanceXL2 = await tokenX.allowance(lender2, clc_Address);
    const allowanceAB1 = await tokenA.allowance(borrower1, clc_Address);
    const allowanceAB2 = await tokenA.allowance(borrower2, clc_Address);

    console.log('allowanceXL1: ', BigInt(allowanceXL1));
    console.log('allowanceXL2: ', BigInt(allowanceXL2));
    console.log('allowanceAB1: ', BigInt(allowanceAB1));
    console.log('allowanceAB2: ', BigInt(allowanceAB2));

  });

  it("Add stable tokens X to the pool", async () => {

    const amount1 = web3.utils.toWei('1000', 'ether');
    const duration = 3; // month
    let tx = await clc.AddToPool(amount1, duration,  { from: lender1 });
    //console.log('Logs: ', tx.logs[0].args);
    const amount2 = web3.utils.toWei('2000', 'ether');
    tx = await clc.AddToPool(amount2, duration,  { from: lender2 });
    //console.log('Logs: ', tx.logs[0].args);

    // events
    let options = {fromBlock: 0, toBlock: 'latest'};
    let events = await clc.getPastEvents('AddedToPool', options);
    //1
    let event = events[0].returnValues;
    console.log('--- AddToPool 1 ---');
    console.log('lender:    ', event.loaner);
    console.log('amount:    ', event.amount);
    console.log('timestamp: ', event.timestamp);
    //2
    event = events[1].returnValues;
    console.log('--- AddToPool 2 ---');
    console.log('lender:    ', event.loaner);
    console.log('amount:    ', event.amount);
    console.log('timestamp: ', event.timestamp);
    //

  });

  it("Take collateral loan", async () => {

    let id = 0;
    // let loanStructure = await clc.getLoanById(id);
    // console.log('loanStructure: ', loanStructure);
     
    let tx = await clc.TakeCollateralLoan(id,  { from: borrower1 });
    //console.log('Logs: ', tx.logs[0].args);
    id = 1;
    tx = await clc.TakeCollateralLoan(id,  { from: borrower2 });
    //console.log('Logs: ', tx.logs[0].args);

    // events
    let options = {fromBlock: 0, toBlock: 'latest'};
    let events = await clc.getPastEvents('CollateralLoanTaken', options);
    //1
    let event = events[0].returnValues;
    console.log('--- CollateralLoanTaken 1 ---');
    console.log('borrower:  ', event.borrower);
    console.log('amountX:   ', event.amountX);
    console.log('amountA:   ', event.amountA);
    console.log('timestamp: ', event.timestamp);
    //2
    event = events[1].returnValues;
    console.log('--- CollateralLoanTaken 2 ---');
    console.log('borrower:  ', event.borrower);
    console.log('amountX:   ', event.amountX);
    console.log('amountA:   ', event.amountA);
    console.log('timestamp: ', event.timestamp);
    //

  });

  it("Try to withdraw by lender", async () => {
    // I'm sorry, I didn't have time to test further. Was very busy. If you give me more time, I will finish next week.
  });

});