<div align="center">
  <h1>Fibrous Finance</h1>
  <h2> Aggregator Contracts gathers all AMMs of Starknet at one place. Written in ✨🐺 Cairo 🦀 </h2>
  <img src="./FibrousLogo.jpg" height="200" width="200">
  <br />
  <a href="https://fibrous.finance/">Try it</a>
  -
  <a href="mailto:support@fibrous.finance">Reach Us</a>
</div>

<div align="center">
<br />

</div>

---

# Fibrous Aggregator Contract

This repository includes the contracts used to execute routes found by Fibrous
API. You can visit [testnet.fibrous.finance](https://testnet.fibrous.finance)
to see it in the work.

> **Warning**
> Fibrous is in its early stages of development. Use the code at your own risk.

```
contracts
├── amm
│   ├── amm_1.cairo
│   ├── amm_1_oracle.cairo
│   └── amm_1_swapper.cairo
├── erc20_self_mintable.cairo
├── interfaces
│   ├── IOracle.cairo
│   ├── ISwapHandler.cairo
│   └── ISwapper.cairo
├── router.cairo
└── swap_handler.cairo
```

[contracts/router.cairo](./contracts/router.cairo) holds the Router contract
that executes a given quote.
<br>
[contracts/swap_handler.cairo](./contracts/swap_handler.cairo) executes a single
quotes on a given protocol
<br>
[contracts/amm](./contracts/amm) holds the example AMM contracts we demonstrate
our routing algorithm with
<br>
[contracts/interfaces](./contracts/interfaces) includes various interfaces used
in the contracts
<br>
[contracts/erc20_self_mintable.cairo](contracts/erc20_self_mintable.cairo)
is the faucet token we use in the application

## Contributing

Contributions are very welcome, but as this is a very early version of the code, 
breaking changes by our side is a possibility.
