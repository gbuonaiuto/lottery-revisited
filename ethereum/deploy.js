const HDWalletProvider = require('truffle-hdwallet-provider');
const Web3 = require('web3');
const compiledGenesisContract = require('./build/Lottery.json');

const provider = new HDWalletProvider(
  'Mnemonic Passphrase',
  'Rinkeby Infura API Key url'
);
const web3 = new Web3(provider);

const deploy = async () => {
  const accounts = await web3.eth.getAccounts();

  console.log('Attempting to deploy from account', accounts[0]);

  const result = await new web3.eth.Contract(
    JSON.parse(compiledGenesisContract.interface)
  )
    .deploy({ data: compiledGenesisContract.bytecode })
    .send({ gas: '1000000', from: accounts[0] });

  console.log('Contract deployed to', result.options.address);
};
deploy();
