use starknet::ContractAddress;

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

/// @dev Starknet Contract for flash loan of a single borrower
// importing interface so we can access the dispatcher  //
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
}

#[starknet::contract]
mod ERC7399Lender {
    use integer::BoundedInt;
    use openzeppelin::token::erc20::interface::IERC20DispatcherTrait;
    use starknet::get_caller_address;
    use starknet::ContractAddress;
    use openzeppelin::token::erc20::ERC20Component;
    use openzeppelin::token::erc20::interface::IERC20Dispatcher;
    use starknet::info::get_contract_address;
    use super::{IERC7399RecieverTraitDispatcher, IERC7399RecieverTraitDispatcherTrait};

    /// @dev 
    #[storage]
    struct Storage {
        owner: ContractAddress,
        assetAddress: ContractAddress,
        fee: u256,
        reserves: u256
    }

    #[constructor]
    fn constructor(ref self: ContractState, assetAddress: ContractAddress, fee: u256) {
        let CALLER: ContractAddress = get_caller_address();
        self.owner.write(CALLER);
        self.fee.write(fee);
        self.assetAddress.write(assetAddress);
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Flash: Flash
    }
    /// will emit an event when flash is success
    #[derive(Drop, starknet::Event)]
    struct Flash {
        #[key]
        from: ContractAddress,
        amount: u256,
        fee: u256
    }

    #[external(v0)]
    impl IERC7399TraitImpl of super::IERC7399Trait<ContractState> {
        /// this will read the total resevres of the lender contract
        fn maxFlashLoanSync(ref self: ContractState, asset: ContractAddress) -> u256 {
            self._sync();
            self.reserves.read()
        }
        /// this will the function that will get the flash fee
        fn flashFee(self: @ContractState, asset: ContractAddress, amount: u256) -> u256 {
            let currReserves: u256 = self.reserves.read();
            if amount.low <= currReserves.low && amount.high <= currReserves.high {
                let result: u256 = self._flashFee(amount);
                result
            } else {
                let result: u256 = BoundedInt::max();
                result
            }
        }
        /// this will be the flash function ///
        fn flash(
            ref self: ContractState,
            loanReceiver: ContractAddress,
            asset: ContractAddress,
            amount: u256,
            data: felt252
        ) -> bool {
            let feeCal = self._flashFee(amount);
            let token: ContractAddress = self.assetAddress.read();
            let initiator: ContractAddress = get_caller_address();
            self._serveLoan(loanReceiver, amount);
            self._onFlashLoan(loanReceiver, initiator, token, amount, feeCal, data);
            let updatedFee: u256 = amount + feeCal;
            self._acceptTransfer(updatedFee);
            self.emit(Flash { from: asset, amount: amount, fee: feeCal });

            true
        }

        fn maxFlashLoan(self: @ContractState) -> u256 {
            self.reserves.read()
        }
    }

    #[generate_trait]
    impl FlashFunctions of FlashFunctionsTrait {
        // internal functions of contract
        fn _flashFee(self: @ContractState, amount: u256) -> u256 {
            let fee_: u256 = self.fee.read();
            let result: u256 = (amount * fee_); // perform some computations
            result
        }

        fn _serveLoan(ref self: ContractState, loanReceiver: ContractAddress, amount: u256) {
            let token: ContractAddress = self.assetAddress.read();
            let contract_this_address = get_contract_address();
            let reserves_: u256 = self.reserves.read();
            let nreserves_: u256 = reserves_ - amount;
            self.reserves.write(nreserves_);

            IERC20Dispatcher { contract_address: token }
                .transfer_from(contract_this_address, loanReceiver, amount);
        }

        fn _acceptTransfer(ref self: ContractState, flashAmount: u256) {
            let assetAddress_ = self.assetAddress.read();
            let caller: ContractAddress = get_caller_address();
        }

        fn _sync(ref self: ContractState) {
            let contract_this_address = get_contract_address();
            let contract_address: ContractAddress = self.assetAddress.read();
            let reserves_: u256 = IERC20Dispatcher { contract_address }
                .balance_of(contract_this_address);
            self.reserves.write(reserves_);
        }

        fn _onFlashLoan(
            ref self: ContractState,
            loanReceiver: ContractAddress,
            initiator: ContractAddress,
            token: ContractAddress,
            amount: u256,
            fee: u256,
            data: felt252
        ) {
            IERC7399RecieverTraitDispatcher { contract_address: loanReceiver }
                .onFlashLoan(initiator, token, amount, fee, data);
        }
    }
}
