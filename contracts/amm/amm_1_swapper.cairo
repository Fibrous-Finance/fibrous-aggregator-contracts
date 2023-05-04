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

// Storage Variables
////////////////////////////////////////////////////////////////////////////////

@storage_var
func _swap_handler() -> (address: felt) {
}

// Constructor
////////////////////////////////////////////////////////////////////////////////

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt, swap_handler: felt
) {
    Ownable.initializer(caller);
    _swap_handler.write(swap_handler);
    return ();
}

// AMM1 Interface
////////////////////////////////////////////////////////////////////////////////

@contract_interface
namespace AMM_1 {
    func swap(token_from: felt, amount_from: Uint256) -> (amount_to: Uint256) {
    }
}

// Views
////////////////////////////////////////////////////////////////////////////////

@view
func get_swap_handler{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    swap_handler: felt
) {
    let (swap_handler) = _swap_handler.read();
    return (swap_handler,);
}

// Externals
////////////////////////////////////////////////////////////////////////////////

@external
func set_swap_handler{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_swap_handler: felt
) {
    Ownable.assert_only_owner();
    _swap_handler.write(new_swap_handler);
    return ();
}

@external
func swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    token_in: felt, token_out: felt, pool: felt, amt_in: Uint256
) -> (amt_out: Uint256) {
    _assert_only_swap_handler();

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

    // Pull token_in from swap handler
    let (success) = IERC20.transferFrom(
        contract_address=token_in, sender=caller, recipient=this_address, amount=amt_in
    );
    assert success = 1;

    // Approve tokens to the AMM
    let (success) = IERC20.approve(contract_address=token_in, spender=pool, amount=amt_in);
    assert success = 1;

    // Do the swap
    let (amt_out: Uint256) = AMM_1.swap(
        contract_address=pool, token_from=token_in, amount_from=amt_in
    );

    let (out_balance: Uint256) = IERC20.balanceOf(contract_address=token_out, account=this_address);

    // Send tokens back to the handler
    let (success) = IERC20.transfer(
        contract_address=token_out, recipient=caller, amount=out_balance
    );
    assert success = 1;

    return (amt_out=out_balance);
}

// Internals
////////////////////////////////////////////////////////////////////////////////

func _assert_only_swap_handler{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let (caller) = get_caller_address();
    let (swap_handler) = _swap_handler.read();

    with_attr error_message("Only swap handler can call this function") {
        caller = swap_handler;
    }

    return ();
}