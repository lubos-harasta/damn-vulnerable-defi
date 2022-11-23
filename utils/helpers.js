const { ethers } = require('hardhat');

/** */
const leakToPrivateKey = (leak) => {
  // console.log(`1. Leaked data: ${leak}`);
  const base64 = Buffer.from(leak.split(` `).join(``), `hex`).toString(`utf8`);
  // console.log(`2. Decoded from hex: ${base64}`);
  const hexKey = Buffer.from(base64, `base64`).toString(`utf8`);
  // console.log(`3. Private key from base64: ${hexKey}`);
  return hexKey;
};

const createWallet = (PK) => {
  // const provider = ethers.getDefaultProvider();
  const newWallet = new ethers.Wallet(PK, ethers.provider);
  // console.log('4. Wallet address derived: ', newWallet.address);
  return newWallet;
};

module.exports = {
  leakToPrivateKey,
  createWallet,
};

// async function main() {
//   for (leakedKey of LEAKED_PKS) {
//     // console.log(leakedKey);
//     const PK = leakToPrivateKey(leakedKey);
//     const wallet = createWallet(PK);
//   }
// }

// main()
//   .then(() => process.exit(0))
//   .catch((error) => {
//     console.error(error);
//     process.exit(1);
//   });
