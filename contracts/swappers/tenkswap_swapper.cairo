%lang starknet

// @title 10K Swap Swapper
// @dev Implements ISwapper for 10K Swap

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

@contract_interface
namespace ITenKSwap {
    func swapExactTokensForTokens (
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
    to: felt,
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

    let (timestamp) = get_block_timestamp();

    // Approve tokens to the AMM
    let (success) = IERC20.approve(
        contract_address=token_in,
        spender=0x07a6f98c03379b9513ca84cca1373ff452a7462a3b61598f0af5bb27ad7f76d1,
        amount=amt_in
    );
    assert success = 1;

    let (path) = alloc();
    [path] = token_in;
    [path + 1] = token_out;

    // Do the swap
    ITenKSwap.swapExactTokensForTokens(
        contract_address=0x07a6f98c03379b9513ca84cca1373ff452a7462a3b61598f0af5bb27ad7f76d1,
        amountIn=amt_in,
        amountOutMin=Uint256(0, 0),
        path_len=2,
        path=path,
        to=to,
        deadline=timestamp
    );
    let (out_balance: Uint256) = IERC20.balanceOf(contract_address=token_out, account=to);

    return (amt_out=out_balance);
}