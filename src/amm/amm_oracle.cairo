use starknet::ContractAddress;
use serde::Serde;


#[derive(Copy, Drop)]
struct HopTokens {
    token_0: ContractAddress,
    token_1: ContractAddress,
    token_2: ContractAddress,
    token_3: ContractAddress,
    pool_0: ContractAddress,
    pool_1: ContractAddress,
    pool_2: ContractAddress,
}

impl SwapDescSerde of serde::Serde::<HopTokens> {
    fn serialize(ref serialized: Array::<felt252>, input: HopTokens) {
        serde::Serde::<ContractAddress>::serialize(ref serialized, input.token_0);
        serde::Serde::<ContractAddress>::serialize(ref serialized, input.token_1);
        serde::Serde::<ContractAddress>::serialize(ref serialized, input.token_2);
        serde::Serde::<ContractAddress>::serialize(ref serialized, input.token_3);
        serde::Serde::<ContractAddress>::serialize(ref serialized, input.pool_0);
        serde::Serde::<ContractAddress>::serialize(ref serialized, input.pool_1);
        serde::Serde::<ContractAddress>::serialize(ref serialized, input.pool_2);
    }
    fn deserialize(ref serialized: Span::<felt252>) -> Option::<HopTokens> {
        Option::Some(
            HopTokens {
                token_0: serde::Serde::<ContractAddress>::deserialize(ref serialized)?,
                token_1: serde::Serde::<ContractAddress>::deserialize(ref serialized)?,
                token_2: serde::Serde::<ContractAddress>::deserialize(ref serialized)?,
                token_3: serde::Serde::<ContractAddress>::deserialize(ref serialized)?,
                pool_0: serde::Serde::<ContractAddress>::deserialize(ref serialized)?,
                pool_1: serde::Serde::<ContractAddress>::deserialize(ref serialized)?,
                pool_2: serde::Serde::<ContractAddress>::deserialize(ref serialized)?,
            }
        )
    }
}

#[contract]
mod AmmRouter {
    use starknet::ContractAddress;
    use starknet::ContractAddressZeroable;
    use starknet::contract_address_const;
    use zeroable::Zeroable;

    use super::HopTokens;
    use starknet::contract_address_to_felt252;
    use integer::u256_from_felt252;
    use array::ArrayTrait;

    #[abi]
    trait Amm {
        fn get_token_reserve(token: ContractAddress) -> (u256);
    }

    struct Storage {
        _pool_addresses: LegacyMap::<(ContractAddress, ContractAddress), ContractAddress>,
        _all_pool_addresses: LegacyMap::<felt252, ContractAddress>,
        _pool_counter: felt252,
    }

    #[constructor]
    fn constructor(owner: ContractAddress) { // TODO: wait openzeppelin to support ownable
    }

    #[view]
    fn get_pool_with_tokens(
        token_a: ContractAddress, token_b: ContractAddress
    ) -> (ContractAddress) {
        let (token_1, token_2) = sort_tokens(token_a, token_b);
        let pool_address = _pool_addresses::read((token_1, token_2));
        return pool_address;
    }

    #[view]
    fn get_pool_count() -> (felt252) {
        return _pool_counter::read();
    }

    #[view]
    fn get_all_pools() -> (Array::<ContractAddress>) {
        let total_number_of_pools = _pool_counter::read();
        let mut all_pools = ArrayTrait::<ContractAddress>::new();
        _get_all_pools(ref all_pools, 0, total_number_of_pools);
        return all_pools;
    }

    // @notice add pool address to the list of pools
    // @param token_a The address of the first token
    // @param token_b The address of the second token
    // @param pool_address The address of the pool
    #[external]
    fn add_pool(token_a: ContractAddress, token_b: ContractAddress, pool_address: ContractAddress) {
        let (token_1, token_2) = sort_tokens(token_a, token_b);
        _pool_addresses::write((token_1, token_2), pool_address);
        _all_pool_addresses::write(_pool_counter::read(), pool_address);
        _pool_counter::write(_pool_counter::read() + 1);
    }


