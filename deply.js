const hre = require("hardhat");

async function main() {
  //deploy the Token Contract
  const Token = await ethers.getContractFactory("Token");
  Token = await Token.deploy("Token", "TKN", (10 ** 18).toString());
  await Token.deployed();

  //deploy the exchange contract
  const Exchange = await hre.ethers.getContractFactory("Exchange");
  const greeter = await Exchange.deploy(Token.address);

  await greeter.deployed();

  console.log("Exchange deployed to:", greeter.address);

  //wait for 30secs
  await sleep(30*1000);

  //verifying the contracts on Etherscan
  await hre.run("verify:verify", {
    address: Token.address,
    constructorArguments: [],
    contract: "C:\Users\deepa\OneDrive\Desktop\HardHat\Contracts\Token.sol",
  });

  await hre.run("verify:verify", {
    address: Exchange.address, 
    constructorArguments: [Exchange.address], 
  });
}


//to ensure proper working and handling the errors
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });