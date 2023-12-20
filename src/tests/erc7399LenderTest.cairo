mod erc7399LenderTest {
    use my_project::erc7399Lender::IERC7399OwnerTraitDispatcherTrait;
    use core::serde::Serde;
    use integer::BoundedInt;
    use core::debug::PrintTrait;
    use my_project::erc7399Lender::{
        IERC7399TraitDispatcher, IERC7399TraitDispatcherTrait, IERC7399OwnerTrait,
        IERC7399OwnerTraitDispatcher, ERC7399Lender
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
        owner: ContractAddress, token: ContractAddress, initial_value: u256
    ) -> (IERC7399TraitDispatcher, IERC7399OwnerTraitDispatcher, ContractAddress) {
        // Set up constructor arguments.
        let mut calldata = ArrayTrait::new();
        owner.serialize(ref calldata);
        token.serialize(ref calldata);
        initial_value.serialize(ref calldata);

        // Declare and deploy
        let (contract_address, _) = deploy_syscall(
            ERC7399Lender::TEST_CLASS_HASH.try_into().unwrap(), 0, calldata.span(), false
        )
            .unwrap();

        // Return the dispatcher.
        // The dispatcher allows to interact with the contract based on its interface.
        (
            IERC7399TraitDispatcher { contract_address },
            IERC7399OwnerTraitDispatcher { contract_address },
            contract_address
        )
    }

    #[test]
    #[available_gas(2000000000)]
    fn test_max_flash_loan() {
        let flashFee: u256 = 3;
        let initial_reserves: u256 = 0;
        let (tokenDispatcher, tokenExternalDispatcher, token) = deploy_token();
        let owner = contract_address_const::<12123>();
        let (lenderContract, lenderOwnerContract, lenderAddress) = deploy_lender(
            owner, token, initial_reserves
        );
        assert(lenderContract.maxFlashLoan() == initial_reserves, 'Testing');
    }

    #[test]
    #[available_gas(2000000000)]
    fn test_max_flash_loan_sync() {
        let flashFee: u256 = 3;
        let (tokenDispatcher, tokenExternalDispatcher, token) = deploy_token();
        let owner = contract_address_const::<12123>();
        let (lenderContract, lenderOwnerContract, lenderAddress) = deploy_lender(
            owner, token, flashFee
        );
        assert(lenderContract.maxFlashLoanSync(token) == 0_u256, 'Error in Intital lenderReserves');
        tokenExternalDispatcher.mint(lenderAddress, 1000_u256);
        assert(
            lenderContract.maxFlashLoanSync(token) == 1000_u256, 'Error in Final lenderReserves'
        );
    }

    #[test]
    #[available_gas(2000000000)]
    fn test_flash_fee() {
        let flashFee: u256 = 10;
        let (tokenDispatcher, tokenExternalDispatcher, token) = deploy_token();
        let owner = contract_address_const::<12123>();
        let (lenderContract, lenderOwnerContract, lenderAddress) = deploy_lender(
            owner, token, flashFee
        );

        let amount: u256 = 100;
        let reserves: u256 = lenderContract.maxFlashLoan();
        let cal_fee: u256 = lenderContract.flashFee(token, amount);
        // Original fee calculation //
        let FEE_CHARGED: u256 = 1000;
        let result: u256 = (amount * flashFee) / FEE_CHARGED;
        // original fee calculation //
        if amount <= reserves {
            assert(cal_fee == result, 'Error in flashfee calculation');
        } else {
            assert(cal_fee == BoundedInt::max(), 'Error in flashfee calculation');
        }
    }

    #[test]
    #[should_panic]
    #[available_gas(2000000000)]
    fn test_max_flash_loan_sync_token_address() {
        let flashFee: u256 = 3;
        let (tokenDispatcher, tokenExternalDispatcher, token) = deploy_token();
        let owner = contract_address_const::<12123>();
        let (lenderContract, lenderOwnerContract, lenderAddress) = deploy_lender(
            owner, token, flashFee
        );
        let fakeAddress = contract_address_const::<121>();
        assert(
            lenderContract.maxFlashLoanSync(fakeAddress) == 0_u256, 'asset is not used by lender'
        );
    }

    #[test]
    #[should_panic]
    #[available_gas(2000000000)]
    fn test_flash_fee_token_address() {
        let flashFee: u256 = 10;
        let (tokenDispatcher, tokenExternalDispatcher, token) = deploy_token();
        let owner = contract_address_const::<12123>();
        let (lenderContract, lenderOwnerContract, lenderAddress) = deploy_lender(
            owner, token, flashFee
        );

        let amount: u256 = 100;
        let fakeAddress = contract_address_const::<121>();
        let cal_fee: u256 = lenderContract.flashFee(fakeAddress, amount);
    }

    #[test]
    #[available_gas(2000000000)]
    fn test_update_fee() {
        let flashFee: u256 = 10;
        let owner: ContractAddress = contract_address_const::<12123>();
        let (tokenDispatcher, tokenExternalDispatcher, token) = deploy_token();
        let (lenderContract, lenderOwnerContract, lenderAddress) = deploy_lender(
            owner, token, flashFee
        );
        tokenExternalDispatcher.mint(lenderAddress, 1000_u256);
        lenderContract.maxFlashLoanSync(token);
        let initialFee: u256 = lenderContract.flashFee(token, 100_u256);
        set_contract_address(owner);
        lenderOwnerContract.updateFee(100_u256);
        let finalFee: u256 = lenderContract.flashFee(token, 100_256);
        assert(initialFee != finalFee, 'fee not updated by owner');
    }

    #[test]
    #[available_gas(2000000000)]
    fn test_defund() {
        let flashFee: u256 = 10;
        let owner: ContractAddress = contract_address_const::<12123>();
        let (tokenDispatcher, tokenExternalDispatcher, token) = deploy_token();
        let (lenderContract, lenderOwnerContract, lenderAddress) = deploy_lender(
            owner, token, flashFee
        );
        tokenExternalDispatcher.mint(lenderAddress, 1000_u256);
        lenderContract.maxFlashLoanSync(token);
        set_contract_address(owner);
        lenderOwnerContract.deFund();
        let finalBalance: u256 = tokenDispatcher.balance_of(lenderAddress);
        assert(finalBalance == 0_u256, 'Defund not successfull');
    }
}
