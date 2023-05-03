%lang starknet

/// @title Router
/// Contract to route swaps

from openzeppelin.access.ownable.library import Ownable
from openzeppelin.token.erc20.IERC20 import IERC20

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_le
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_contract_address,
    get_tx_info
)
from contracts.interfaces.ISwapHandler import ISwapHandler, Swap, SwapParams

// Storage Variables
////////////////////////////////////////////////////////////////////////////////

@storage_var
func _swap_handler() -> (swap_handler: felt) {
}

// Constructor
////////////////////////////////////////////////////////////////////////////////

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(owner: felt) {
    Ownable.initializer(owner);
    return ();
}

// Views
////////////////////////////////////////////////////////////////////////////////

@view
func get_owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (owner: felt) {
    return Ownable.owner();
}

@view
func get_swap_handler{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    swap_handler: felt
) {
    return _swap_handler.read();
}

// Externals
////////////////////////////////////////////////////////////////////////////////

@external
func set_swap_handler{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_handler: felt
) {
    Ownable.assert_only_owner();
    _swap_handler.write(value=new_handler);
    return ();
}

// @notice Routes the swap requests to the swap handler and makes sure it is valid
// @param swaps  : Swap[]        Swap requests
// @param params : SwapParams    Swap parameters
// @dev The rate inside the Swap struct is the rate wrt. balance in the contract
//      Therefore in a 40/60/20 splitted sequence of swaps, rate field of swaps
//      would be 40/75/100, as after each swap, balance would change
//      40 / 100 => 40%
//      60 /  80 => 75%
//      20 /  20 => 100%
@external
func swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    swaps_len: felt,
    swaps: Swap*,
    params: SwapParams
) {
    alloc_locals;

    // Get the swap handler
    let (swap_handler: felt) = _swap_handler.read();
    // Get the caller account address
    let (caller: felt) = get_caller_address();
    // Get this contract's address
    let (this_address: felt) = get_contract_address();

    // Transfer tokens from user to router
    let (success) = IERC20.transferFrom(
        contract_address=params.token_in,
        sender=caller,
        recipient=this_address,
        amount=params.amount
    );
    assert success = 1;

    // Approve tokens to swap handler
    let (success) = IERC20.approve(
        contract_address=params.token_in,
        spender=swap_handler,
        amount=params.amount
    );
    assert success = 1;

    // Call swap handler to handle swaps
    ISwapHandler.swap(
        contract_address=swap_handler, 
        swaps_len=swaps_len,
        swaps=swaps,
        params=params
    );

    // IERC20.balanceOf revokes the syscall_ptr
    local syscall_ptr: felt* = syscall_ptr;
    let (after_balance: Uint256) = IERC20.balanceOf(
        contract_address=params.token_out, account=this_address
    );

    // Assert if minimum receive amount is reached, otherwise error
    with_attr error_message("Minimum receive amount not reached") {
        let (min_received: felt) = uint256_le(params.min_received, after_balance);
        assert min_received = 1;
    }

    // Send tokens to the destination
    let (success) = IERC20.transfer(
        contract_address=params.token_out,
        recipient=params.destination, 
        amount=after_balance
    );
    assert success = 1;

    return ();
}