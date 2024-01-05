// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Similar to `sui::bag`, an `ObjectBag` is a heterogeneous map-like collection. But unlike
/// `sui::bag`, the values bound to these dynamic fields _must_ be objects themselves. This allows
/// for the objects to still exist in storage, which may be important for external tools.
/// The difference is otherwise not observable from within Move.
module sui_gives::object_bag {
    use std::option::Option;
    use sui::object::{Self, ID, UID};
    use sui::dynamic_object_field as ofield;
    use sui::tx_context::TxContext;

    friend sui_gives::locker;

    //-------- Errors --------------

    // Attempted to destroy a non-empty bag
    const EBagNotEmpty: u64 = 0;

    //-------- Objects --------------
    struct ObjectBag has key, store {
        /// the ID of this bag
        id: UID,
        /// the number of key-value pairs in the bag
        size: u64,
    }

    /// Creates a new, empty bag
    public(friend) fun new(ctx: &mut TxContext): ObjectBag {
        ObjectBag {
            id: object::new(ctx),
            size: 0,
        }
    }

    /// Adds a key-value pair to the bag `bag: &mut ObjectBag`
    /// Aborts with `sui::dynamic_field::EFieldAlreadyExists` if the bag already has an entry with
    /// that key `k: K`.
    public(friend) fun add<V: key + store>(bag: &mut ObjectBag, k: u64, v: V) {
        ofield::add(&mut bag.id, k, v);
        bag.size = bag.size + 1;
    }

    /// Immutably borrows the value associated with the key in the bag `bag: &ObjectBag`.
    /// Aborts with `sui::dynamic_field::EFieldDoesNotExist` if the bag does not have an entry with
    /// that key `k: K`.
    /// Aborts with `sui::dynamic_field::EFieldTypeMismatch` if the bag has an entry for the key, but
    /// the value does not have the specified type.
    public(friend) fun borrow<K: copy + drop + store, V: key + store>(bag: &ObjectBag, k: K): &V {
        ofield::borrow(&bag.id, k)
    }

    /// Mutably borrows the value associated with the key in the bag `bag: &mut ObjectBag`.
    /// Aborts with `sui::dynamic_field::EFieldDoesNotExist` if the bag does not have an entry with
    /// that key `k: K`.
    /// Aborts with `sui::dynamic_field::EFieldTypeMismatch` if the bag has an entry for the key, but
    /// the value does not have the specified type.
    /// 
    /// Disabled because it is not needed for the current use case
    /// 
    public(friend) fun borrow_mut<K: copy + drop + store, V: key + store>(bag: &mut ObjectBag, k: K): &mut V {
        ofield::borrow_mut(&mut bag.id, k)
    }

    /// Mutably borrows the key-value pair in the bag `bag: &mut ObjectBag` and returns the value.
    /// Aborts with `sui::dynamic_field::EFieldDoesNotExist` if the bag does not have an entry with
    /// that key `k: K`.
    /// Aborts with `sui::dynamic_field::EFieldTypeMismatch` if the bag has an entry for the key, but
    /// the value does not have the specified type.
    public(friend) fun remove<V: key + store>(bag: &mut ObjectBag, k: u64): V {
        let v = ofield::remove(&mut bag.id, k);
        bag.size = bag.size - 1;
        v
    }

    /// Returns true iff there is an value associated with the key `k: K` in the bag `bag: &ObjectBag`
    public(friend) fun contains<K: copy + drop + store>(bag: &ObjectBag, k: K): bool {
        ofield::exists_<K>(&bag.id, k)
    }

    /// Returns true iff there is an value associated with the key `k: K` in the bag `bag: &ObjectBag`
    /// with an assigned value of type `V`
    public(friend) fun contains_with_type<K: copy + drop + store, V: key + store>(bag: &ObjectBag, k: K): bool {
        ofield::exists_with_type<K, V>(&bag.id, k)
    }

    /// Returns the size of the bag, the number of key-value pairs
    public(friend) fun length(bag: &ObjectBag): u64 {
        bag.size
    }

    /// Returns true iff the bag is empty (if `length` returns `0`)
    public(friend) fun is_empty(bag: &ObjectBag): bool {
        bag.size == 0
    }

    /// Destroys an empty bag
    /// Aborts with `EBagNotEmpty` if the bag still contains values
    public(friend) fun destroy_empty(bag: ObjectBag) {
        let ObjectBag { id, size } = bag;
        assert!(size == 0, EBagNotEmpty);
        object::delete(id)
    }

    /// Returns the ID of the object associated with the key if the bag has an entry with key `k: K`
    /// Returns none otherwise
    public(friend) fun value_id<K: copy + drop + store>(bag: &ObjectBag, k: K): Option<ID> {
        ofield::id(&bag.id, k)
    }
}
