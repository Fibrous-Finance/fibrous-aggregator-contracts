#[contract]
mod Router {
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
    use fibrous::interfaces::ISwapHandlerDispatcher;
    use fibrous::interfaces::ISwapHandlerDispatcherTrait;

    struct Storage {
        _swap_handler: ContractAddress, 
    }

    #[constructor]
    fn constructor(owner: ContractAddress) { // TODO: wait openzeppelin to support ownable
    }

    // TODO: wait openzeppelin ownable to get_owner function

    #[view]
    fn get_swap_handler() -> ContractAddress {
        _swap_handler::read()
    }


    #[external]
    fn set_swap_handler(swap_handler: ContractAddress) {
        _swap_handler::write(swap_handler)
    }

    #[external]
    fn swap(desc: SwapDesc, path: SwapPath) {
        let swap_handler = _swap_handler::read();
        let caller = get_caller_address();
        let this_address = get_contract_address();

        IERC20Dispatcher {
            contract_address: desc.token_in
        }.transferFrom(caller, this_address, desc.amt);
        IERC20Dispatcher { contract_address: desc.token_in }.approve(swap_handler, desc.amt);

        ISwapHandlerDispatcher { contract_address: swap_handler }.swap(desc, path);

        let after_balance = IERC20Dispatcher {
            contract_address: desc.token_out
        }.balanceOf(this_address);

        assert(after_balance >= desc.min_rcv, 'Min. receive amount not reached');

        IERC20Dispatcher { contract_address: desc.token_out }.transfer(caller, after_balance);
    }
}
