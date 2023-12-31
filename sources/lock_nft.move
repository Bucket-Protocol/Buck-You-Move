module sui_gives::lock_nft {
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
    
    const WRONG_KEY_OR_NOT_AUTHORIZED: u64 = 0;

    struct LockedNFTCreated has copy, drop {
        id: ID,
        creator: address,
        nft_type: ASCIIString,
        nft_id: ID,
        key_hash: vector<u8>,
    }
    struct LockedNFTUnlocked has copy, drop {
        id: ID,
        creator: address,
        nft_type: ASCIIString,
        nft_id: ID,
        recipient: address,
        key: vector<u8>,
    }
    fun emit_locked_nft_created<T: store + key>(
        lockedNFT: &LockedNFT<T>
    ) {
        let event = LockedNFTCreated {
            id: *object::borrow_id(lockedNFT),
            creator: lockedNFT.creator,
            nft_type: type_name::into_string(type_name::get<T>()),
            nft_id: lockedNFT.nft_table_key,
            key_hash: lockedNFT.key_hash,
        };
        event::emit(event);
    }
    fun emit_locked_nft_unlocked<T: store + key>(
        lockedNFT: &LockedNFT<T>,
        recipient: address,
        key: vector<u8>
    ) {
        let event = LockedNFTUnlocked {
            id: *object::borrow_id(lockedNFT),
            creator: lockedNFT.creator,
            nft_type: type_name::into_string(type_name::get<T>()),
            nft_id: lockedNFT.nft_table_key,
            recipient: recipient,
            key: key,
        };
        event::emit(event);
    }
    
    struct LockedNFT <phantom T: store + key> has key, store {
        id: UID,
        creator: address,
        key_hash: vector<u8>,
        nft_object_table: ObjectTable<ID, T>,
        nft_table_key: ID,
    }
    fun init(_ctx: &mut TxContext) {
    }

    public entry fun lock_nft<T: store + key>(
        nft: T,
        key_hash: vector<u8>,
        ctx: &mut TxContext
    ){
        let nft_table_key = object::id(&nft);
        
        let nft_object_table = object_table::new(ctx);
        object_table::add(&mut nft_object_table, nft_table_key, nft);
        let lockedNFT: LockedNFT<T> = LockedNFT {
            id: object::new(ctx),
            creator: tx_context::sender(ctx),
            key_hash: key_hash,
            nft_object_table,
            nft_table_key,
        };
        emit_locked_nft_created(&lockedNFT);
        transfer::public_share_object(lockedNFT);
    }

    public entry fun unlock_nft<T: store + key>(
        lockedNFT: &mut LockedNFT<T>,
        key: vector<u8>,
        recipient: address,
        ctx: &mut TxContext
    ){
        let key_matched = sha3_256(key) == lockedNFT.key_hash;
        assert!(
            key_matched || 
            &lockedNFT.creator == &tx_context::sender(ctx), 
            WRONG_KEY_OR_NOT_AUTHORIZED
        );
        
        let nft = object_table::remove(&mut lockedNFT.nft_object_table, lockedNFT.nft_table_key);
        
        emit_locked_nft_unlocked(lockedNFT, recipient, key);
        transfer::public_transfer(nft, recipient);
    }
}
