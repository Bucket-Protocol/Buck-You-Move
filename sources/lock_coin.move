module sui_gives::lock_coin {
    use sui::clock::{Self, Clock};
    
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use std::string::{Self, String};
    use std::ascii::String as ASCIIString;
    use sui::event;
    use std::type_name;
    use sui::object::{Self, UID,ID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use std::vector;
    use std::hash::{sha3_256};
    
    const WRONG_KEY_OR_NOT_AUTHORIZED: u64 = 0;

    struct LockedCoinCreated has copy, drop {
        LockedCoin_id: ID,
        coin_type: ASCIIString,
        creator: address,
        key_hash: vector<u8>,
        balance: u64,
    }
    struct LockedCoinUnlocked has copy, drop {
        LockedCoin_id: ID,
        coin_type: ASCIIString,
        creator: address,
        recipient: address,
        key: vector<u8>,
        balance: u64,
    }
    fun emit_locked_coin_created<T>(lockedCoin: &LockedCoin<T>) {
        let event = LockedCoinCreated {
            LockedCoin_id: *object::borrow_id(lockedCoin),
            coin_type: type_name::into_string(type_name::get<T>()),
            creator: lockedCoin.creator,
            key_hash: lockedCoin.key_hash,
            balance: balance::value(&lockedCoin.balance),
        };
        event::emit(event);
    }
    fun emit_locked_coin_unlocked<T>(lockedCoin: &LockedCoin<T>, recipient: address, key: vector<u8>) {
        let event = LockedCoinUnlocked {
            LockedCoin_id: *object::borrow_id(lockedCoin),
            coin_type: type_name::into_string(type_name::get<T>()),
            creator: lockedCoin.creator,
            recipient: recipient,
            key: key,
            balance: balance::value(&lockedCoin.balance),
        };
        event::emit(event);
    }
    
    struct LockedCoin <phantom T> has key, store {
        id: UID,
        creator: address,
        key_hash: vector<u8>,
        balance: Balance<T>,
    }
    fun init(_ctx: &mut TxContext) {
    }

    public entry fun lock_coin<T>(
        coin: Coin<T>,
        key_hash: vector<u8>,
        ctx: &mut TxContext
    ){
        let lockedCoin = LockedCoin<T> {
            id: object::new(ctx),
            creator: tx_context::sender(ctx),
            key_hash: key_hash,
            balance: coin::into_balance<T>(coin),
        };
        emit_locked_coin_created(&lockedCoin);
        transfer::public_share_object(lockedCoin);
    }
    public entry fun unlock_coin<T>(
        lockedCoin: &mut LockedCoin<T>,
        key: vector<u8>,
        recipient: address,
        ctx: &mut TxContext
    ){
        let key_matched = sha3_256(key) == lockedCoin.key_hash;
        assert!(
            key_matched || 
            &lockedCoin.creator == &tx_context::sender(ctx), 
            WRONG_KEY_OR_NOT_AUTHORIZED
        );

        let value = balance::value(&lockedCoin.balance);
        
        emit_locked_coin_unlocked(lockedCoin, recipient, key);
        transfer::public_transfer(
            coin::take(
              &mut lockedCoin.balance, 
              value, 
              ctx
            ), 
            recipient
        );
    }
    

    #[test]
    fun test_lock_by_sender_then_unlock_by_receiver() {
        use sui_gives::test_coin::{Self, TEST_COIN};
        use sui::test_scenario;
        use sui::balance;
        use std::debug;
        // create test addresses representing users
        let sender = @0xad;
        let receiver = @0xac;
        
        // first transaction to emulate module initialization
        let scenario_val = test_scenario::begin(sender);
        let scenario = &mut scenario_val;

        let key = x"8714127bd7b54f7cd362ea56141fcf741c9937fb399feec150014511d68b715f";
        let value = 10000;
        {
            init(test_scenario::ctx(scenario));
            // test_coin::init(test_utils::create_one_time_witness<TEST>(), test_scenario::ctx(scenario))
        };

        test_scenario::next_tx(scenario, sender);
        
        
        {
            let coin = coin::from_balance(balance::create_for_testing<TEST_COIN>(value), test_scenario::ctx(scenario));
            let key_hash = sha3_256(key);
            lock_coin(coin, key_hash, test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, receiver);

        {
            let lockedCoin = test_scenario::take_shared<LockedCoin<TEST_COIN>>(scenario);
            unlock_coin(&mut lockedCoin, key, receiver, test_scenario::ctx(scenario));
            test_scenario::return_shared(lockedCoin);
        };

        test_scenario::next_tx(scenario, receiver);

        {
            let coin1 = test_scenario::take_from_address<Coin<TEST_COIN>>(scenario, receiver);
            assert!(balance::value(coin::balance(&coin1)) == value, 0);
            test_scenario::return_to_address(receiver, coin1);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = WRONG_KEY_OR_NOT_AUTHORIZED)]
    fun test_lock_by_sender_then_unlock_by_recevier_by_another_key() {
        use sui_gives::test_coin::{Self, TEST_COIN};
        use sui::test_scenario;
        use sui::balance;
        use std::debug;
        // create test addresses representing users
        let sender = @0xad;
        let receiver = @0xac;
        
        // first transaction to emulate module initialization
        let scenario_val = test_scenario::begin(sender);
        let scenario = &mut scenario_val;

        let key = x"8714127bd7b54f7cd362ea56141fcf741c9937fb399feec150014511d68b715f";
        let dummy_key = x"87";
        let value = 10000;
        {
            init(test_scenario::ctx(scenario));
            // test_coin::init(test_utils::create_one_time_witness<TEST>(), test_scenario::ctx(scenario))
        };

        test_scenario::next_tx(scenario, sender);
        
        
        {
            let coin = coin::from_balance(balance::create_for_testing<TEST_COIN>(value), test_scenario::ctx(scenario));
            let key_hash = sha3_256(key);
            lock_coin(coin, key_hash, test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, receiver);

        {
            let lockedCoin = test_scenario::take_shared<LockedCoin<TEST_COIN>>(scenario);
            unlock_coin(&mut lockedCoin, dummy_key, receiver, test_scenario::ctx(scenario));
            test_scenario::return_shared(lockedCoin);
        };

        test_scenario::next_tx(scenario, receiver);

        {
            let coin1 = test_scenario::take_from_address<Coin<TEST_COIN>>(scenario, receiver);
            assert!(balance::value(coin::balance(&coin1)) == value, 0);
            test_scenario::return_to_address(receiver, coin1);
        };
        
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_lock_by_sender_then_unlock_by_sender_by_another_key() {
        use sui_gives::test_coin::{Self, TEST_COIN};
        use sui::test_scenario;
        use sui::balance;
        use std::debug;
        // create test addresses representing users
        let sender = @0xad;
        let receiver = @0xac;
        
        // first transaction to emulate module initialization
        let scenario_val = test_scenario::begin(sender);
        let scenario = &mut scenario_val;

        let key = x"8714127bd7b54f7cd362ea56141fcf741c9937fb399feec150014511d68b715f";
        let dummy_key = x"87";
        let value = 10000;
        {
            init(test_scenario::ctx(scenario));
            // test_coin::init(test_utils::create_one_time_witness<TEST>(), test_scenario::ctx(scenario))
        };

        test_scenario::next_tx(scenario, sender);
        
        
        {
            let coin = coin::from_balance(balance::create_for_testing<TEST_COIN>(value), test_scenario::ctx(scenario));
            let key_hash = sha3_256(key);
            lock_coin(coin, key_hash, test_scenario::ctx(scenario));
        };

        test_scenario::next_tx(scenario, sender);

        {
            let lockedCoin = test_scenario::take_shared<LockedCoin<TEST_COIN>>(scenario);
            unlock_coin(&mut lockedCoin, dummy_key, receiver, test_scenario::ctx(scenario));
            test_scenario::return_shared(lockedCoin);
        };

        test_scenario::next_tx(scenario, sender);

        {
            let coin1 = test_scenario::take_from_address<Coin<TEST_COIN>>(scenario, sender);
            assert!(balance::value(coin::balance(&coin1)) == value, 0);
            test_scenario::return_to_address(sender, coin1);
        };
        
        test_scenario::end(scenario_val);
    }
    
}
