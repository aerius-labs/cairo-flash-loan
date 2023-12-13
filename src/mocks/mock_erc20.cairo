use starknet::ContractAddress;

#[starknet::interface]
trait ERC20ExternalTrait<TState> {
    fn mint(ref self: TState, recipient: ContractAddress, amount: u256);
}

#[starknet::contract]
mod MyToken {
    use openzeppelin::token::erc20::ERC20Component;
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20Component::ERC20MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;
    impl InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        let name = 'MyToken';
        let symbol = 'MTK';

        self.erc20.initializer(name, symbol);
    }

    #[external(v0)]
    impl MyTokenImpl of super::ERC20ExternalTrait<ContractState> {
        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            // This function is NOT protected which means
            // ANYONE can mint tokens
            self.erc20._mint(recipient, amount);
        }
    }
}
