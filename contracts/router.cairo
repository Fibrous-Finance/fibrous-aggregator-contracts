%lang starknet

## @title Router
## Contract to route swaps

from openzeppelin.access.ownable.library import Ownable
from openzeppelin.token.erc20.IERC20 import IERC20

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_le
from starkware.starknet.common.syscalls import (
    get_caller_address, 
    get_contract_address)
from contracts.interfaces.ISwapHandler import ISwapHandler, SwapDesc, SwapPath

## Storage Variables
################################################################################

@storage_var
func _swap_handler() -> (swap_handler: felt):
end

## Constructor
################################################################################

@constructor
func constructor{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(owner: felt):
    Ownable.initializer(owner)
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
    return Ownable.owner()
end

@view
func get_swap_handler{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}() -> (swap_handler: felt):
    return _swap_handler.read()
end

## Externals
################################################################################

@external
func set_swap_handler{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(new_handler: felt):
    Ownable.assert_only_owner()
    _swap_handler.write(value=new_handler)
    return ()
end

@external
func swap{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(desc: SwapDesc, path: SwapPath):
    alloc_locals

    let (swap_handler: felt) = _swap_handler.read()
    let (caller: felt) = get_caller_address()
    let (this_address: felt) = get_contract_address()

    # Transfer tokens from user to router
    let (success) = IERC20.transferFrom(
        contract_address=desc.token_in,
        sender=caller,
        recipient=this_address,
        amount=desc.amt
    )
    assert success = 1

    # Approve tokens to swap handler
    let (success) = IERC20.approve(
        contract_address=desc.token_in,
        spender=swap_handler,
        amount=desc.amt
    )
    assert success = 1

    ISwapHandler.swap(
        contract_address=swap_handler,
        desc=desc,
        path=path
    )

    # Assert if minimum receive amount is reached, otherwise error
    
    # IERC20.balanceOf revokes the syscall_ptr
    local syscall_ptr: felt* = syscall_ptr
    let (after_balance: Uint256) = IERC20.balanceOf(
        contract_address=desc.token_out,
        account=this_address
    )

    with_attr error_message("Minimum receive amount not reached"):
        let (min_recvd: felt) = uint256_le(desc.min_rcv, after_balance)
        assert min_recvd = 1 
    end

    # Send tokens to the caller
    let (success) = IERC20.transfer(
        contract_address=desc.token_out,
        recipient=caller,
        amount=after_balance)
    assert success = 1

    return ()
end
