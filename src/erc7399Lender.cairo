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

#[starknet::interface]
trait IERC7399OwnerTrait<TState> {
    fn updateFee(ref self: TState, amount: u256);
    fn deFund(ref self: TState);
}

#[starknet::contract]
mod ERC7399Lender {
    use integer::BoundedInt;
    use starknet::{ContractAddress, get_caller_address};
    use openzeppelin::token::erc20::ERC20Component;
    use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
    use starknet::info::get_contract_address;
    use my_project::erc7399Borrower::{
        IERC7399RecieverTraitDispatcher, IERC7399RecieverTraitDispatcherTrait
    };

    #[storage]
    struct Storage {
        owner: ContractAddress,
        assetAddress: ContractAddress,
        fee: u256,
        reserves: u256
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        ownerAddress: ContractAddress,
        assetAddress: ContractAddress,
        fee: u256
    ) {
        self.fee.write(fee);
        self.assetAddress.write(assetAddress);
        self.owner.write(ownerAddress);
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
        fn maxFlashLoan(self: @ContractState) -> u256 {
            self.reserves.read()
        }

        fn maxFlashLoanSync(ref self: ContractState, asset: ContractAddress) -> u256 {
            let assetAddress = self.assetAddress.read();
            assert(assetAddress == asset, 'asset is not used by lender');
            self._sync();
            self.reserves.read()
        }
        /// this will the function that will get the flash fee
        fn flashFee(self: @ContractState, asset: ContractAddress, amount: u256) -> u256 {
            let assetAddress = self.assetAddress.read();
            assert(assetAddress == asset, 'asset is not used by lender');
            let currReserves: u256 = self.reserves.read();
            if amount <= currReserves {
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
            let assetAddress = self.assetAddress.read();
            assert(assetAddress == asset, 'asset is not used by lender');
            let feeCal = self._flashFee(amount);
            let flash_lender = get_contract_address();
            // when called from borrower it is borrower address //
            let initiator: ContractAddress = get_caller_address();
            let updatedFee: u256 = amount + feeCal;
            self._serveLoan(loanReceiver, amount);
            self._onFlashLoan(loanReceiver, initiator, flash_lender, asset, amount, feeCal, data);
            self._acceptTransfer(asset, initiator, flash_lender, updatedFee);
            self.emit(Flash { from: asset, amount: amount, fee: feeCal });
            true
        }
    }

    #[external(v0)]
    impl IERC7399OwnerTraitImpl of super::IERC7399OwnerTrait<ContractState> {
        fn updateFee(ref self: ContractState, amount: u256) {
            let owner = self.owner.read();
            let caller = get_caller_address();
            assert(owner == caller, 'caller is not owner');
            self.fee.write(amount);
        }

        fn deFund(ref self: ContractState) {
            let owner = self.owner.read();
            let caller = get_caller_address();
            assert(owner == caller, 'caller is not owner');

            let asset: ContractAddress = self.assetAddress.read();
            let this_address: ContractAddress = get_contract_address();
            let amount: u256 = IERC20Dispatcher { contract_address: asset }
                .balance_of(this_address);
            IERC20Dispatcher { contract_address: asset }.transfer(owner, amount);
        }
    }

    #[generate_trait]
    impl FlashFunctions of FlashFunctionsTrait {
        // internal functions of contract
        fn _flashFee(self: @ContractState, amount: u256) -> u256 {
            // this will be in decimals multiple by token decimals value //
            let fee_: u256 = self.fee.read();
            let FEE_CHARGED: u256 = 1000;
            let result: u256 = (amount * fee_) / FEE_CHARGED; // perform some computations
            result
        }

        fn _serveLoan(ref self: ContractState, loanReceiver: ContractAddress, amount: u256) {
            let token: ContractAddress = self.assetAddress.read();
            let reserves_: u256 = self.reserves.read();
            let nreserves_: u256 = reserves_ - amount;
            self.reserves.write(nreserves_);
            IERC20Dispatcher { contract_address: token }.transfer(loanReceiver, amount);
        }

        fn _acceptTransfer(
            ref self: ContractState,
            asset: ContractAddress,
            initiator: ContractAddress,
            this_contract: ContractAddress,
            repaymentAmount: u256
        ) {
            let reserves_: u256 = self.reserves.read();
            let nreserves_: u256 = reserves_ + repaymentAmount;
            self.reserves.write(nreserves_);
            IERC20Dispatcher { contract_address: asset }
                .transfer_from(initiator, this_contract, repaymentAmount);
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
            flash_lender: ContractAddress,
            token: ContractAddress,
            amount: u256,
            fee: u256,
            data: felt252
        ) {
            IERC7399RecieverTraitDispatcher { contract_address: loanReceiver }
                .onFlashLoan(initiator, flash_lender, token, amount, fee, data);
        }
    }
}
