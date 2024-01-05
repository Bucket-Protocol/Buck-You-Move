#[test_only]
module sui_gives::test_lock {

    use std::hash::sha3_256;
    use sui_gives::object_bag;
    use sui::coin;
    use sui::sui::SUI;
    use sui_gives::test_coin::TEST_COIN;
    use sui::test_scenario::{Self as ts};
    use sui_gives::locker::{Self, Locker};

    #[test]
    fun test_lock() {
        let creator = @0x111;
        let key = vector[1, 2, 3, 4, 5];
        let key_hash = sha3_256(key);

        let scenario_val = ts::begin(creator);
        let scenario = &mut scenario_val;
        {
            locker::init_for_testing(ts::ctx(scenario));
        };

        ts::next_tx(scenario, creator);
        {
            let bag = object_bag::new(ts::ctx(scenario));
            let sui_coin = coin::mint_for_testing<SUI>(1_000, ts::ctx(scenario));
            object_bag::add_coin(&mut bag, 1, sui_coin, ts::ctx(scenario));
            let test_coin = coin::mint_for_testing<TEST_COIN>(1_000, ts::ctx(scenario));
            object_bag::add_coin(&mut bag, 2, test_coin, ts::ctx(scenario));
            let locker = ts::take_shared<Locker>(scenario);
            locker::lock(&mut locker, key_hash, bag, ts::ctx(scenario));
            ts::return_shared(locker);
        };

        let unlocker = @0x222;
        ts::next_tx(scenario, unlocker);
        {
            let locker = ts::take_shared<Locker>(scenario);
            locker::unlock_to(&mut locker, key, unlocker, ts::ctx(scenario));
            ts::return_shared(locker);
        };

        ts::end(scenario_val);
    }
}