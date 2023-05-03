%lang starknet

from openzeppelin.token.erc20.IERC20 import IERC20
from openzeppelin.access.ownable.library import Ownable 

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import (
    Uint256, uint256_unsigned_div_rem, uint256_mul, uint256_add)

from starkware.starknet.common.syscalls import (
    get_caller_address, get_contract_address)

## Storage Variables
################################################################################

@storage_var
func _pool_balance(token: felt) -> (balance: felt):
end

@storage_var
func _token_a() -> (res : felt):
end

@storage_var
func _token_b() -> (res : felt):
end

## Constructor
################################################################################

@constructor
func constructor{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(token_a: felt, token_b: felt, owner: felt):
    _token_a.write(token_a)
    _token_b.write(token_b)

    Ownable.initializer(owner)
    return ()
end

## Views
################################################################################

## @notice Gets the balance of the pool for a token
## @param   token   : felt      address of the token
## @returns balance : Uint256   balance of the pool
@view
func get_token_reserve{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(token: felt) -> (balance: Uint256):
    let (this_address) = get_contract_address()
    let (balance) = IERC20.balanceOf(
        contract_address=token,
        account=this_address)

    return (balance)
end

## @notice Getter for token_a 
## @returns token_a: felt       address of token a
@view
func token_a{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}() -> (token_a: felt):
    let (token_a) = _token_a.read()
    return (token_a)
end

## @notice Getter for token_b 
## @returns token_b: felt       address of token b
@view
func token_b{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}() -> (token_b: felt):
    let (token_b) = _token_b.read()
    return (token_b)
end

## Externals 
################################################################################

## @notice Swaps token_from to token_to
## @param token_from: felt      address of source token
## @param amount_from: Uint256  amount of token given
## @returns amount_to: Uint256  amount of token received
@external
func swap{
    syscall_ptr: felt*, 
    pedersen_ptr: HashBuiltin*, 
    range_check_ptr
}(
    token_from: felt,
    amount_from: Uint256
) -> (
    amount_to: Uint256
):
    alloc_locals
    let (local caller) = get_caller_address()

    _assert_valid_token(token_from)

    # Do the swap
    let (token_to) = get_opposite_token(token=token_from)
    let (amount_to) = _swap(
        account=caller, 
        token_from=token_from, 
        token_to=token_to, 
        amount_from=amount_from)

    return (amount_to=amount_to)
end

## Owner Only 
################################################################################

## @notice Adds liquditiy to a pool
@external
func add_liquidity{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*, 
    range_check_ptr
}(token: felt, liq_amount: Uint256):
    Ownable.assert_only_owner() 
    _assert_valid_token(token)

    let (caller) = get_caller_address()
    let (this_address) = get_contract_address() 
    let (success) = IERC20.transferFrom(
        contract_address=token,
        sender=caller,
        recipient=this_address,
        amount=liq_amount)
    assert success = 1

    return ()
end

## @notice Removes liquditiy from the pool
@external
func remove_liquidity{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*, 
    range_check_ptr
}(token: felt, liq_amount: Uint256):
    Ownable.assert_only_owner() 
    _assert_valid_token(token)

    let (caller) = get_caller_address()
    let (success) = IERC20.transfer(
        contract_address=token,
        recipient=caller,
        amount=liq_amount)
    assert success = 1

    return ()
end



## Internals 
################################################################################

## @dev Revert if invalid token
func _assert_valid_token{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(token: felt):
    let (token_a: felt) = _token_a.read()
    let (token_b: felt) = _token_b.read()

    with_attr error_message("Invalid token"):
        assert (token - token_a) * (token - token_b) = 0
    end

    return ()
end

## @dev Get the opposite token
func get_opposite_token{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(token: felt) -> (opposite: felt):
    let (token_a: felt) = _token_a.read()
    let (token_b: felt) = _token_b.read()

    if token == token_a:
        return (token_b)
    else:
        return (token_a)
    end
end

## @dev Does the swap
func _swap{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(
    account: felt,
    token_from: felt,
    token_to: felt,
    amount_from: Uint256
) -> (
    amount_to: Uint256
):
    alloc_locals
    
    # Get pool balance 
    let (amm_from_balance) = get_token_reserve(token_from)
    let (amm_to_balance) = get_token_reserve(token_to)
    let (from_mul_balance, _) = uint256_mul(amm_to_balance, amount_from)
    let (balance_add_from, _) = uint256_add(amm_from_balance, amount_from)

    # Calculate swap amount
    let (local amount_to, _) = uint256_unsigned_div_rem(
        from_mul_balance, balance_add_from)

    let (this_address) = get_contract_address()

    # Transfer token_from to pool 
    let (success) = IERC20.transferFrom(
        contract_address=token_from,
        sender=account,
        recipient=this_address,
        amount=amount_from)
    assert success = 1

    # Transfer token_to to account 
    let (success) = IERC20.transfer(
        contract_address=token_to,
        recipient=account,
        amount=amount_to)
    assert success = 1

    return (amount_to)
end