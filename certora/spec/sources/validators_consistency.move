/// Property: Validator Registry Consistency
/// Description: Ensures the internal validator registry maintains structural invariants critical for
/// correct protocol operation. The total SUI supply tracked in storage must equal the sum of SUI across
/// all validators plus the liquid pool. The registry must not contain duplicate validators (preventing
/// double-counting of stake), and validators can only be added or removed through authorized operations.
/// After refresh operations, the registry must contain no inactive stake or empty validator entries,
/// ensuring clean state. These properties guarantee accurate stake accounting and prevent inconsistencies
/// in the validator management system.

module spec::validators_consistency;

use cvlm::asserts::{cvlm_assert, cvlm_assume_msg};
use cvlm::function::Function;
use cvlm::ghost::ghost_destroy;
use cvlm::manifest::{target, invoker, rule};
use cvlm::nondet::nondet;
use liquid_staking::liquid_staking::LiquidStakingInfo;
use liquid_staking::storage::{Self, Storage, get_sui_amount, active_stake, ValidatorInfo};
use spec::common::{log, setup};
use spec::dummy::DummyToken;
use sui_system::sui_system::SuiSystemState;
use liquid_staking::storage::max_validators;

public fun cvlm_manifest() {
    // Public mut functions

    target(@liquid_staking, b"storage", b"refresh");
    target(@liquid_staking, b"storage", b"change_validator_priority");
    target(@liquid_staking, b"storage", b"join_to_sui_pool");
    target(@liquid_staking, b"storage", b"join_stake");
    target(@liquid_staking, b"storage", b"join_fungible_stake");
    target(@liquid_staking, b"storage", b"join_inactive_stake_to_validator");
    target(@liquid_staking, b"storage", b"join_fungible_staked_sui_to_validator");
    target(@liquid_staking, b"storage", b"split_up_to_n_sui_from_sui_pool");
    target(@liquid_staking, b"storage", b"split_from_sui_pool");
    target(@liquid_staking, b"storage", b"unstake_approx_n_sui_from_validator");
    target(@liquid_staking, b"storage", b"unstake_approx_n_sui_from_active_stake");
    target(@liquid_staking, b"storage", b"unstake_approx_n_sui_from_inactive_stake");
    target(@liquid_staking, b"storage", b"split_n_sui");
    target(@liquid_staking, b"storage", b"get_or_add_validator_index_by_staking_pool_id_mut");

    invoker(b"invoke");

    rule(b"total_sui_supply_correct_base");
    rule(b"total_sui_supply_correct_step");

    rule(b"no_duplicate_validators");
    rule(b"can_add_correct");
    rule(b"can_remove_correct");
    rule(b"add_at_most_one");

    rule(b"validators_upper_bound_base");
    rule(b"validators_upper_bound_step");

    rule(b"no_stake_no_sui_base");
    rule(b"no_stake_no_sui_step");


    rule(b"no_inactive_stake_after_refresh");
    rule(b"no_empty_validators_after_refresh");
}

native fun invoke(
    target: Function,
    strg: &mut Storage,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
);

fun staked_active(strg: &Storage, i: u64): u64 {
    let validator_info = &strg.validators()[i];
    if (validator_info.active_stake().is_some()) {
        let active_stake = validator_info.active_stake().borrow();
        get_sui_amount(
            validator_info.exchange_rate(),
            active_stake.value(),
        )
    } else {
        0
    }
}

fun staked_inactive(strg: &Storage, i: u64): u64 {
    let validator_info = &strg.validators()[i];
    if (validator_info.inactive_stake().is_some()) {
        let inactive_stake = validator_info.inactive_stake().borrow();
        inactive_stake.staked_sui_amount()
    } else {
        0
    }
}

fun validator_sui_supply(strg: &Storage, i: u64): u64 {
    let active_stake = staked_active(strg, i);
    let inactive_stake = staked_inactive(strg, i);

    active_stake + inactive_stake
}

