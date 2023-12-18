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

#[starknet::interface]
trait IERC7399Trait<TState> {
    /// @dev The amount of currency available to be lent.
    /// @param asset The loan currency.
    /// @return The amount of `asset` that can be borrowed.
    fn maxFlashLoanSync(ref self: TState, asset: ContractAddress) -> u256;

    fn maxFlashLoan(self: @TState) -> u256;

    /// @dev The fee to be charged for a given loan. Returns type(uint256).max if the loan is not possible.
    /// @param asset The loan currency.
    /// @param amount The amount of assets lent.
    /// @return The amount of `asset` to be charged for the loan, on top of the returned principal.

    fn flashFee(self: @TState, asset: ContractAddress, amount: u256) -> u256;

    /// @dev Initiate a flash loan.
    /// @param loanReceiver The address receiving the flash loan
    /// @param asset The asset to be loaned
    /// @param amount The amount to loaned
    /// @param data The ABI encoded user data
    /// @param callback The address and signature of the callback function
    /// @return result ABI encoded result of the callback

    fn flash(
        ref self: TState,
        loanReceiver: ContractAddress,
        asset: ContractAddress,
        amount: u256,
        data: felt252,
    ) -> bool;
}

#[starknet::contract]
mod ERC7399Borrower {
    use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
    use starknet::{ContractAddress, get_caller_address};
    use starknet::ContractAddress;
    use openzeppelin::token::erc20::ERC20Component;
    use starknet::info::get_contract_address;
    use super::{IERC7399TraitDispatcher, IERC7399TraitDispatcherTrait};

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
