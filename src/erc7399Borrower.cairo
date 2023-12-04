use starknet:: ContractAddress;

#[starknet::interface]
trait IERC7399RecieverTrait<TState> {
    // /**
    // * @dev Receive a flash loan.
    // * @param initiator The initiator of the loan.
    // * @param token The loan currency.
    // * @param amount The amount of tokens lent.
    // * @param fee The additional amount of tokens to repay.
    // * @param data Arbitrary data structure, intended to contain user-defined parameters.
    // * @return The keccak256 hash of "ERC3156FlashBorrower.onFlashLoan"
    // */

    fn onFlashLoan (
        ref self: TState,
        initiator: ContractAddress,
        token: ContractAddress,
        amount: u256,
        fee: u256,
        data: felt252
    ) -> bool;

}

#[starknet::contract]
mod ERC7399Borrower {
    use openzeppelin::token::erc20::interface::IERC20DispatcherTrait;
    use starknet::get_caller_address;
    use starknet:: ContractAddress;
    use openzeppelin::token::erc20::ERC20Component;
    use openzeppelin::token::erc20::interface::IERC20Dispatcher;
    use starknet::info::get_contract_address;


    /// @dev 
    #[storage]
    struct Storage {
        lenderAddress: ContractAddress,
    }

    #[constructor]
    fn constructor(
      ref self: ContractState,
      lenderAddress:ContractAddress,
    ) {
        self.lenderAddress.write(lenderAddress);
    }

    #[external(v0)]
    impl IERC7399RecieverTraitIml of super::IERC7399RecieverTrait<ContractState> {
        fn onFlashLoan(ref self: ContractState,initiator:ContractAddress,token:ContractAddress,amount:u256,fee:u256,data:felt252) -> bool {
            let caller: ContractAddress = get_caller_address();
            let flash_lender: ContractAddress = self.lenderAddress.read();
            let this_address: ContractAddress = get_contract_address();

            assert(caller == flash_lender, 'caller must be lender');
            assert(initiator == this_address, 'intiator is not borrower');




            true
        }
    }

    
}
