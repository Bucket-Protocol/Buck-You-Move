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
        transfer::public_share_object(lockedNFT);
    }

    public entry fun unlock_nft<T: store + key>(
        lockedNFT: &mut LockedNFT<T>,
        key: vector<u8>,
        ctx: &mut TxContext
    ){
        let key_matched = sha3_256(key) == lockedNFT.key_hash;
        assert!(
            key_matched || 
            &lockedNFT.creator == &tx_context::sender(ctx), 
            WRONG_KEY_OR_NOT_AUTHORIZED
        );
        
        let nft = object_table::remove(&mut lockedNFT.nft_object_table, lockedNFT.nft_table_key);
        let recipient = tx_context::sender(ctx);
        transfer::public_transfer(nft, recipient);
    }
}
