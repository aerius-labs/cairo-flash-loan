mod erc7399LenderTest {
    use core::serde::Serde;
    use my_project::erc7399Lender::{
        IERC7399RecieverTrait, IERC7399RecieverTraitDispatcher, IERC7399TraitDispatcher,
        IERC7399TraitDispatcherTrait, ERC7399Lender
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
    fn deploy(token: ContractAddress, initial_value: u256) -> IERC7399TraitDispatcher {
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
        IERC7399TraitDispatcher { contract_address }
    }

    #[test]
    #[available_gas(2000000000)]
    fn test_deploy() {
        let initial_value: u256 = 0;
        let (tokenDispatcher, tokenExternalDispatcher, token) = deploy_token();
        let contract = deploy(token, initial_value);
        assert(contract.maxFlashLoan() == initial_value, 'Testing');

        let recipient = contract_address_const::<1>();
        let value: u256 = 100;
        assert(tokenDispatcher.balance_of(recipient) == value, 'initial test');
        tokenExternalDispatcher.mint(recipient, value);
        assert(tokenDispatcher.balance_of(recipient) == value, 'final test');
    }
}
