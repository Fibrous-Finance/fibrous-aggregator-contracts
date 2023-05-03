%lang starknet

// @notice Interface to handle a swap

from starkware.cairo.common.uint256 import Uint256

struct SwapParams {
    token_in: felt,
    token_out: felt,
    amount: Uint256,
    min_received: Uint256,
    destination: felt,
}

// 100 * 10**4 gives 4 precision points
const RATE_EXTENSION = 1000000;

struct Swap {
    token_in: felt,
    token_out: felt,
    rate: felt,
    protocol: felt,
    pool_address: felt,
}

@contract_interface
namespace ISwapHandler {
    func swap(swaps_len: felt, swaps: Swap*, params: SwapParams) {
    }
}