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
    use sui_gives::lock_manager::{Self, LockerManager, add_lock, remove_lock};
    
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
        lockerManager: &mut LockerManager,
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
        add_lock(lockerManager, key_hash, lockedCoin);
    }
    public entry fun unlock_coin<T>(
        // lockedCoin: &mut LockedCoin<T>,
        lockerManager: &mut LockerManager,
        key: vector<u8>,
        recipient: address,
        ctx: &mut TxContext
    ){
        let lockedCoin: LockedCoin<T> = remove_lock(lockerManager, key);
        
        let value = balance::value(&lockedCoin.balance);
        
        emit_locked_coin_unlocked(&lockedCoin, recipient, key);
        
        let LockedCoin { id, creator, key_hash, balance } = lockedCoin;
        transfer::public_transfer(
            coin::from_balance(balance, ctx),
            recipient
        );
        object::delete(id);
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
            lock_manager::create_locker_manager(test_scenario::ctx(scenario));
            init(test_scenario::ctx(scenario));
            // test_coin::init(test_utils::create_one_time_witness<TEST>(), test_scenario::ctx(scenario))
        };

        test_scenario::next_tx(scenario, sender);
        
        {
            let lockerManager = test_scenario::take_shared<LockerManager>(scenario);
            let coin = coin::from_balance(balance::create_for_testing<TEST_COIN>(value), test_scenario::ctx(scenario));
            let key_hash = sha3_256(key);
            lock_coin( &mut lockerManager, coin, key_hash, test_scenario::ctx(scenario));
            test_scenario::return_shared(lockerManager);
        };

        test_scenario::next_tx(scenario, receiver);

        {
            let lockerManager = test_scenario::take_shared<LockerManager>(scenario);
            unlock_coin<TEST_COIN>(&mut lockerManager, key, receiver, test_scenario::ctx(scenario));
            test_scenario::return_shared(lockerManager);
        };

        test_scenario::next_tx(scenario, receiver);

        {
            let coin1 = test_scenario::take_from_address<Coin<TEST_COIN>>(scenario, receiver);
            assert!(balance::value(coin::balance(&coin1)) == value, 0);
            test_scenario::return_to_address(receiver, coin1);
        };
        
        test_scenario::end(scenario_val);
    }
}