    // @notice Get prices from the AMM 
    // @dev This will change for each unique AMM we'll have
    // @dev Calculates the rate as RESERVE_OUT / (RESERVE_IN + AMOUNT_IN)
    // @param amt_in The amount of token_in to swap
    // @param pool The address of the pool
    // @param token_in The address of the token to swap from
    // @param token_out The address of the token to swap to
    // @return The amount of token_out that will be received
    #[view]
    fn get_amt_out(
        amt_in: u256, pool: ContractAddress, token_in: ContractAddress, token_out: ContractAddress
    ) -> u256 {
        assert(token_in != token_out, 'must not be same address');
        let (token_1, token_2) = sort_tokens(token_in, token_out);

        // Query for the pool
        let pool_address = _pool_addresses::read((token_1, token_2));
        assert(pool_address != ContractAddressZeroable::zero(), 'pool not found');

        let zero_balanceu256 = u256 { low: 0_u128, high: 0_u128 };
        // Get balance for each token
        let reserve_in = AmmDispatcher { contract_address: pool }.get_token_reserve(token_in);

        assert(reserve_in > zero_balanceu256, 'must be greater than 0');

        let reserve_out = AmmDispatcher { contract_address: pool }.get_token_reserve(token_out);

        assert(reserve_in > zero_balanceu256, 'must be greater than 0');

        // Calculate the amount out

        let amountIn_with_fee = amt_in * u256 { low: 997_u128, high: 0_u128 }; // fee is 0.3%
        let numerator = amountIn_with_fee * reserve_in;
        let denominator = (reserve_in * u256 { low: 1000_u128, high: 0_u128 }) + amountIn_with_fee;

        u256 {
            low: numerator.low / denominator.low, high: 0_u128
        } // TODO: offical support for u256 division
    }

    // @notice Gets amount out for a fixed amount in and a path
    // @dev Assumes paths are left-aligned (ie somethings like [a,0,b,c] is not 
    // possible). Instead it should be [a,b,0,c]. (1)
    // @param amt_in The amount of token_in to swap
    // @param opt The HopTokens struct
    // @return The amount of token_out that will be received
    #[view]
    fn get_amt_out_through_path(amt_in: u256, opt: HopTokens) -> u256 {
        if (opt.token_0.is_zero() | opt.token_3.is_zero()) {
            return u256 { low: 0_u128, high: 0_u128 };
        }

        if (!opt.token_1.is_zero()) {
            if (!opt.token_2.is_zero()) {
                let amt_out_0 = get_amt_out(amt_in, opt.pool_0, opt.token_0, opt.token_1);
                let amt_out_1 = get_amt_out(amt_out_0, opt.pool_1, opt.token_1, opt.token_2);
                let amt_out_2 = get_amt_out(amt_out_1, opt.pool_2, opt.token_2, opt.token_3);
                return amt_out_2;
            } else {
                return get_amt_out(amt_in, opt.pool_1, opt.token_1, opt.token_3);
            }
        } else {
            return get_amt_out(amt_in, opt.pool_0, opt.token_0, opt.token_3);
        }
    }

    #[view]
    fn get_amts_out_through_paths(
        amt_ins: Array::<u256>, opts: Array::<HopTokens>
    ) -> Array::<u256> {
        let mut amts_outs = ArrayTrait::<u256>::new();
        _get_amts_out_through_paths(0_u32, amt_ins, opts, ref amts_outs);
        amts_outs
    }

    #[view]
    fn get_amt_in(
        amt_out: u256, pool: ContractAddress, token_in: ContractAddress, token_out: ContractAddress
    ) -> u256 {
        assert(token_in != token_out, 'must not be same address');

        // Get token balances
        let reserve_in = AmmDispatcher { contract_address: pool }.get_token_reserve(token_in);
        assert(reserve_in > u256 { low: 0_u128, high: 0_u128 }, 'must be greater than 0');

        let reserve_out = AmmDispatcher { contract_address: pool }.get_token_reserve(token_out);
        assert(reserve_out > u256 { low: 0_u128, high: 0_u128 }, 'must be greater than 0');

        let numerator = (reserve_in * amt_out) * u256 { low: 1000_u128, high: 0_u128 };
        let denominator = (reserve_out - amt_out) * u256 {
            low: 997_u128, high: 0_u128
        }; // fee is 0.3%

        u256 {
            low: numerator.low / denominator.low, high: 0_u128
            } + u256 {
            low: 1_u128, high: 0_u128
        }
    }