fun current_supply(strg: &Storage): u64 {
    let mut i = 0;
    let mut v = strg.sui_pool().value();

    while (i < strg.validators().length()) {
        v = v + validator_sui_supply(strg, i);
        i = i+1;
    };
    v
}

/// Base case: Verifies that for newly created storage, the total SUI supply equals the computed
/// sum across all validators and the liquid pool.
public fun total_sui_supply_correct_base(ctx: &mut TxContext) {
    let strg = storage::new(ctx);
    let supply = current_supply(&strg);
    let supply_expected = strg.total_sui_supply();
    cvlm_assert(supply == supply_expected);
    ghost_destroy(strg);
}

/// Inductive step: Verifies that all storage operations preserve the invariant that total SUI supply
/// equals the sum across validators and the liquid pool, ensuring accurate accounting.
public fun total_sui_supply_correct_step(
    target: Function,
    strg: &mut Storage,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    cvlm_assume_msg(strg.validators().length() <= 1, b"Only one validator");

    cvlm_assume_msg(ctx.epoch() > strg.last_refresh_epoch(), b"Assume fresh state");
    strg.refresh(system_state, ctx);

    let supply_pre = current_supply(strg);
    let supply_expected_pre = strg.total_sui_supply();
    cvlm_assume_msg(supply_pre == supply_expected_pre, b"Assume invariant holds in pre state");

    invoke(target, strg, system_state, ctx);

    strg.refresh(system_state, ctx); // No necessary but to be extra sure everything is up to date
    let supply_post = current_supply(strg);
    let supply_expected_post = strg.total_sui_supply();
    cvlm_assert(supply_post == supply_expected_post);
}

fun can_add_validator(target: Function): bool {
    target.name() == b"get_or_add_validator_index_by_staking_pool_id_mut"
    || target.name() == b"join_stake"
    || target.name() == b"join_fungible_stake"
}

fun can_remove_validator(target: Function): bool {
    target.name() == b"refresh"
}

/// Verifies that validators can only be added to the registry through explicitly authorized operations
/// (staking operations and direct validator addition), preventing unauthorized registry modifications.
public fun can_add_correct(
    target: Function,
    strg: &mut Storage,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    let validators_pre = strg.validators().length();
    invoke(target, strg, system_state, ctx);
    let validators_post = strg.validators().length();

    let appended = validators_post > validators_pre;
    let allowed = can_add_validator(target);

    cvlm_assert(!appended || allowed);
}

/// Verifies that validators can only be removed from the registry through the refresh operation,
/// which cleans up empty validators, preventing unauthorized validator removal.
public fun can_remove_correct(
    target: Function,
    strg: &mut Storage,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    let validators_pre = strg.validators().length();
    invoke(target, strg, system_state, ctx);
    let validators_post = strg.validators().length();

    let removed = validators_post < validators_pre;
    let allowed = can_remove_validator(target);

    cvlm_assert(!removed || allowed);
}

/// Verifies that adding a validator to the registry only occurs if neither its staking pool ID
/// nor its validator address already exists, preventing duplicate entries and double-counting.
public fun no_duplicate_validators(
    strg: &mut Storage,
    staking_pool_id: ID,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    let validator_address = system_state.validator_address_by_pool_id(&staking_pool_id);

    let mut id_exists = false;
    let mut address_exists = false;

    let infos_pre = strg.validators().length();

    let mut i = 0;
    while (i < infos_pre) {
        let v = &strg.validators()[i];
        id_exists = id_exists || v.staking_pool_id() == staking_pool_id;
        address_exists = address_exists || v.validator_address() == validator_address;
        i = i + 1;
    };

    let index = strg.get_or_add_validator_index_by_staking_pool_id_mut(
        system_state,
        staking_pool_id,
        ctx,
    );
    let appended = index == infos_pre;

    log(&id_exists);
    log(&address_exists);
    log(&appended);

    // appended -> !id_exists && !address_exists
    cvlm_assert(!appended || (!id_exists && !address_exists ));
}

