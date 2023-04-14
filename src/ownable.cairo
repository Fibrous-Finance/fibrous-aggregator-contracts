use starknet::ContractAddress;
trait IOwnable {
    fn initializer(_owner: ContractAddress);
    fn transferOwnership( newOwner: ContractAddress);
    fn renounceOwnership();
    fn get_owner() -> ContractAddress;
    fn assert_only_owner();
}


#[contract]
mod Ownable {
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use starknet::ContractAddressZeroable;
    use starknet::Zeroable;

    struct Storage{
        owner_ownable: ContractAddress,
    }

    #[event]
    fn OwnershipTransferred(previousOwner: ContractAddress, newOwner: ContractAddress){}



    #[external]
    fn initializer(_owner: ContractAddress) {
         owner_ownable::write(_owner);
         OwnershipTransferred(ContractAddressZeroable::zero(), _owner);
    }

    #[external]
    fn transferOwnership(newOwner: ContractAddress) {
        assert_only_owner();
        assert(!newOwner.is_zero(), 'New owner can not be zero');
        let previousOwner = owner_ownable::read();
        owner_ownable::write(newOwner);
        OwnershipTransferred(previousOwner, newOwner);
    }

    #[external]
    fn renounceOwnership() {
        assert_only_owner();
        let previousOwner = owner_ownable::read();
        owner_ownable::write(ContractAddressZeroable::zero());
        OwnershipTransferred(previousOwner, ContractAddressZeroable::zero());
    }

    #[view]
    fn get_owner() -> ContractAddress {
        owner_ownable::read()
    }

    #[external]
    fn assert_only_owner() {
        let owner = owner_ownable::read();
        let caller = get_caller_address();
        assert(!caller.is_zero(), 'Caller can not be zero');
        assert(owner == caller, 'Only owner can call');
    }

}