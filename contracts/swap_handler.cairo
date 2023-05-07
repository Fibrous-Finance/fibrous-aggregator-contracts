%lang starknet

/// @title Swap Handler
/// @dev Holds the swappers' info and does swaps
/// @dev Implements ISwapHandler

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address

from openzeppelin.access.ownable.library import Ownable
from openzeppelin.token.erc20.IERC20 import IERC20

from contracts.interfaces.ISwapHandler import SwapParams, Swap, RATE_EXTENSION
from contracts.interfaces.ISwapper import ISwapper
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_unsigned_div_rem,
    assert_uint256_eq,
    uint256_mul,
    assert_uint256_lt
)


// STORAGE VARIABLES

// @notice Address of the router, only router can call the swap handler
@storage_var
func _router() -> (router: felt) {
}

/// @notice Stores the classhash of the proxy contract that'll do the swap for
/// each protocol
@storage_var
func _swap_proxies(protocol: felt) -> (proxy_hash: felt) {
}


// CONSTRUCTOR

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt,
    router: felt,
    initial_swap_proxies_len: felt,
    initial_swap_proxies: felt*,
) {
    Ownable.initializer(caller);

    _router.write(router);
    _set_initial_swappers(initial_swap_proxies_len, initial_swap_proxies, 0);

    return ();
}

func _set_initial_swappers{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    initial_swap_proxies_len: felt,
    initial_swap_proxies: felt*,
    idx: felt
) {
    alloc_locals;

    if (idx == initial_swap_proxies_len) {
        return ();
    }

    _swap_proxies.write(idx + 1, initial_swap_proxies[idx]);

    return _set_initial_swappers(initial_swap_proxies_len, initial_swap_proxies, idx + 1);
}

// VIEW FUNCTIONS

@view
func get_owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (owner: felt) {
    let (owner: felt) = Ownable.owner();
    return (owner=owner);
}

@view
func get_swap_proxy{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    protocol: felt
) -> (
    proxy_hash: felt
) {
    let (proxy_hash) = _swap_proxies.read(protocol);
    return (proxy_hash=proxy_hash);
}

// EXTERNAL FUNCTIONS

@external
func set_router{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(new_router: felt) {
    Ownable.assert_only_owner();
    _router.write(new_router);

    return ();
}

@external
func set_swap_proxy{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    protocol: felt, proxy_hash: felt
) {
    Ownable.assert_only_owner();
    _swap_proxies.write(protocol, proxy_hash);

    return ();
}

// @notice Executes a list of swaps
// @param swaps     : Swap[]        List of swaps
// @param params    : SwapParams    Swap parameters
@external
func swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    swaps_len: felt,
    swaps: Swap*,
    params: SwapParams
) {
    alloc_locals;

    // Get the caller address
    let (local caller: felt) = get_caller_address();

    // Get the address of this contract
    let (local this_address: felt) = get_contract_address();

    with_attr error_message("Only router can swap") {
        _assert_only_router(caller);
    }

    // Get starting amount from the router 
    let (router_rcv_success) = IERC20.transferFrom(
        contract_address=params.token_in,
        sender=caller,
        recipient=this_address,
        amount=params.amount
    );
    assert router_rcv_success = 1;

    // Do swaps
    _swap(swaps_len=swaps_len, swaps=swaps);

    // Return balance of token_out to the router
    let (out_balance: Uint256) = IERC20.balanceOf(
        contract_address=params.token_out,
        account=this_address
    );

    let (router_send_success) = IERC20.transfer(
        contract_address=params.token_out,
        recipient=caller,
        amount=out_balance
    );
    assert router_send_success = 1;

    return ();
}

// @notice Goes through each swap and executes it
// @dev Base Case: swaps_len == 0
// @dev For each swap handler approves tokens to the swapper, then it is swapper's responsibility to
//      send the tokens back to the swap handler after the swap
func _swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    swaps_len: felt, swaps: Swap*
) {
    alloc_locals;
    let (local this_address) = get_contract_address();

    if (swaps_len == 0) {
        return ();
    }

    // Get classhash of the proxy contract
    let (proxy_hash) = _swap_proxies.read([swaps].protocol);

    with_attr error_message("Proxy classhash is zero") {
        assert_not_zero(proxy_hash);
    } 

    // Calculate the amount in from the handler's token balance and rate of the swap
    let (src_balance: Uint256) = IERC20.balanceOf(
        contract_address=[swaps].token_in,
        account=this_address
    );
    let (amount_in: Uint256) = _get_amount_in(src_balance, [swaps].rate);

    with_attr error_message("Swap in failed") {
        assert_uint256_lt(Uint256(0,0), amount_in);
    }

    let (amount_out: Uint256) = ISwapper.library_call_swap(
        class_hash=proxy_hash,
        token_in=[swaps].token_in,
        token_out=[swaps].token_out,
        pool=[swaps].pool_address,
        amt=amount_in,
    );

    with_attr error_message("Swap out failed") {
        assert_uint256_lt(Uint256(0,0), amount_out);
    }

    return _swap(swaps_len - 1, swaps + Swap.SIZE);
}

// HELPER FUNCTIONS

// @notice Calculates amount in
// @param amount   : Uint256       Amount of token out
// @param rate     : felt          Rate of the swap
// @dev Amount In = Amount * Rate Extended /  Rate Extension
// @dev Rate of 25.725 would look like 257250 when it is extended
func _get_amount_in{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr} (
    amount: Uint256,
    rate: felt
) -> (amount_in: Uint256) {
    alloc_locals;

    let rate_u256: Uint256 = Uint256(rate, 0);
    let ext_u256: Uint256 = Uint256(RATE_EXTENSION, 0);

    let (local extended: Uint256, carry: Uint256) = uint256_mul(amount, rate_u256);
    with_attr error_message("Overflow on extension") {
        assert_uint256_eq(carry, Uint256(0,0));
    }

    let (amount_in: Uint256, _remainder: Uint256) = uint256_unsigned_div_rem(extended, ext_u256);
    return (amount_in=amount_in);
}

// @notice Asserts if caller is the router
// @param caller   : felt          Address of the caller
func _assert_only_router{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt
) {
    let (router: felt) = _router.read();

    with_attr error_message("Only router can call this function") {
        assert caller = router;
    }

    return ();
}