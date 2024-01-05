#[test_only]
module sui_gives::test_lock {

    use std::hash::sha3_256;
    use sui::sui::SUI;
    use sui_gives::test_coin::TEST_COIN;
    use sui_gives::test_nft::{Self, TEST_NFT};
    use sui::test_scenario::{Self as ts};
    use sui_gives::locker::{Self, Locker};
    use sui::balance::{Self};
    use sui::coin::{Self, Coin};

    #[test]
    fun test_lock() {
        let creator = @0x111;
        let key = vector[1, 2, 3, 4, 5];
        let key_hash = sha3_256(key);

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

            locker::create_locker_contents(&mut locker, creator, creator, key_hash, ts::ctx(scenario));
            locker::add_coin(&mut locker, key_hash, sui_coin, ts::ctx(scenario));
            locker::add_coin(&mut locker, key_hash, test_coin, ts::ctx(scenario));
            locker::add_object(&mut locker, key_hash, test_nft, ts::ctx(scenario));
            ts::return_shared(locker);
        };

        let unlocker = @0x222;
        ts::next_tx(scenario, unlocker);
        {
            let locker = ts::take_shared<Locker>(scenario);
            locker::unlock(&mut locker, key, unlocker);
            locker::remove_coin_to<SUI>(&mut locker, key_hash, 0, unlocker, ts::ctx(scenario));
            locker::remove_coin_to<TEST_COIN>(&mut locker, key_hash, 1, unlocker, ts::ctx(scenario));
            locker::remove_object_to<TEST_NFT>(&mut locker, key_hash, 2, unlocker, ts::ctx(scenario));
            locker::delete_locker_contents(&mut locker, key_hash, ts::ctx(scenario));
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