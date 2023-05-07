%lang starknet

// @title MySwap Swapper
// @dev Implements ISwapper for MySwap

from openzeppelin.access.ownable.library import Ownable
from openzeppelin.token.erc20.IERC20 import IERC20

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero, assert_not_equal, assert_lt
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.uint256 import Uint256, uint256_mul_div_mod

from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_contract_address,
    get_block_timestamp
)     

// AMM Interface
////////////////////////////////////////////////////////////////////////////////

@contract_interface
namespace IJediSwap {
    func swap_exact_tokens_for_tokens(
        amountIn: Uint256,
        amountOutMin: Uint256,
        path_len: felt,
        path: felt*,
        to: felt,
        deadline: felt
    ) {
    }
}

// Externals
////////////////////////////////////////////////////////////////////////////////

@external
func swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_in: felt,
    token_out: felt,
    pool: felt,
    amt_in: Uint256,
) -> (amt_out: Uint256) {
    alloc_locals;

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

    let (local this_address) = get_contract_address();
    let (timestamp) = get_block_timestamp();

    // Approve tokens to the AMM
    let (success) = IERC20.approve(
        contract_address=token_in,
        spender=0x041fd22b238fa21cfcf5dd45a8548974d8263b3a531a60388411c5e230f97023,
        amount=amt_in
    );
    assert success = 1;

    let (min_amount_lo: Uint256, _, _) = uint256_mul_div_mod(
        amt_in,
        Uint256(80, 0),
        Uint256(100,0)
    );

    let (path) = alloc();
    assert [path] = token_in;
    assert [path + 1] = token_out;

    IJediSwap.swap_exact_tokens_for_tokens(
        contract_address=0x041fd22b238fa21cfcf5dd45a8548974d8263b3a531a60388411c5e230f97023,
        amountIn=amt_in,
        amountOutMin=min_amount_lo,
        path_len=2,
        path=path,
        to=this_address,
        deadline=timestamp
    );

    let (out_balance: Uint256) = IERC20.balanceOf(contract_address=token_out, account=this_address);

    return (amt_out=out_balance);
}