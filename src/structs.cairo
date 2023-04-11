use serde::Serde;
use starknet::ContractAddress;

#[derive(Copy, Drop)]
struct SwapDesc {
    token_in: ContractAddress,
    token_out: ContractAddress,
    amt: u256,
    min_rcv: u256,
    dst_rcv: felt252,
}

#[derive(Copy, Drop)]
struct SwapPath { // TODO: check if we can use array here and change the type to ContractAddress
    path_0: ContractAddress,
    path_1: ContractAddress,
    path_2: ContractAddress,
    path_3: ContractAddress,
    //     Swapper indices 
    // 1st hop
    swap_1: felt252,
    pool_1: ContractAddress,
    // 2nd hop
    swap_2: felt252,
    pool_2: ContractAddress,
    // 3rd hop
    swap_3: felt252,
    pool_3: ContractAddress,
}

impl SwapDescSerde of serde::Serde::<SwapDesc> {
    fn serialize(ref serialized: Array::<felt252>, input: SwapDesc) {
        serde::Serde::<ContractAddress>::serialize(ref serialized, input.token_in);
        serde::Serde::<ContractAddress>::serialize(ref serialized, input.token_out);
        serde::Serde::<u256>::serialize(ref serialized, input.amt);
        serde::Serde::<u256>::serialize(ref serialized, input.min_rcv);
        serde::Serde::<felt252>::serialize(ref serialized, input.dst_rcv);
    }
    fn deserialize(ref serialized: Span::<felt252>) -> Option::<SwapDesc> {
        Option::Some(
            SwapDesc {
                token_in: serde::Serde::<ContractAddress>::deserialize(ref serialized)?,
                token_out: serde::Serde::<ContractAddress>::deserialize(ref serialized)?,
                amt: serde::Serde::<u256>::deserialize(ref serialized)?,
                min_rcv: serde::Serde::<u256>::deserialize(ref serialized)?,
                dst_rcv: serde::Serde::<felt252>::deserialize(ref serialized)?,
            }
        )
    }
}

impl SwapPathSerde of serde::Serde::<SwapPath> {
    fn serialize(ref serialized: Array::<felt252>, input: SwapPath) {
        serde::Serde::<ContractAddress>::serialize(ref serialized, input.path_0);
        serde::Serde::<ContractAddress>::serialize(ref serialized, input.path_1);
        serde::Serde::<ContractAddress>::serialize(ref serialized, input.path_2);
        serde::Serde::<ContractAddress>::serialize(ref serialized, input.path_3);
        serde::Serde::<felt252>::serialize(ref serialized, input.swap_1);
        serde::Serde::<ContractAddress>::serialize(ref serialized, input.pool_1);
        serde::Serde::<felt252>::serialize(ref serialized, input.swap_2);
        serde::Serde::<ContractAddress>::serialize(ref serialized, input.pool_2);
        serde::Serde::<felt252>::serialize(ref serialized, input.swap_3);
        serde::Serde::<ContractAddress>::serialize(ref serialized, input.pool_3);
    }
    fn deserialize(ref serialized: Span::<felt252>) -> Option::<SwapPath> {
        Option::Some(
            SwapPath {
                path_0: serde::Serde::<ContractAddress>::deserialize(ref serialized)?,
                path_1: serde::Serde::<ContractAddress>::deserialize(ref serialized)?,
                path_2: serde::Serde::<ContractAddress>::deserialize(ref serialized)?,
                path_3: serde::Serde::<ContractAddress>::deserialize(ref serialized)?,
                swap_1: serde::Serde::<felt252>::deserialize(ref serialized)?,
                pool_1: serde::Serde::<ContractAddress>::deserialize(ref serialized)?,
                swap_2: serde::Serde::<felt252>::deserialize(ref serialized)?,
                pool_2: serde::Serde::<ContractAddress>::deserialize(ref serialized)?,
                swap_3: serde::Serde::<felt252>::deserialize(ref serialized)?,
                pool_3: serde::Serde::<ContractAddress>::deserialize(ref serialized)?,
            }
        )
    }
}
