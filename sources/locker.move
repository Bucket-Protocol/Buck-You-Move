module sui_gives::locker {

    use std::hash::sha3_256;
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::dynamic_object_field as dof;
    use sui_gives::object_bag::{Self, ObjectBag};
    use sui::event;
    use std::vector;
    use std::ascii::{String as ASCIIString};
    use std::string::{Self};
    use sui::coin::{Self, Coin};
    use std::type_name;

    //-------- Errors --------------
    const EOnlyCreatorCanLock: u64 = 8;
    const ECanNotUseCoinAtThisFunction: u64 = 7;

    //-------- Events --------------

    struct Locked has copy, drop {
        key_hash: vector<u8>,
        bag_id: ID,
        creator: address,
        lockerContent_id: ID,
    }

    struct Unlocked has copy, drop {
        key_hash: vector<u8>,
        bag_id: ID,
        creator: address,
        unlocker: address,
        lockerContent_id: ID,
        key: vector<u8>,
    }

    struct AddCoin has copy, drop {
        key_hash: vector<u8>,
        bag_id: ID,
        coin_type: ASCIIString,
        balance: u64,
        sender: address,
    }
    struct AddObject has copy, drop {
        key_hash: vector<u8>,
        bag_id: ID,
        object_type: ASCIIString,
        sender: address,
    }
    struct RemoveCoin has copy, drop {
        bag_id: ID,
        coin_type: ASCIIString,
        balance: u64,
        sender: address,
    }
    struct RemoveObject has copy, drop {
        bag_id: ID,
        object_type: ASCIIString,
        sender: address,
    }

    //-------- Objects --------------

    struct Locker has key {
        id: UID
    }

    struct LockerContents has key, store {
        id: UID,
        bag: ObjectBag,
        creator: address,
    }

    //-------- Constructor --------------

    fun init(ctx: &mut TxContext) {
        create_locker(ctx);
    }

    fun create_locker(ctx: &mut TxContext) {
        transfer::share_object(Locker { id: object::new(ctx) })
    }

    //-------- Public Functions --------------


    public fun create_locker_contents(
        locker: &mut Locker,
        creator: address,
        key_hash: vector<u8>,
        ctx: &mut TxContext,
    ) {
        let bag = object_bag::new(ctx);
        let contents = LockerContents {
            id: object::new(ctx),
            bag,
            creator,
        };
        dof::add(&mut locker.id, key_hash, contents);
    }


    public fun lock_coin<T>(
        locker: &mut Locker,
        key_hash: vector<u8>,
        v: Coin<T>, 
        ctx: &TxContext
    ) {
        let contents = dof::borrow_mut<vector<u8>, LockerContents>(&mut locker.id, key_hash);
        assert!(contents.creator == tx_context::sender(ctx), EOnlyCreatorCanLock);
        let index = object_bag::length(&contents.bag);
        object_bag::add_coin(&mut contents.bag, index, v, ctx);
    }

    public fun lock_object<T: key + store>(
        locker: &mut Locker,
        key_hash: vector<u8>,
        v: T,
        ctx: &TxContext
    ) {
        let contents = dof::borrow_mut<vector<u8>, LockerContents>(&mut locker.id, key_hash);
        assert!(contents.creator == tx_context::sender(ctx), EOnlyCreatorCanLock);
        let index = object_bag::length(&contents.bag);
        object_bag::add_object(&mut contents.bag, index, v, ctx);
    }

    public fun unlock(
        locker: &mut Locker,
        key: vector<u8>,
        ctx: &TxContext,
    ): ObjectBag {
        let unlocker = tx_context::sender(ctx);
        let key_hash = sha3_256(key);
        let contents = dof::remove(&mut locker.id, key_hash);
        let lockerContent_id = object::id(&contents);
        let LockerContents { id, bag, creator: _ } = contents;
        let bag_id = object::id(&bag);
        event::emit(Unlocked { unlocker, lockerContent_id, bag_id, key_hash, key });
        object::delete(id);
        bag
    }

    public fun unlock_to(
        locker: &mut Locker,
        key: vector<u8>,
        recipient: address,
        ctx: &TxContext,
    ) {
        let bag = unlock(locker, key, ctx);
        transfer::public_transfer(bag, recipient);
    }

    public fun unlock_by_creator(
        locker: &mut Locker,
        key_hash: vector<u8>,
        ctx: &TxContext,
    ): ObjectBag {
        let unlocker = tx_context::sender(ctx);
        let contents = dof::remove(&mut locker.id, key_hash);
        let lockerContent_id = object::id(&contents);
        let LockerContents { id, bag, creator } = contents;
        assert!(unlocker == creator, 0);
        let bag_id = object::id(&bag);
        event::emit(Unlocked { unlocker, lockerContent_id, bag_id , key_hash, key: vector::empty<u8>()});
        object::delete(id);
        bag
    }

    //-------- Getter Functions --------------

    public fun lock_exists(
        locker: &Locker,
        key_hash: vector<u8>,
    ): bool {
        dof::exists_with_type<vector<u8>, LockerContents>(&locker.id, key_hash)
    }

    //-------- Test-only Functions --------------

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}
