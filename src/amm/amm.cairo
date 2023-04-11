#[contract]
mod FibrousTestAmm {
    use starknet::ContractAddress;
    use starknet::ContractAddressZeroable;
    use starknet::get_contract_address;
    use starknet::get_caller_address;
    use array::ArrayTrait;

    #[abi]
    trait IERC20 {
        fn balanceOf(owner: ContractAddress) -> u256;
        fn transfer(recipient: ContractAddress, amount: u256) -> bool;
        fn transferFrom(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
        fn approve(spender: ContractAddress, amount: u256) -> bool;
    }
    struct Storage {
        _pool_balance: LegacyMap<ContractAddress, u256>,
        _token_a: ContractAddress,
        _token_b: ContractAddress
    }

    #[constructor]
    fn constructor(token_a: ContractAddress, token_b: ContractAddress, owner: ContractAddress) {
        _token_a::write(token_a);
        _token_b::write(token_b);
    // TODO wait openzeppelin to support ownable or write own 
    }

    // @notice Gets the balance of the pool for a given token
    // @param token The address of the token
    // @return The balance of the pool for the given token
    #[view]
    fn get_token_reserve(token: ContractAddress) -> u256 {
        let this_address = get_contract_address();
        let balance = IERC20Dispatcher { contract_address: token }.balanceOf(this_address);
        return balance;
    }

    // @notice Getter for token a
    // @return The address of token a
    #[view]
    fn token_a() -> ContractAddress {
        return _token_a::read();
    }

    // @notice Getter for token b
    // @return The address of token b
    #[view]
    fn token_b() -> ContractAddress {
        return _token_b::read();
    }


    // @notice Swaps token_from to token_to
    // @param token_from address of the source token
    // @param amount_from amount of the given token to swap
    // @return amount of token received
    #[external]
    fn swap(token_from: ContractAddress, amount_from: u256) -> u256 {
        let caller = get_caller_address();
        let token_to = get_opposite_token(token_from);
        _assert_valid_token(token_from);
        let amount_to = _swap(caller, token_from, token_to, amount_from);
        return amount_to;
    }

    // @notice Adds liquidity to the pool
    // @param token The address of the token
    // @param liq_amount The amount of liquidity to add
    #[external]
    fn add_liquidity(token: ContractAddress, liq_amount: u256) {
        // TODO assert only owner

        _assert_valid_token(token);

        let caller = get_caller_address();
        let this_address = get_contract_address();
        IERC20Dispatcher { contract_address: token }.transferFrom(caller, this_address, liq_amount);
    }

    // @notice Removes liquidity from the pool
    // @param token The address of the token
    // @param liq_amount The amount of liquidity to remove
    #[external]
    fn remove_liquidity(token: ContractAddress, liq_amount: u256) {
        // TODO assert only owner

        _assert_valid_token(token);

        let caller = get_caller_address();
        let this_address = get_contract_address();
        IERC20Dispatcher { contract_address: token }.transfer(caller, liq_amount);
    }


    //************ Internal Functions ************

    fn _swap(
        account: ContractAddress,
        token_from: ContractAddress,
        token_to: ContractAddress,
        amount_from: u256
    ) -> u256 {
        let this_address = get_contract_address();

        let amm_from_balance = get_token_reserve(token_from);
        let amm_to_balance = get_token_reserve(token_to);

        let from_mul_balance = amm_to_balance
            * amount_from; // TODO check overflow with official functions
        let balance_add_from = amm_from_balance + amount_from;

        // Calculate swap amount
        let amount_to = u256 {
            low: from_mul_balance.low / balance_add_from.low, high: 0_u128
        }; // TODO check overflow with official functions

        // Transfer token_from to pool
        IERC20Dispatcher {
            contract_address: token_from
        }.transferFrom(account, this_address, amount_from);

        // Transfer token_to to account
        IERC20Dispatcher { contract_address: token_to }.transfer(account, amount_to);

        return amount_to;
    }
    // @notice Gets the opposite token
    fn get_opposite_token(token: ContractAddress) -> ContractAddress {
        let token_a = _token_a::read();
        let token_b = _token_b::read();
        if token == token_a {
            return token_b;
        } else if token == token_b {
            return token_a;
        } else {
            return ContractAddressZeroable::zero();
        }
    }

    fn _assert_valid_token(token: ContractAddress) {
        let token_a = _token_a::read();
        let token_b = _token_b::read();
        assert(token == token_a | token == token_b, 'Invaid token');
    }
}
