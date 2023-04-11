#[contract]
mod SwapHandler {
    use array::ArrayTrait;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use starknet::ContractAddress;
    use starknet::contract_address_try_from_felt252;
    use starknet::ContractAddressZeroable;
    use zeroable::Zeroable;
    use fibrous::structs::SwapDesc;
    use fibrous::structs::SwapPath;
    use fibrous::interfaces::IERC20Dispatcher;
    use fibrous::interfaces::IERC20DispatcherTrait;
    use fibrous::interfaces::ISwapperDispatcher;
    use fibrous::interfaces::ISwapperDispatcherTrait;


    struct Storage {
        router: ContractAddress,
        swap_addresses: LegacyMap<felt252, ContractAddress>,
    }


    #[constructor]
    fn constructor(caller: felt252, _router: ContractAddress) {
        router::write(_router);
    // TODO: wait openzeppelin to support ownable
    }

    #[view]
    fn get_router() -> ContractAddress {
        router::read()
    }

    // TODO: wait openzeppelin ownable to get_owner function

    #[external]
    fn set_router(_router: ContractAddress) {
        // TODO: wait openzeppelin to support ownable
        router::write(_router)
    }

    #[external]
    fn set_swap_address(idx: felt252, _swap_address: ContractAddress) {
        swap_addresses::write(idx, _swap_address)
    }

    #[external]
    fn swap(desc: SwapDesc, path: SwapPath) {
        let caller = get_caller_address();
        let this_address = get_contract_address();

        _assert_only_router();

        assert(!path.path_0.is_zero(), 'Source token can not be zero');
        assert(!path.path_3.is_zero(), 'Destination token cant be zero');

        IERC20Dispatcher {
            contract_address: desc.token_in
        }.transferFrom(caller, this_address, desc.amt);

        _swap(desc.amt, path.path_0, path, 0);

        let out_balance = IERC20Dispatcher {
            contract_address: desc.token_out
        }.balanceOf(this_address);
        // assert(out_balance >= desc.min_rcv, 'Received amount is less than expected'); 
        IERC20Dispatcher { contract_address: desc.token_out }.transfer(caller, out_balance);
    }


    // INTERNALS

    // TODO: add break to recursion or use loop instead of recursion when supported
    fn _swap(amt: u256, src_token: ContractAddress, path: SwapPath, step: felt252) {
        match gas::withdraw_gas_all(get_builtin_costs()) {
            Option::Some(_) => {},
            Option::None(_) => {
                let mut data = ArrayTrait::new();
                data.append('Out of gas');
                panic(data);
            },
        }
        let this_address = get_contract_address();
        let (next_to_token, next_pool, next_swap) = _get_next_swap(path, step);

        if next_to_token.is_zero() { // TODO check is_zero working as expected for ContractAddressZeroable
            return _swap(amt, src_token, path, step + 1);
        }
        let swap_address = swap_addresses::read(next_swap);

        assert(!swap_address.is_zero(), 'No swap defined for given index');

        let tokenDispatcher = IERC20Dispatcher { contract_address: src_token };
        let src_balance = tokenDispatcher.balanceOf(this_address);
        tokenDispatcher.approve(swap_address, src_balance);

        let amt_out = ISwapperDispatcher {
            contract_address: swap_address
        }.swap(src_token, next_to_token, next_pool, amt);

        if next_to_token != path.path_3 {
            return _swap(amt_out, next_to_token, path, step + 1);
        }
        return ();
    }

    fn _get_next_swap(path: SwapPath, idx: felt252) -> (ContractAddress, ContractAddress, felt252) {
        if idx == 0 {
            (path.path_0, path.pool_1, path.swap_1)
        } else if idx == 1 {
            (path.path_1, path.pool_2, path.swap_2)
        } else if idx == 2 {
            (path.path_2, path.pool_3, path.swap_3)
        } else {
            (ContractAddressZeroable::zero(), ContractAddressZeroable::zero(), 0)
        }
    }

    fn _assert_only_router() {
        let caller = get_caller_address();
        let router = router::read();
        assert(caller == router, 'only router can call');
    }
}
