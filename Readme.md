# Fibrous Aggregator Contract

This repository includes the contracts used to execute routes found by Fibrous
API. You can visit [testnet.fibrous.finance](https://testnet.fibrous.finance)
to see it in the work.

> **Warning**
> Fibrous is in its early stages of development. Use the code at your own risk.

```
src
├── amm
│   ├── amm_1.cairo
│   ├── amm_1_oracle.cairo
│   └── amm_1_swapper.cairo
├── interfaces
│   ├── ISwapHandler
│   └── ISwapper
│   └── IERC20
├── router.cairo
└── swap_handler.cairo
```

[src/router.cairo](./src/router.cairo) holds the Router contract
that executes a given quote.
<br>
[src/swap_handler.cairo](./src/swap_handler.cairo) executes a single
quotes on a given protocol
<br>
[src/amm](./src/amm) holds the example AMM contracts we demonstrate
our routing algorithm with
<br>

## Contributing

Contributions are very welcome, but as this is a very early version of the code, 
breaking changes by our side is a possibility.