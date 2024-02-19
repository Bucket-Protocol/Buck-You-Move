#[test_only]
module sui_gives::test_lock {

    use sui::sui::SUI;
    use sui_gives::test_coin::TEST_COIN;
    use sui_gives::test_nft::{Self, TEST_NFT};
    use sui::test_scenario::{Self as ts};
    use sui_gives::locker::{Self, Locker};
    use sui::balance::{Self};
    use sui::coin::{Self, Coin};
    use std::option::{Self};

    #[test]
    fun test_lock() {
        let creator = @0x111;
        let public_key = vector[ 167, 231, 90, 249, 221,  77, 134, 138,  65, 173, 47,  90, 91,   2,  29, 101,  62,  49,   8,  66, 97, 114, 79, 180,  10, 226, 241, 177, 195,  28, 119, 141, 59, 148, 100,  80,  45,  89, 156, 246, 114,   7, 35, 236,  92, 104, 181, 157 ];
        let bls_signature = vector[ 130,  44, 247, 147, 115, 203,  29,  43,  49, 228, 246, 177, 57,  22, 181, 123, 195,  60, 111,  39, 209,  19,   3,  53, 56, 214,  44, 245,  31, 176, 126, 145, 167, 156, 166, 187, 99, 240,  49,  44, 171,  17, 179, 126, 132,  35, 165, 160, 11,   5,   4,  87, 248,  88, 183,  74, 168,  96, 242, 193, 95, 199, 168,  80,  91, 145,  36, 164,  54,  26, 204, 212, 89,  69, 119,  59, 176,   8,  31,  82,  88, 245,  12, 156, 194,  54,  52,  60,  50,  60, 254, 249, 117,  15, 189, 101 ];
        let scenario_val = ts::begin(creator);
        let scenario = &mut scenario_val;
        let value = 1_000;
        {
            locker::init_for_testing(ts::ctx(scenario));
        };

        ts::next_tx(scenario, creator);
        {
            let sui_coin = coin::mint_for_testing<SUI>(value, ts::ctx(scenario));
            let test_coin = coin::mint_for_testing<TEST_COIN>(value, ts::ctx(scenario));
            let test_nft = test_nft::mint(b"test", b"a test", b"https://www.sui.io", creator, ts::ctx(scenario));
            let locker = ts::take_shared<Locker>(scenario);

            locker::create_locker_contents(&mut locker, creator, option::some(creator), public_key, ts::ctx(scenario));
            locker::add_coin(&mut locker, public_key, sui_coin, ts::ctx(scenario));
            locker::add_coin(&mut locker, public_key, test_coin, ts::ctx(scenario));
            locker::add_object(&mut locker, public_key, test_nft, ts::ctx(scenario));
            ts::return_shared(locker);
        };

        let unlocker = @0x4fb6bb32eb3f5e495430e00233d3f21354088eee6e2b2e0c25c11815f90eea53;
        ts::next_tx(scenario, unlocker);
        {
            let locker = ts::take_shared<Locker>(scenario);
            locker::unlock(&mut locker, bls_signature, public_key, unlocker, ts::ctx(scenario));
            locker::remove_coin_to<SUI>(&mut locker, public_key, 0, unlocker, ts::ctx(scenario));
            locker::remove_coin_to<TEST_COIN>(&mut locker, public_key, 1, unlocker, ts::ctx(scenario));
            locker::remove_object_to<TEST_NFT>(&mut locker, public_key, 2, unlocker, ts::ctx(scenario));
            locker::delete_locker_contents(&mut locker, public_key, ts::ctx(scenario));
            ts::return_shared(locker);
        };

        ts::next_tx(scenario, unlocker);
        {
            let test_coin = ts::take_from_address<Coin<TEST_COIN>>(scenario, unlocker);
            assert!(balance::value(coin::balance(&test_coin)) == value, 0);
            ts::return_to_address(unlocker, test_coin);

            let sui_coin = ts::take_from_address<Coin<SUI>>(scenario, unlocker);
            assert!(balance::value(coin::balance(&sui_coin)) == value, 0);
            ts::return_to_address(unlocker, sui_coin);
        };

        ts::end(scenario_val);
    }
}