module sui_gives::locker {

    use std::hash::sha3_256;
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::dynamic_object_field as dof;
    use sui_gives::object_bag_with_events::ObjectBag;
    use sui::event;
    use std::vector;

    //-------- Events --------------

    struct Locked has copy, drop {
        creator: address,
        lock_id: ID,
        bag_id: ID,
        key_hash: vector<u8>,
    }

    struct Unlocked has copy, drop {
        unlocker: address,
        lock_id: ID,
        bag_id: ID,
        key_hash: vector<u8>,
        key: vector<u8>,
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

    //-------- Public Functions --------------

    public fun create_locker(ctx: &mut TxContext) {
        transfer::share_object(Locker { id: object::new(ctx) })
    }

    public fun lock(
        locker: &mut Locker,
        key_hash: vector<u8>,
        bag: ObjectBag,
        ctx: &mut TxContext,
    ) {
        let creator = tx_context::sender(ctx);
        let bag_id = object::id(&bag);
        let contents = LockerContents {
            id: object::new(ctx),
            bag,
            creator,
        };
        let lock_id = object::id(&contents);
        dof::add(&mut locker.id, key_hash, contents);
        event::emit(Locked { creator, lock_id, bag_id, key_hash });
    }

    public fun unlock(
        locker: &mut Locker,
        key: vector<u8>,
        ctx: &TxContext,
    ): ObjectBag {
        let unlocker = tx_context::sender(ctx);
        let key_hash = sha3_256(key);
        let contents = dof::remove(&mut locker.id, key_hash);
        let lock_id = object::id(&contents);
        let LockerContents { id, bag, creator } = contents;
        let bag_id = object::id(&bag);
        event::emit(Unlocked { unlocker, lock_id, bag_id, key_hash, key });
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
        let lock_id = object::id(&contents);
        let LockerContents { id, bag, creator } = contents;
        assert!(unlocker == creator, 0);
        let bag_id = object::id(&bag);
        event::emit(Unlocked { unlocker, lock_id, bag_id , key_hash, key: vector::empty<u8>()});
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
