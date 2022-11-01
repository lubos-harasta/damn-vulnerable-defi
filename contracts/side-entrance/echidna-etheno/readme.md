## Guideline

1.  Write a deployment script (see [side-entrance.js](../../../deploy/side-entrance.js)).
2.  Start etheno by running the following command:

```
etheno --ganache --ganache-args="--miner.blockGasLimit 10000000" -x init.json
```

> it will start generating data into `init.json` file located in the directory from the etheno was run.

3. Deploy the deployment script in another terminal by running:

```
yarn hardhat run ./deploy/side-entrance.js --network localhost
```

> do not forget to add `localnetwork` with url `http://127.0.0.1:8545` to [hardhat.config.js](../../../hardhat.config.js).

4. Exit etheno and copy the generated `init.json` to the folder with echidna tests + specify path to it in [config.yaml](config.yaml).
5. Start Echidna in docker running (see [`yarn toolbox`](../../../package.json)).
6. Select compiler `solc-select use 0.8.7`.
7. Run echidna fuzzer by running the following command in the docker:
   1. my solution: `npx hardhat clean && npx hardhat compile --force && echidna-test /src --contract EchidnaEthenoSideEntranceLenderPool --config /src/contracts/side-entrance/echidna-etheno/config.yaml`;
   2. tutorial solution `npx hardhat clean && npx hardhat compile --force && echidna-test /src --contract E2E --config /src/contracts/side-entrance/echidna-etheno/config-tutorial.yaml`.
