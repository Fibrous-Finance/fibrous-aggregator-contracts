%lang starknet

// @title MySwap Swapper
// @dev Implements ISwapper for MySwap

from openzeppelin.access.ownable.library import Ownable
from openzeppelin.token.erc20.IERC20 import IERC20

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero, assert_not_equal, assert_lt
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.uint256 import Uint256, uint256_mul_div_mod

from starkware.starknet.common.syscalls import get_caller_address, get_contract_address

// AMM Interface
////////////////////////////////////////////////////////////////////////////////

@contract_interface
namespace IMySwap {
    func swap(pool_id: felt, token_from_addr: felt, amount_from: Uint256, amount_to_min: Uint256) {
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

    let (this_address) = get_contract_address();

    // Approve tokens to the AMM
    let (success) = IERC20.approve(
        contract_address=token_in,
        spender=0x010884171baf1914edc28d7afb619b40a4051cfae78a094a55d230f19e944a28,
        amount=amt_in
    );
    assert success = 1;

    let ( min_amount_lo: Uint256, _, _) = uint256_mul_div_mod(
        amt_in,
        Uint256(80, 0),
        Uint256(100,0)
    );

    // Do the swap
    IMySwap.swap(
        contract_address=0x010884171baf1914edc28d7afb619b40a4051cfae78a094a55d230f19e944a28,
        pool_id=pool, 
        token_from_addr=token_in,
        amount_from=amt_in,
        amount_to_min=min_amount_lo
    );

    let (out_balance: Uint256) = IERC20.balanceOf(contract_address=token_out, account=this_address);

    return (amt_out=out_balance);
}