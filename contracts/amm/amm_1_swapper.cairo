%lang starknet

// @title AMM1 Swapper
// @dev Implements ISwapper for AMM1

from openzeppelin.access.ownable.library import Ownable
from openzeppelin.token.erc20.IERC20 import IERC20

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero, assert_not_equal, assert_lt
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.uint256 import Uint256

from starkware.starknet.common.syscalls import get_caller_address, get_contract_address

// AMM1 Interface
////////////////////////////////////////////////////////////////////////////////

@contract_interface
namespace AMM_1 {
    func swap(token_from: felt, amount_from: Uint256) -> (amount_to: Uint256) {
    }
}

// Externals
////////////////////////////////////////////////////////////////////////////////

@external
func swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_in: felt, token_out: felt, pool: felt, amt_in: Uint256
) -> (amt_out: Uint256) {
    with_attr error_message("Same token provided") {
        assert_not_equal(token_in, token_out);
    }

    with_attr error_message("Token in is undefined") {
        assert_not_zero(token_in);
    }

    with_attr error_message("Token out is undefined") {
        assert_not_zero(token_out);
    }

    with_attr error_message("Pool is undefined") {
        assert_not_zero(pool);
    }

    let (caller) = get_caller_address();
    let (this_address) = get_contract_address();

    // Approve tokens to the AMM
    let (success) = IERC20.approve(contract_address=token_in, spender=pool, amount=amt_in);
    assert success = 1;

    // Do the swap
    let (amt_out: Uint256) = AMM_1.swap(
        contract_address=pool, token_from=token_in, amount_from=amt_in
    );

    let (out_balance: Uint256) = IERC20.balanceOf(contract_address=token_out, account=this_address);

    return (amt_out=out_balance);
}