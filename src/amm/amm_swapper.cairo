#[contract]
mod AmmSwapper {
    use starknet::ContractAddress;
    use starknet::ContractAddressZeroable;
    use starknet::contract_address_const;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use zeroable::Zeroable;
    use fibrous::ownable::Ownable;


    #[abi]
    trait Amm {
        fn swap(token_from: ContractAddress, amount_from: u256) -> u256;
    }

    #[abi]
    trait IERC20 {
        fn balanceOf(owner: ContractAddress) -> u256;
        fn transfer(recipient: ContractAddress, amount: u256) -> bool;
        fn transferFrom(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
        fn approve(spender: ContractAddress, amount: u256) -> bool;
    }

    struct Storage {
        _swap_handler: ContractAddress
    }

    #[constructor]
    fn constructor(owner: ContractAddress, swap_handler: ContractAddress) {
        Ownable::initializer(owner);
        _swap_handler::write(swap_handler);
    }

    #[view]
    fn get_swap_handler() -> ContractAddress {
        _swap_handler::read()
    }

    #[external]
    fn set_swap_handler(swap_handler: ContractAddress) {
        Ownable::assert_only_owner();
        _swap_handler::write(swap_handler);
    }

    #[external]
    fn swap(
        token_in: ContractAddress,
        token_out: ContractAddress,
        pool: ContractAddress,
        amount_in: u256
    ) -> u256 {
        _assert_only_swap_handler();
        assert(!token_in.is_zero(), 'Token in cannot be zero');
        assert(!token_out.is_zero(), 'Token out cannot be zero');
        assert(!pool.is_zero(), 'Pool cannot be zero');
        assert(token_in != token_out, 'Same token provided');

        let caller = get_caller_address();
        let this_address = get_contract_address();

        IERC20Dispatcher {
            contract_address: token_in
        }.transferFrom(caller, this_address, amount_in);

        IERC20Dispatcher { contract_address: token_in }.approve(pool, amount_in);

        let amount_out = AmmDispatcher { contract_address: pool }.swap(token_in, amount_in);

        let out_balance = IERC20Dispatcher { contract_address: token_out }.balanceOf(this_address);

        assert(out_balance >= amount_out, 'Not enough balance');

        IERC20Dispatcher { contract_address: token_out }.transfer(caller, amount_out);

        return amount_out;
    }

    fn _assert_only_swap_handler() {
        let caller = get_caller_address();
        let swap_handler = _swap_handler::read();
        assert(caller == swap_handler, 'Only swap handler');
    }
}
