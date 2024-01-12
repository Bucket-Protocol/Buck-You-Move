module sui_gives::locker {

    use std::hash::sha3_256;
    use sui::object::{Self, UID, ID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::dynamic_object_field as dof;
    use sui_gives::object_bag::{Self, ObjectBag};
    use sui::event;
    use std::ascii::{String as ASCIIString};
    use std::string::{Self};
    use sui::coin::{Self, Coin};
    use std::type_name;
    use std::option::{Self, Option};

    //-------- Errors --------------
    const ENotAuthorized: u64 = 8;
    const ECanNotUseCoinAtThisFunction: u64 = 7;

    //-------- Events --------------

    struct LockerContentsCreated has copy, drop {
        key_hash: vector<u8>,
        lockerContents_id: ID,
        creator: address,
        unlocker: Option<address>,
        sender: address,
    }

    struct LockerContentsDeleted has copy, drop {
        key_hash: vector<u8>,
        lockerContents_id: ID,
        creator: address,
        unlocker: Option<address>,
        sender: address,
    }

    struct LockerContentsUnlocked has copy, drop {
        key: vector<u8>,
        key_hash: vector<u8>,
        lockerContents_id: ID,
        creator: address,
        unlocker: Option<address>,
        sender: address,
    }

    struct AddCoin has copy, drop {
        key_hash: vector<u8>,
        lockerContents_id: ID,
        coin_type: ASCIIString,
        balance: u64,
        creator: address,
        unlocker: Option<address>,
        sender: address,
    }

    struct AddObject has copy, drop {
        key_hash: vector<u8>,
        lockerContents_id: ID,
        object_type: ASCIIString,
        creator: address,
        unlocker: Option<address>,
        sender: address,
    } 

    struct RemoveCoin has copy, drop {
        key_hash: vector<u8>,
        lockerContents_id: ID,
        coin_type: ASCIIString,
        balance: u64,
        creator: address,
        unlocker: Option<address>,
        sender: address,
    }

    struct RemoveObject has copy, drop {
        key_hash: vector<u8>,
        lockerContents_id: ID,
        object_type: ASCIIString,
        creator: address,
        unlocker: Option<address>,
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
        unlocker: Option<address>,
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
        unlocker: Option<address>,
        key_hash: vector<u8>,
        ctx: &mut TxContext,
    ) {
        let bag = object_bag::new(ctx);
        let contents = LockerContents {
            id: object::new(ctx),
            bag,
            creator,
            unlocker,
        };

        let lockerContents_id = object::id(&contents);
        event::emit(LockerContentsCreated {
            key_hash,
            lockerContents_id,
            creator,
            unlocker,
            sender: tx_context::sender(ctx)
        });

        dof::add(&mut locker.id, key_hash, contents);
    }

    public fun delete_locker_contents(
        locker: &mut Locker,
        key_hash: vector<u8>,
        ctx: &mut TxContext,
    ) {
        let contents = dof::remove<vector<u8>, LockerContents>(&mut locker.id, key_hash);
        let LockerContents { id, bag, creator, unlocker} = contents;
        assert!(
            creator == tx_context::sender(ctx) || 
            *option::borrow(&unlocker) == tx_context::sender(ctx),
            ENotAuthorized
        );

        let lockerContents_id = object::uid_to_inner(&id);
        event::emit(LockerContentsDeleted {
            key_hash,
            lockerContents_id,
            creator,
            unlocker,
            sender: tx_context::sender(ctx),
        });
        
        object_bag::destroy_empty(bag);
        object::delete(id);
    }

    public fun unlock(
        locker: &mut Locker,
        key: vector<u8>,
        unlocker: Option<address>,
        ctx: &mut TxContext,
    ) {
        let key_hash = sha3_256(key);
        let contents = dof::borrow_mut<vector<u8>, LockerContents>(&mut locker.id, key_hash);
        contents.unlocker = unlocker;

        event::emit(LockerContentsUnlocked {
            key,
            key_hash,
            lockerContents_id: object::id(contents),
            creator: contents.creator,
            unlocker,
            sender: tx_context::sender(ctx),
        });
    }


    fun is_not_coin<T>(): bool {
        let type_string_ascii: ASCIIString = type_name::into_string((type_name::get<T>()));
        let type_string = string::from_ascii(type_string_ascii);
        let type_substring = string::utf8(b"");
        if(string::length(&type_string) > 76){
            type_substring = string::sub_string(&type_string, 0, 76);
        };
        let isCoin = type_substring == string::utf8(
            b"0000000000000000000000000000000000000000000000000000000000000002::coin::Coin"
        );
        !isCoin
    }

    public fun add_coin<T>(
        locker: &mut Locker,
        key_hash: vector<u8>,
        v: Coin<T>, 
        ctx: &TxContext
    ) {
        let contents = dof::borrow_mut<vector<u8>, LockerContents>(&mut locker.id, key_hash);
        assert!(contents.creator == tx_context::sender(ctx), ENotAuthorized);

        event::emit(AddCoin {
            key_hash,
            lockerContents_id: object::id(contents),
            coin_type: type_name::into_string((type_name::get<T>())),
            balance: coin::value(&v),
            creator: contents.creator,
            unlocker: contents.unlocker,
            sender: tx_context::sender(ctx),
        });

        let index = object_bag::length(&contents.bag);
        object_bag::add(&mut contents.bag, index, v);
    }

    public fun add_object<V: key + store>(
        locker: &mut Locker,
        key_hash: vector<u8>,
        v: V,
        ctx: &TxContext
    ) {
        assert!(is_not_coin<V>(), ECanNotUseCoinAtThisFunction);
        let contents = dof::borrow_mut<vector<u8>, LockerContents>(
            &mut locker.id,
            key_hash
        );
        assert!(contents.creator == tx_context::sender(ctx), ENotAuthorized);

        event::emit(AddObject {
            key_hash,
            lockerContents_id: object::id(contents),
            object_type: type_name::into_string((type_name::get<V>())),
            creator: contents.creator,
            unlocker: contents.unlocker,
            sender: tx_context::sender(ctx),
        });

        let index = object_bag::length(&contents.bag);
        object_bag::add(&mut contents.bag, index, v);
    }

    public fun remove_coin<T>(
        locker: &mut Locker,
        key_hash: vector<u8>,
        k: u64,
        ctx: &TxContext
    ): Coin<T> {
        let contents = dof::borrow_mut<vector<u8>, LockerContents>(&mut locker.id, key_hash);
        assert!(
            contents.creator == tx_context::sender(ctx) || 
            *option::borrow(&contents.unlocker) == tx_context::sender(ctx),
            ENotAuthorized
        );

        let v = object_bag::remove<Coin<T>>(&mut contents.bag, k);

        event::emit(RemoveCoin {
            key_hash,
            lockerContents_id: object::id(contents),
            coin_type: type_name::into_string((type_name::get<T>())),
            balance: coin::value(&v),
            creator: contents.creator,
            unlocker: contents.unlocker,
            sender: tx_context::sender(ctx),
        });
        v
    }

    public fun remove_object<V: key + store>(
        locker: &mut Locker,
        key_hash: vector<u8>,
        k: u64,
        ctx: &TxContext
    ): V {
        assert!(is_not_coin<V>(), ECanNotUseCoinAtThisFunction);
        let contents = dof::borrow_mut<vector<u8>, LockerContents>(&mut locker.id, key_hash);
        assert!(
            contents.creator == tx_context::sender(ctx) || 
            *option::borrow(&contents.unlocker) == tx_context::sender(ctx),
            ENotAuthorized
        );

        let object = object_bag::remove<V>(&mut contents.bag, k);

        event::emit(RemoveObject {
            key_hash,
            lockerContents_id: object::id(contents),
            object_type: type_name::into_string((type_name::get<V>())),
            creator: contents.creator,
            unlocker: contents.unlocker,
            sender: tx_context::sender(ctx),
        });

        object
    }

    public fun remove_coin_to<T>(
        locker: &mut Locker,
        key_hash: vector<u8>,
        k: u64,
        recipient: address,
        ctx: &TxContext
    ) {
        let coin = remove_coin<T>(locker, key_hash, k, ctx);
        transfer::public_transfer(coin, recipient);
    }

    public fun remove_object_to<V: key + store>(
        locker: &mut Locker,
        key_hash: vector<u8>,
        k: u64,
        recipient: address,
        ctx: &TxContext
    ) {
        let object = remove_object<V>(locker, key_hash, k, ctx);
        transfer::public_transfer(object, recipient);
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
