use starknet::ContractAddress;
use fibrous::structs::SwapDesc;
use fibrous::structs::SwapPath;

#[abi]
trait IERC20 {
    fn balanceOf(owner: ContractAddress) -> u256;
    fn transfer(recipient: ContractAddress, amount: u256) -> bool;
    fn transferFrom(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    fn approve(spender: ContractAddress, amount: u256) -> bool;
}

#[abi]
trait ISwapHandler {
    fn swap(desc: SwapDesc, path: SwapPath);
}

#[abi]
trait ISwapper {
    fn swap(
        token_in: ContractAddress, token_out: ContractAddress, pool: ContractAddress, amt: u256
    ) -> u256;
}
