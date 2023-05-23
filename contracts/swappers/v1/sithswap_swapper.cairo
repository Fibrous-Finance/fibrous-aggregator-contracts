%lang starknet

// @title SithSwap Swapper
// @dev Implements ISwapper for SithSwap

from openzeppelin.access.ownable.library import Ownable
from openzeppelin.token.erc20.IERC20 import IERC20

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero, assert_not_equal, assert_lt
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.uint256 import Uint256

from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_contract_address,
    get_block_timestamp
)     

// AMM Interface
////////////////////////////////////////////////////////////////////////////////

struct SithRoute {
    from_address: felt,
    to_address: felt,
    stable: felt,
}

@contract_interface
namespace ISithSwap {
    func swapExactTokensForTokensSupportingFeeOnTransferTokens(
        amount_in: Uint256,
        amount_out_min: Uint256,
        routes_len: felt,
        routes: felt*,
        to: felt,
        deadline: felt
    ) {
    }

    func swapExactTokensForTokensSimple(
        amount_in: Uint256,
        amount_out_min: Uint256,
        token_from: felt,
        token_to: felt,
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

    let (local this_address) = get_contract_address();

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

    let (timestamp) = get_block_timestamp();

    // Approve tokens to the AMM
    let (success) = IERC20.approve(
        contract_address=token_in,
        spender=0x028c858a586fa12123a1ccb337a0a3b369281f91ea00544d0c086524b759f627,
        amount=amt_in
    );
    assert success = 1;

    let (path: SithRoute*) = alloc();
    assert path[0] = SithRoute(
        from_address=token_in,
        to_address=token_out,
        stable=0
    );

    ISithSwap.swapExactTokensForTokensSupportingFeeOnTransferTokens(
        contract_address=0x028c858a586fa12123a1ccb337a0a3b369281f91ea00544d0c086524b759f627,
        amount_in=amt_in,
        amount_out_min=Uint256(0,0),
        routes_len=1,
        routes=path,
        to=this_address,
        deadline=timestamp
    );

    let (out_balance: Uint256) = IERC20.balanceOf(contract_address=token_out, account=this_address);

    return (amt_out=out_balance);
}