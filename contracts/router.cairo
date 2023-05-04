%lang starknet

/// @title Router
/// Contract to route swaps

from openzeppelin.access.ownable.library import Ownable
from openzeppelin.token.erc20.IERC20 import IERC20
from openzeppelin.token.erc721.IERC721 import IERC721

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_le,
    uint256_add,
    uint256_sub,
    uint256_mul_div_mod,
    assert_uint256_eq
)
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_contract_address,
    get_tx_info
)
from contracts.interfaces.ISwapHandler import ISwapHandler, Swap, SwapParams

const FEE_EXTENSION = 10 ** 6;

// Storage Variables
////////////////////////////////////////////////////////////////////////////////

@storage_var
func _swap_handler() -> (swap_handler: felt) {
}

@storage_var
func _stark_rocks_address() -> (stark_rocks_address: felt) {
}

@storage_var
func _accrued_fees(token: felt, lo_hi: felt) -> (accrued_fees: felt) {
}

/// @notice Fee charged for each swap
/// @dev It is a value between 0 and FEE_EXTENSION
/// @dev If the fee is x percent, the value stored in the storage variable
///      is x * FEE_EXTENSION / 100
@storage_var
func _router_fee() -> (router_fee: felt) {
}

// Constructor
////////////////////////////////////////////////////////////////////////////////

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt,
    stark_rocks_address: felt,
    router_fee: felt,
) {
    Ownable.initializer(owner);

    _router_fee.write(value=router_fee);
    _stark_rocks_address.write(value=stark_rocks_address);

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

@view
func get_router_fee{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    router_fee: felt
) {
    return _router_fee.read();
}

@view
func get_stark_rocks_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    stark_rocks_address: felt
) {
    return _stark_rocks_address.read();
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

@external
func set_router_fee{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_router_fee: felt
) {
    Ownable.assert_only_owner();
    _router_fee.write(value=new_router_fee);
    return ();
}

@external
func set_stark_rocks_address{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_address: felt
) {
    Ownable.assert_only_owner();
    _stark_rocks_address.write(value=new_address);
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

    let (accrued_fees_lo) = _accrued_fees.read(params.token_out, 0);
    let (accrued_fees_hi) = _accrued_fees.read(params.token_out, 1);

    let accrued_fees_before: Uint256 = Uint256(accrued_fees_lo, accrued_fees_hi);

    // Calculate amount to be received by user and fee amount
    let (output_amount) = uint256_sub(after_balance, accrued_fees_before);
    let (receive_amount, fee_amount) = calculate_output(output_amount, swaps_len);

    // Update accrued fees
    // @dev Here, carry can't be 1 realistically, so we're skipping the check
    let (accrued_fees_after, _) = uint256_add(accrued_fees_before, fee_amount);
    _accrued_fees.write(params.token_out, 0, accrued_fees_after.low);
    _accrued_fees.write(params.token_out, 1, accrued_fees_after.high);

    // Send tokens to the destination
    let (success) = IERC20.transfer(
        contract_address=params.token_out,
        recipient=params.destination, 
        amount=receive_amount
    );
    assert success = 1;

    return ();
}

/// @notice Allows the owner to claim the tokens in the contract
/// @param token       : felt  Token to claim
/// @param destination : felt  Destination to send the tokens to
@external
func claim{ syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr }(
    token: felt,
    destination: felt
) {
    Ownable.assert_only_owner();

    let (this_address) = get_contract_address();

    let (this_token_balance) = IERC20.balanceOf(
        contract_address=token,
        account=this_address,
    );

    let (success) = IERC20.transfer(
        contract_address=token,
        recipient=destination,
        amount=this_token_balance,
    );
    assert success = 1;

    // Reset accrued fees
    _accrued_fees.write(token, 0, 0);
    _accrued_fees.write(token, 1, 0);

    return ();
}

// Helpers
////////////////////////////////////////////////////////////////////////////////

/// @notice Calculates the output amount after fees
/// @param amount         : felt  Amount to calculate output for
/// @param is_direct      : felt  Whether the swap is direct or not
/// @return output_amount : felt  Output amount after fees
/// @dev Fee rules:
///     - Direct swaps have no fees
///     - If tx origin has a StarkRocks NFT, there is no fee
///     - Otherwise fee is read from _router_fee storage variable
func calculate_output{ syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr }(
    amount: Uint256,
    swaps_len: felt
) -> (
    output_amount: Uint256,
    fee_amount: Uint256,
) {
    alloc_locals;

    if (swaps_len == 1) {
        return (output_amount=amount, fee_amount=Uint256(0,0));
    }
    
    let (tx_info) = get_tx_info();
    let (stark_rocks_address) = _stark_rocks_address.read();

    let (stark_rocks_balance) = IERC721.balanceOf(
        contract_address=stark_rocks_address,
        owner=tx_info.account_contract_address
    );

    // If tx origin has a StarkRocks NFT, there is no fee
    if (stark_rocks_balance.low != 0) {
        return (output_amount=amount, fee_amount=Uint256(0,0));
    }

    let (router_fee) = _router_fee.read();
    let (
        local output_fee_lo: Uint256,
        local output_fee_hi: Uint256,
        local output_fee_rem: Uint256
    ) = uint256_mul_div_mod(
        amount,
        Uint256(router_fee, 0),
        Uint256(FEE_EXTENSION,0)
    );

    // `router_fee` should be a very small number compared to `amount` so there
    // should be no remainder and division result should be less then 2**256
    with_attr error_message("Fee calculation overflow") {
        assert_uint256_eq(Uint256(0,0), output_fee_hi);
        assert_uint256_eq(Uint256(0,0), output_fee_rem);
    }

    // `output_amount` = `amount` * `router_fee` / `FEE_EXTENSION`
    let (output_amount) = uint256_sub(amount, output_fee_lo);

    return (output_amount=output_amount, fee_amount=output_fee_lo);
}