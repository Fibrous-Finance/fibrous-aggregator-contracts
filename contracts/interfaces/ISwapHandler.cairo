%lang starknet

## @notice Interface to handle a swap

from starkware.cairo.common.uint256 import Uint256

# TODO: Use destination receiver (dst_rcv) in the contracts
struct SwapDesc:
    member token_in: felt
    member token_out: felt
    member amt: Uint256 
    member min_rcv: Uint256 
    member dst_rcv: felt
end

struct SwapPath:
    # Tokens
    member path_0: felt
    member path_1: felt
    member path_2: felt
    member path_3: felt 
    # Swapper indices 
    # 1st hop
    member swap_1: felt
    member pool_1: felt
    # 2nd hop
    member swap_2: felt
    member pool_2: felt
    # 3rd hop
    member swap_3: felt
    member pool_3: felt
end

@contract_interface
namespace ISwapHandler:
    ## @notice Given enough funds for it, executes a swap according to 
    ##         description and path
    ## @param desc: Holds information about the swap
    ## @param path: Specifies the path
    func swap(desc: SwapDesc, path: SwapPath):
    end 
end
