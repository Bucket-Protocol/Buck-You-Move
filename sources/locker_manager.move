module sui_gives::lock_manager {
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
    use sui::object_table::{Self, ObjectTable};
    use sui::dynamic_object_field as dof;

    const ERROR_WRONG_KEY: u64 = 0;
    friend sui_gives::lock_coin;
    friend sui_gives::lock_nft;

    struct LockerManager has key {
        id: UID
    }

    fun init(_ctx: &mut TxContext) {
        create_locker_manager(_ctx);
    }

    public(friend) fun create_locker_manager(ctx: &mut TxContext) {
        transfer::share_object(LockerManager {
            id: object::new(ctx),
        });
    }

    public(friend) fun add_lock<T: key + store>(
        manager: &mut LockerManager,
        key_hash: vector<u8>,
        object: T,
    ) {
        dof::add(&mut manager.id, key_hash, object);
    }

    public(friend) fun remove_lock<T: key + store>(
        manager: &mut LockerManager,
        key: vector<u8>,
    ): T {
        let key_hash = sha3_256(key);
        assert!(dof::exists_(&mut manager.id, key_hash), ERROR_WRONG_KEY);
        dof::remove(&mut manager.id, key_hash)
    }

    public fun lock_exists(
        manager: &mut LockerManager,
        key: vector<u8>,
    ): bool {
        let key_hash = sha3_256(key);
        dof::exists_(&mut manager.id, key_hash)
    }
    public fun lock_exists_by_key_hash(
        manager: &mut LockerManager,
        key_hash: vector<u8>,
    ): bool {
        dof::exists_(&mut manager.id, key_hash)
    }
    
}
