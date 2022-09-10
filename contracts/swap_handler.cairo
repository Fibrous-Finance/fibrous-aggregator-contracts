%lang starknet

## @title Swap Handler 
## @dev Holds the swappers' info and does swaps
## @dev Implements ISwapHandler

from openzeppelin.access.ownable.library import Ownable
from openzeppelin.token.erc20.IERC20 import IERC20

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.uint256 import Uint256 
from starkware.starknet.common.syscalls import (
    get_caller_address, get_contract_address)

from contracts.interfaces.ISwapHandler import SwapDesc, SwapPath
from contracts.interfaces.ISwapper import ISwapper

## Storage Variables
################################################################################

## @notice Address of the router, only router can call the swap handler
@storage_var
func _router() -> (router: felt):
end

## @notice Each swap has its own address, this mapping stores those
@storage_var
func _swap_addresses(idx: felt) -> (swap_address: felt):
end

## Constructor
################################################################################

@constructor
func constructor{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(caller: felt, router: felt):
    Ownable.initializer(caller)
    _router.write(router)
    return ()
end

## Views
################################################################################

@view
func get_owner{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}() -> (owner: felt):
    let (owner: felt) = Ownable.owner()
    return (owner=owner)
end

## Externals
################################################################################

@external
func set_router{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(new_router: felt):
    Ownable.assert_only_owner()
    _router.write(new_router)

    return ()
end

@external
func set_swap_address{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(idx: felt, swap_address: felt):
    Ownable.assert_only_owner()
    _swap_addresses.write(idx, swap_address)

    return ()
end

@external
func swap{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(desc: SwapDesc, path: SwapPath):
    alloc_locals
    let (local caller) = get_caller_address()
    let (local this_address) = get_contract_address()

    _assert_only_router()

    with_attr error_message("Source token cannot be zero"):
        assert_not_zero(path.path_0)
    end
    
    with_attr error_message("Destination token cannot be zero"):
        assert_not_zero(path.path_3)
    end

    # Get tokens from the router
    let (success) = IERC20.transferFrom(
        contract_address=desc.token_in,
        sender=caller,
        recipient=this_address,
        amount=desc.amt)
    assert success = 1

    # Do the swaps
    _swap(
        amt=desc.amt,
        src_token=path.path_0,
        path=path,
        step=0)
    
    # Return all the balance back
    let (out_balance: Uint256) = IERC20.balanceOf(
        contract_address=desc.token_out,
        account=this_address)

    let (success) = IERC20.transfer(
        contract_address=desc.token_out,
        recipient=caller,
        amount=out_balance)
    assert success = 1

    return ()
end

func _swap{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(
    amt: Uint256,
    src_token: felt, 
    path: SwapPath,
    step: felt
):
    alloc_locals
    let (local this_address) = get_contract_address()

    # Determine the next target token from step
    let (next_to_token, next_pool, next_swap) = _get_next_swap(step, path)

    # If there's no such token go to the next step
    # At last step next_to_token mustn't be 0 as it will be the destination
    # token
    if next_to_token == 0:
        return _swap(amt=amt, src_token=src_token, path=path, step=step+1)
    end

    let (swap_address: felt) = _swap_addresses.read(idx=next_swap)

    with_attr error_message("No swap defined for given index"):
        assert_not_zero(swap_address)
    end

    let (src_balance: Uint256) = IERC20.balanceOf(
        contract_address=src_token,
        account=this_address)

    # Approve tokens to the swapper
    let (success) = IERC20.approve(
        contract_address=src_token,
        spender=swap_address,
        amount=src_balance)
    assert success = 1

    # Do the swap
    let (amt_out: Uint256) = ISwapper.swap(
        contract_address=swap_address,
        token_in=src_token,
        token_out=next_to_token,
        pool=next_pool,
        amt=amt)
        
    # If destination token isn't reached, do the next swap
    if next_to_token != path.path_3:
        return _swap(amt=amt_out, src_token=next_to_token, path=path, step=step+1)
    end

    return ()
end

## Internals
################################################################################

func _get_next_swap{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(
    idx: felt, 
    path: SwapPath
) -> (
    next_token: felt,
    next_pool: felt,
    next_swap: felt
):
    if idx == 0:
        return (
            next_token=path.path_1, 
            next_pool=path.pool_1,
            next_swap=path.swap_1)
    else:
        if idx == 1:
            return (
                next_token=path.path_2, 
                next_pool=path.pool_2,
                next_swap=path.swap_2)
        else:
            assert idx = 2
            return (
                next_token=path.path_3, 
                next_pool=path.pool_3,
                next_swap=path.swap_3)
        end
    end
end

## @notice Asserts if caller is the router
func _assert_only_router{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}():
    let (caller: felt) = get_caller_address()
    let (router: felt) = _router.read()

    with_attr error_message("Only router can call this function"):
        assert caller = router
    end

    return ()
end