    #[view]
    fn get_amt_in_through_path(amt_out: u256, opt: HopTokens) -> u256 {
        if (opt.token_0.is_zero() | opt.token_3.is_zero()) {
            return u256 { low: 0_u128, high: 0_u128 };
        }
        // A - B - C - D
        if (!opt.token_2.is_zero()) {
            assert(
                !opt.token_1.is_zero(), 'must not be zero address'
            ); // Todo: check this assertion
            let amt_in_0 = get_amt_in(amt_out, opt.pool_2, opt.token_2, opt.token_3);
            let amt_in_1 = get_amt_in(amt_in_0, opt.pool_1, opt.token_1, opt.token_2);
            let amt_in_2 = get_amt_in(amt_in_1, opt.pool_0, opt.token_0, opt.token_1);
            return amt_in_2;
        } else {
            // A - B - 0- D
            if (!opt.token_1.is_zero()) {
                let amt_in_0 = get_amt_out(amt_out, opt.pool_1, opt.token_1, opt.token_3);
                let amt_in_1 = get_amt_out(amt_in_0, opt.pool_0, opt.token_0, opt.token_1);
                return amt_in_1;
            } else {
                // A - D
                return get_amt_in(amt_out, opt.pool_0, opt.token_0, opt.token_3);
            }
        }
    }

    #[view]
    fn get_amt_in_through_paths(
        amt_outs: Array::<u256>, opts: Array::<HopTokens>
    ) -> Array::<u256> {
        let mut amts_ins = ArrayTrait::<u256>::new();
        _get_amts_in_through_paths(0_u32, amt_outs, opts, ref amts_ins);
        amts_ins
    }


    fn sort_tokens(
        token_in: ContractAddress, token_out: ContractAddress
    ) -> (ContractAddress, ContractAddress) {
        assert(token_in != token_out, 'must not be same address');
        assert(token_in != ContractAddressZeroable::zero(), 'must not be zero address');
        if u256_from_felt252(
            contract_address_to_felt252(token_in)
        ) < u256_from_felt252(
            contract_address_to_felt252(token_out)
        ) { // TODO maybe there is a better way to compare
            (token_in, token_out)
        } else {
            (token_out, token_in)
        }
    }


    fn _get_all_pools(ref res: Array::<ContractAddress>, start: felt252, pool_count: felt252) {
        match gas::withdraw_gas_all(get_builtin_costs()) {
            Option::Some(_) => {},
            Option::None(_) => {
                let mut data = ArrayTrait::new();
                data.append('Out of gas');
                panic(data);
            },
        }
        if (start == pool_count) {
            return ();
        }
        let pool_address = _all_pool_addresses::read(start);
        res.append(pool_address);
        return _get_all_pools(ref res, start + 1, pool_count);
    }

    fn _get_amts_out_through_paths(
        idx: u32, amt_ins: Array::<u256>, opts: Array::<HopTokens>, ref amt_outs: Array::<u256>
    ) {
        match gas::withdraw_gas_all(get_builtin_costs()) {
            Option::Some(_) => {},
            Option::None(_) => {
                let mut data = ArrayTrait::new();
                data.append('Out of gas');
                panic(data);
            },
        }
        if (idx == amt_ins.len()) {
            return ();
        }
        let amt_out = get_amt_out_through_path(*amt_ins.at(idx), *opts.at(idx));
        amt_outs.append(amt_out);
        return _get_amts_out_through_paths(idx + 1_u32, amt_ins, opts, ref amt_outs);
    }

    fn _get_amts_in_through_paths(
        idx: u32, amt_outs: Array::<u256>, opts: Array::<HopTokens>, ref amts_ins: Array::<u256>
    ) {
        match gas::withdraw_gas_all(get_builtin_costs()) {
            Option::Some(_) => {},
            Option::None(_) => {
                let mut data = ArrayTrait::new();
                data.append('Out of gas');
                panic(data);
            },
        }

        if (idx == amt_outs.len()) {
            ()
        }
        let amt_in = get_amt_in_through_path(*amt_outs.at(idx), *opts.at(idx));
        amts_ins.append(amt_in);
        return _get_amts_in_through_paths(idx + 1_u32, amt_outs, opts, ref amts_ins);
    }
}
