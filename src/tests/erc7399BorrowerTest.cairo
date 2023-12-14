mod erc7399BorrowerTest {
    use core::serde::Serde;
    use core::debug::PrintTrait;
    use integer::BoundedInt;
    use my_project::erc7399Lender::{
        IERC7399TraitDispatcher, IERC7399TraitDispatcherTrait, ERC7399Lender
    };
    use my_project::erc7399Borrower::{
        IERC7399RecieverTraitDispatcher, IERC7399RecieverTraitDispatcherTrait, ERC7399Borrower
    };
    // Import the deploy syscall to be able to deploy the contract.
    use starknet::class_hash::Felt252TryIntoClassHash;
    use starknet::{
        deploy_syscall, ContractAddress, get_caller_address, get_contract_address,
        contract_address_const
    };
    // Use starknet test utils to fake the transaction context.
    use starknet::testing::{set_caller_address, set_contract_address};

    // import the token //

    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use my_project::mocks::mock_erc20::MyToken;
    use my_project::mocks::mock_erc20::{
        ERC20ExternalTraitDispatcher, ERC20ExternalTraitDispatcherTrait
    };

    fn deploy_token() -> (IERC20Dispatcher, ERC20ExternalTraitDispatcher, ContractAddress) {
        let mut calldata = ArrayTrait::new();
        // Declare and deploy
        let (contract_address, _) = deploy_syscall(
            MyToken::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
        )
            .unwrap();

        // Return the dispatcher.
        // The dispatcher allows to interact with the contract based on its interface.
        (
            IERC20Dispatcher { contract_address },
            ERC20ExternalTraitDispatcher { contract_address },
            contract_address
        )
    }
    // token part over //

    // Deploy the contract and return its dispatcher.
    fn deploy_lender(
        token: ContractAddress, initial_value: u256
    ) -> (IERC7399TraitDispatcher, ContractAddress) {
        // Set up constructor arguments.
        let mut calldata = ArrayTrait::new();
        token.serialize(ref calldata);
        initial_value.serialize(ref calldata);

        // Declare and deploy
        let (contract_address, _) = deploy_syscall(
            ERC7399Lender::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
        )
            .unwrap();

        // Return the dispatcher.
        // The dispatcher allows to interact with the contract based on its interface.
        (IERC7399TraitDispatcher { contract_address }, contract_address)
    }
    // Deploy the borrower //
    fn deploy_borrower(
        lenderAddress: ContractAddress
    ) -> (IERC7399RecieverTraitDispatcher, ContractAddress) {
        let mut calldata = ArrayTrait::new();
        lenderAddress.serialize(ref calldata);

        // Declare and deploy
        let (contract_address, _) = deploy_syscall(
            ERC7399Borrower::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
        )
            .unwrap();

        // Return the dispatcher.
        // The dispatcher allows to interact with the contract based on its interface.
        (IERC7399RecieverTraitDispatcher { contract_address }, contract_address)
    }

    #[test]
    #[available_gas(2000000000)]
    fn test_flash_borrow() {
        let flashFee: u256 = 10;
        let (tokenDispatcher, tokenExternalDispatcher, token) = deploy_token();
        let (lenderContract, lenderAddress) = deploy_lender(token, flashFee);
        let (borrowerContract, borrowerAddress) = deploy_borrower(lenderAddress);

        // fund something to lender //
        tokenExternalDispatcher.mint(lenderAddress, 1000_u256);
        // calling the sync function //
        lenderContract.maxFlashLoanSync(token);

        // Fake the caller address to address 1
        let caller = contract_address_const::<1>();
        set_caller_address(caller);
        // this is done because initially borrower has zero token but fee cal is 1 so when transferring 
        // only amount will be transfered to borrower but amount+fee is the repayment that need to transferred
        // so we have to add fee manually or make it smaller // 
        tokenExternalDispatcher.mint(borrowerAddress, 1_u256);

        borrowerContract.flashBorrow(token, 100_u256, 'flash borrow');
        assert(tokenDispatcher.balance_of(lenderAddress) == 1001_u256, 'lender balance');
        assert(tokenDispatcher.balance_of(borrowerAddress) == 0_u256, 'borrower balance');
    }
}
