use starknet::ContractAddress;

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

    fn onFlashLoan(
        ref self: TState,
        initiator: ContractAddress,
        token: ContractAddress,
        amount: u256,
        fee: u256,
        data: felt252
    ) -> bool;

    fn flashBorrow(ref self: TState, token: ContractAddress, amount: u256, data: felt252) -> bool;
}

#[starknet::contract]
mod ERC7399Borrower {
    use openzeppelin::token::erc20::interface::IERC20DispatcherTrait;
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use openzeppelin::token::erc20::ERC20Component;
    use openzeppelin::token::erc20::interface::IERC20Dispatcher;
    use starknet::info::get_contract_address;
    use my_project::erc7399Lender::{IERC7399TraitDispatcher, IERC7399TraitDispatcherTrait};

    /// @dev 
    #[storage]
    struct Storage {
        lenderAddress: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, lenderAddress: ContractAddress,) {
        self.lenderAddress.write(lenderAddress);
    }

    #[external(v0)]
    impl IERC7399RecieverTraitIml of super::IERC7399RecieverTrait<ContractState> {
        fn onFlashLoan(
            ref self: ContractState,
            initiator: ContractAddress,
            token: ContractAddress,
            amount: u256,
            fee: u256,
            data: felt252
        ) -> bool {
            let caller: ContractAddress = get_caller_address();
            let flash_lender: ContractAddress = self.lenderAddress.read();
            let this_address: ContractAddress = get_contract_address();

            assert(caller == flash_lender, 'caller must be lender');
            assert(initiator == this_address, 'intiator is not borrower');

            //////////////////////////////////////////////////////////////*

            ///Do you thing here///

            ////////////////////////////////////////////////////////////

            true
        }

        fn flashBorrow(
            ref self: ContractState, token: ContractAddress, amount: u256, data: felt252
        ) -> bool {
            let this_contract = get_contract_address();
            let flash_lender = self.lenderAddress.read();
            let feeCal = IERC7399TraitDispatcher { contract_address: flash_lender }
                .flashFee(token, amount);
            let repayment_: u256 = (amount + feeCal);
            // calculated replayment_ so that only lender can perform transfer when calling lender contract //
            IERC20Dispatcher { contract_address: token }.approve(flash_lender, repayment_);
            let _bool: bool = IERC7399TraitDispatcher { contract_address: flash_lender }
                .flash(this_contract, token, amount, data);
            _bool
        }
    }
}
