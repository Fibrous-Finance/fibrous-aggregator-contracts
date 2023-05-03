%lang starknet

from starkware.cairo.common.uint256 import Uint256

// @notice An interface to swap a token on an exchange
// @dev This must be implemented for each unique exchange
@contract_interface
namespace ISwapper {
    // @notice Swaps between two tokens
    // @param token_in: Address of the incoming token
    // @param token_out: Address of the outcoming token
    // @param amt: Amount of incoming token
    // @returns amt_out: Amount swapped
    func swap(token_in: felt, token_out: felt, pool: felt, amt: Uint256) -> (amt_out: Uint256) {
    }
}