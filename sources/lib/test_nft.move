#[test_only]
module sui_gives::test_nft {
    use sui::object::{Self, UID};
    use std::string;
    use sui::url::{Self, Url};
    use sui::tx_context::{TxContext};
    
    struct TEST_NFT has key, store {
        id: UID,
        /// Name for the token
        name: string::String,
        /// Description of the token
        description: string::String,
        /// URL for the token
        img_url: Url,
        creator: address,
    }

    /// Create a new nft
    public fun mint(
        name: vector<u8>,
        description: vector<u8>,
        img_url: vector<u8>,
        creator: address,
        ctx: &mut TxContext
    ): TEST_NFT {
        let nft = TEST_NFT {
            id: object::new(ctx),
            name: string::utf8(name),
            description: string::utf8(description),
            img_url: url::new_unsafe_from_bytes(img_url),
            creator: creator
        };
        nft
    }

}
