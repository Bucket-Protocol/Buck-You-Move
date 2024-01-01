#[test_only]
module sui_gives::test_coin {
    
    // use std::option;
    // use sui::coin::{Self, Coin};
    // use sui::transfer;
    // use sui::tx_context::TxContext;

    struct TEST_COIN has drop {}
    
    // fun init(otw: TEST_COIN, ctx: &mut TxContext) {
    //     let (treasury_cap, metadata) = coin::create_currency(
    //         otw, 
    //         2, 
    //         b"TEST", 
    //         b"TEST", 
    //         b"", 
    //         option::none(), 
    //         ctx
    //     );
    //     transfer::public_share_object(treasury_cap);
    //     transfer::public_share_object(metadata);
    // }
}
