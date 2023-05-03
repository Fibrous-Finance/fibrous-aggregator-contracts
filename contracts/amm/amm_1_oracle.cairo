%lang starknet

from openzeppelin.access.ownable.library import Ownable

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin

from starkware.cairo.common.math import (
    assert_lt, assert_not_zero, assert_not_equal, split_felt)
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.uint256 import (
    Uint256, uint256_lt, uint256_add, uint256_unsigned_div_rem, 
    uint256_mul, uint256_sub)

## Types
################################################################################

struct HopTokens:
    member token_0: felt
    member token_1: felt
    member token_2: felt
    member token_3: felt
    member pool_0: felt
    member pool_1: felt
    member pool_2: felt
end

## AMM Interface
################################################################################

@contract_interface
namespace AMM_1:
    func get_token_reserve(token: felt) -> (balance: Uint256):
    end
end

## Storage Variables
################################################################################

@storage_var
func _pool_addresses(token_1: felt, token_2: felt) -> (pool_address: felt):
end

@storage_var
func _all_pool_addresses(id: felt) -> (pool_address: felt):
end

@storage_var
func _pool_counter() -> (id: felt):
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

## @notice Given two tokens, returns the pool address
@view
func get_pool_with_tokens{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(token_a: felt, token_b: felt) -> (pool_address: felt):
    let (token_1: felt, token_2: felt) = sort_tokens(token_a, token_b)
    let (pool_address) = _pool_addresses.read(token_1, token_2)
    return (pool_address)
end

## @notice Gets pool count
@view
func get_pool_count{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}() -> (pool_count: felt):
    let (pool_count) = _pool_counter.read()
    return (pool_count)
end

## @notice Gets all pools
@view
func get_all_pools{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr: felt
}() -> (all_pools_len: felt, all_pools: felt*):

    alloc_locals
    let (total_number_of_pools) = _pool_counter.read()

    let (local all_pools: felt*) = alloc()

    _get_all_pools(
        total_number_of_pools=total_number_of_pools,
        pool_idx=0,
        pools=all_pools)
    
    return (total_number_of_pools, all_pools)
end

func _get_all_pools{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr: felt
}(
    total_number_of_pools: felt,
    pool_idx: felt,
    pools: felt*
):

    if pool_idx == total_number_of_pools:
        return ()
    end

    let (pool_address) = _all_pool_addresses.read(pool_idx)

    assert [pools] = pool_address

    _get_all_pools(
        total_number_of_pools=total_number_of_pools,
        pool_idx=pool_idx+ 1,
        pools=pools+1)
    return ()
end

## Externals 
################################################################################

## @notice Adds a new pool
## @dev onlyOwner 
## @param token_1: Address of token 1
## @param token_2: Address of token 2
## @param pool_address: Contract address for pool of token 1<>token 2
@external
func add_pool{
    syscall_ptr: felt*, 
    pedersen_ptr: HashBuiltin*, 
    range_check_ptr
}(token_a: felt, token_b: felt, pool_address: felt):
    Ownable.assert_only_owner()   

    let (token_1: felt, token_2: felt) = sort_tokens(token_a, token_b)

    _pool_addresses.write(token_1, token_2, pool_address)

    let (pool_idx) = _pool_counter.read()
    _all_pool_addresses.write(pool_idx, pool_address)
    _pool_counter.write(pool_idx + 1)

    return ()
end

## Internals 
################################################################################

## @notice Takes in & out tokens and returns them in an ascending order
## @dev Assumption: token_in != token_out
func sort_tokens{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(token_in: felt, token_out: felt) -> (token_1: felt, token_2: felt):
    let (al, ah) = split_felt(token_in)
    let (bl, bh) = split_felt(token_out)
    assert_not_zero(token_out)

    # a < b == a <= (b-1)
    let (in_lt_out: felt) = is_le(ah, bh)
    if in_lt_out == 1:
      return (token_in, token_out)
    else:
      return (token_out, token_in)
    end
end

## IOracle 
################################################################################

## @notice Gets price from the AMM1
## @dev This will change for each unique AMM we'll have
## @dev Calculates the rate as RESERVE_OUT / (RESERVE_IN + AMT_IN)
@view
func get_amt_out{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(
    amt_in: Uint256, 
    pool: felt,
    token_in: felt, 
    token_out: felt
) -> (rate: Uint256):
    alloc_locals
    with_attr error_message("Same token provided"):
        assert_not_equal(token_in, token_out)
    end
    # let (token_1: felt, token_2: felt) = sort_tokens(token_in, token_out)

    # # Query for the pool
    # let (pool_address: felt) = _pool_addresses.read(token_1, token_2)
    # with_attr error_message("No such pool exists"):
    #     assert_not_zero(pool_address) 
    # end

    # Get balances for each token
    let (token_in_balance: Uint256) = AMM_1.get_token_reserve(
        contract_address=pool,
        token=token_in)
    let (tok_in_nn: felt) = uint256_lt(Uint256(0,0), token_in_balance)
    assert tok_in_nn = 1

    let (token_out_balance: Uint256) = AMM_1.get_token_reserve(
        contract_address=pool,
        token=token_out)
    let (tok_out_nn: felt) = uint256_lt(Uint256(0,0), token_in_balance)
    assert tok_out_nn = 1
    local syscall_ptr: felt* = syscall_ptr
  
    # Calculate price
    # Assume AMT_IN * TOKEN_IN_RESERVE won't overflow
    # Assume AMT_IN * RATE won't overflow
    let (rate_0: Uint256, carry: felt) = uint256_add(amt_in, token_in_balance)
    assert carry = 0

    let (rate_1: Uint256, rem: Uint256) = uint256_mul(token_out_balance, amt_in)
    let (rate_2: Uint256, rem: Uint256) = uint256_unsigned_div_rem(
        rate_1, rate_0)

    return (rate=rate_2)
end

## @notice Gets amount out for a fixed amount in and a path
## @dev Assumes paths are left-aligned (ie somethings like [a,0,b,c] is not 
## possible). Instead it should be [a,b,0,c]. (1)
@view
func get_amt_out_through_path{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(amt_in: Uint256, opt: HopTokens) -> (amt_out: Uint256):
    # Must be impossible
    if opt.token_0 == 0:
        return (amt_out=Uint256(0,0))
    end

    if opt.token_3 == 0:
        return (amt_out=Uint256(0,0))
    end

    if opt.token_1 != 0:
        let (amt_out_0: Uint256) = get_amt_out(amt_in, opt.pool_0, opt.token_0, opt.token_1)

        if opt.token_2 != 0:
            let (amt_out_1: Uint256) = get_amt_out(amt_out_0, opt.pool_1, opt.token_1, opt.token_2)
            let (amt_out_2: Uint256) = get_amt_out(amt_out_1, opt.pool_2, opt.token_2, opt.token_3)
            return (amt_out=amt_out_2)
        else: 
            let (amt_out_0: Uint256) = get_amt_out(amt_in, opt.pool_1, opt.token_1, opt.token_3)
            return (amt_out=amt_out_0) 
        end

    # Due to the assumption (1) we can conclude token_2 is also 0, we'll go to
    # the dst_token directly
    else:
        let (amt_out_0: Uint256) = get_amt_out(amt_in, opt.pool_0, opt.token_0, opt.token_3)
        return (amt_out=amt_out_0) 
    end 
end

## @notice Batches multiple get_amt_out_through_path calls
## @param amt_ins: felt[]
## @param opts: HopTokens[]
## @returns amt_outs: felt[]
@view
func get_amts_out_through_paths{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(
    amt_ins_len: felt, amt_ins: Uint256*,
    opts_len: felt, opts: HopTokens*
) -> (
    amt_outs_len: felt, amt_outs: Uint256*
):
    alloc_locals
    let (amt_outs: Uint256*) = alloc()

    _get_amts_out_through_paths{
        amt_ins_len=amt_ins_len,
        amt_ins=amt_ins,
        opts=opts,
        amt_outs=amt_outs
    }(0)

    return (
        amt_outs_len=amt_ins_len,
        amt_outs=amt_outs
    )
end

func _get_amts_out_through_paths{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    amt_ins_len: felt,
    amt_ins: Uint256*,
    opts: HopTokens*,
    amt_outs: Uint256*
}(idx: felt):
    if idx == amt_ins_len:
        return ()
    end 

    let (amt_out: Uint256) = get_amt_out_through_path(
        amt_in=amt_ins[idx],
        opt=opts[idx]
    )

    assert amt_outs[idx] = amt_out
    return _get_amts_out_through_paths(idx+1)
end

@view
func get_amt_in{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(
    amt_out: Uint256,
    pool: felt,
    token_in: felt,
    token_out: felt
) -> (
    amt_in: Uint256
):
    alloc_locals
    with_attr error_message("Same token provided"):
        assert_not_equal(token_in, token_out)
    end

    # Get token balances
    let (reserve_in: Uint256) = AMM_1.get_token_reserve(
        contract_address=pool,
        token=token_in)
    let (tok_in_nn: felt) = uint256_lt(Uint256(0,0), reserve_in)
    assert tok_in_nn = 1

    let (reserve_out: Uint256) = AMM_1.get_token_reserve(
        contract_address=pool,
        token=token_out)
    let (tok_out_nn: felt) = uint256_lt(Uint256(0,0), reserve_out)
    assert tok_out_nn = 1

    # Reset revoked syscall_ptr
    local syscall_ptr: felt* = syscall_ptr

    let (numerator: Uint256, excess: Uint256) = uint256_mul(
        reserve_in, amt_out)
    let (denominator: Uint256) = uint256_sub(reserve_out, amt_out)
    let (amt_in: Uint256, rem: Uint256) = uint256_unsigned_div_rem(
        numerator, denominator)
    
    return (amt_in=amt_in)
end

@view
func get_amt_in_through_path{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(amt_out: Uint256, opt: HopTokens) -> (amt_in: Uint256):
    # Must be impossible if call is right
    if opt.token_0 == 0:
        return (amt_in=Uint256(0,0))
    end

    if opt.token_3 == 0:
        return (amt_in=Uint256(0,0))
    end

    # A - B - C - D
    if opt.token_2 != 0: 
        if opt.token_1 == 0:
            assert 1 = 0
        end
        let (amt_in_0: Uint256) = get_amt_in(
            amt_out, opt.pool_2, opt.token_2, opt.token_3)
        let (amt_in_1: Uint256) = get_amt_in(
            amt_in_0, opt.pool_1, opt.token_1, opt.token_2)
        let (amt_in_2: Uint256) = get_amt_in(
            amt_in_1, opt.pool_0, opt.token_0, opt.token_1)
        return (amt_in=amt_in_2)
    else:
        # A - B - 0 - D
        if opt.token_1 != 0:
            let (amt_in_0: Uint256) = get_amt_out(
                amt_out, opt.pool_1, opt.token_1, opt.token_3) 
            let (amt_in_1: Uint256) = get_amt_out(
                amt_in_0, opt.pool_0, opt.token_0, opt.token_1)
            return (amt_in=amt_in_1)
        # A - 0 - 0 - D
        else:
            let (amt_in_0: Uint256) = get_amt_in(
                amt_out, opt.pool_0, opt.token_0, opt.token_3)
            return (amt_in=amt_in_0)
        end
    end
end

@view
func get_amts_in_through_paths{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(
    amt_outs_len: felt, amt_outs: Uint256*,
    opts_len: felt, opts: HopTokens*
) -> (
    amt_ins_len: felt, amt_ins: Uint256*
):
    alloc_locals
    let (amt_ins: Uint256*) = alloc()

    _get_amts_in_through_paths{
        amt_outs_len=amt_outs_len,
        amt_outs=amt_outs,
        opts=opts,
        amt_ins=amt_ins
    }(0)

    return (
        amt_ins_len=amt_outs_len,
        amt_ins=amt_ins
    )
end

func _get_amts_in_through_paths{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    amt_outs_len: felt,
    amt_outs: Uint256*,
    opts: HopTokens*,
    amt_ins: Uint256*
}(idx: felt):
    if idx == amt_outs_len:
        return ()
    end 

    let (amt_in: Uint256) = get_amt_in_through_path(
        amt_out=amt_outs[idx],
        opt=opts[idx]
    )

    assert amt_ins[idx] = amt_in
    return _get_amts_in_through_paths(idx+1)
end