/// Verifies that any single operation can add at most one validator to the registry,
/// preventing bulk additions that could bypass validation logic.
public fun add_at_most_one(
    target: Function,
    strg: &mut Storage,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    let validators_pre = strg.validators().length();
    invoke(target, strg, system_state, ctx);
    let validators_post = strg.validators().length();

    cvlm_assert(validators_post <= validators_pre + 1);
}


public fun validators_upper_bound_base(ctx: &mut TxContext) {
    let strg = storage::new(ctx);
    cvlm_assert(strg.validators().length() <= max_validators());
    ghost_destroy(strg);
}

public fun validators_upper_bound_step(
    target: Function,
    strg: &mut Storage,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    cvlm_assume_msg(strg.validators().length() <= max_validators(), b"Assume in pre state");
    invoke(target, strg, system_state, ctx);
    cvlm_assert(strg.validators().length() <= max_validators());
}

fun validator_no_stake_no_sui(v: &ValidatorInfo): bool {
    let no_active = v.active_stake().is_none();
    let no_inactive = v.inactive_stake().is_none();
    // (no active && no_inactive) => no sui
    !(no_active && no_inactive) || v.total_sui_amount() == 0
}

fun no_stake_no_sui(strg: &Storage): bool {
    let mut ret = true;
    let mut i = 0;
    while (i < strg.validators().length()) {
        let v_i = &strg.validators()[i];
        ret = ret && validator_no_stake_no_sui(v_i);
        i = i+1;
    };
    ret
}

/// Base case: Verifies that for newly created storage, validators with no active or inactive stake
/// have zero total SUI amount recorded.
public fun no_stake_no_sui_base(ctx: &mut TxContext) {
    let strg = storage::new(ctx);
    cvlm_assert(no_stake_no_sui(&strg));
    ghost_destroy(strg);
}

/// Inductive step: Verifies that all operations preserve the invariant that validators with no
/// active or inactive stake have zero total SUI recorded, preventing phantom stake.
public fun no_stake_no_sui_step(
    target: Function,
    strg: &mut Storage,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    cvlm_assume_msg(no_stake_no_sui(strg), b"Assume in pre state");
    invoke(target, strg, system_state, ctx);
    strg.refresh(system_state, ctx);
    cvlm_assert(no_stake_no_sui(strg));
}

/// Verifies that after a refresh operation completes, no validators in the registry contain
/// inactive stake, ensuring all stake has been properly activated or removed.
public fun no_inactive_stake_after_refresh(
    lsi: &mut LiquidStakingInfo<DummyToken>,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    setup(lsi);
    cvlm_assume_msg(ctx.epoch() > lsi.storage().last_refresh_epoch(), b"Force refresh");

    lsi.refresh(system_state, ctx);

    let i = nondet();
    cvlm_assume_msg(i < lsi.storage().validators().length(), b"");

    let inactive = lsi.storage().validators()[i].inactive_stake();
    cvlm_assert(inactive.is_none());
}

/// Verifies that after a refresh operation completes, no validators in the registry are empty
/// (containing no stake), ensuring clean state and accurate registry size.
public fun no_empty_validators_after_refresh(
    lsi: &mut LiquidStakingInfo<DummyToken>,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    setup(lsi);
    cvlm_assume_msg(ctx.epoch() > lsi.storage().last_refresh_epoch(), b"Force refresh");
    cvlm_assume_msg(no_stake_no_sui(lsi.storage()), b"Assume in pre state");

    lsi.refresh(system_state, ctx);

    let i = nondet();
    cvlm_assume_msg(i < lsi.storage().validators().length(), b"");
    let validator = &lsi.storage().validators()[i];

    cvlm_assert(!validator.is_empty());
}
