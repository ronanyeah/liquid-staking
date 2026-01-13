module spec::accounting_total_sui_supply;

use cvlm::asserts::{cvlm_assert, cvlm_assume_msg};
use cvlm::function::Function;
use cvlm::ghost::ghost_destroy;
use cvlm::manifest::{target, invoker, rule};
use liquid_staking::storage::{Self, Storage, get_sui_amount, active_stake};
use sui_system::sui_system::SuiSystemState;

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

public fun total_supply_correct(strg: &Storage): bool {
    let expected = current_supply(strg);
    let actual  = strg.total_sui_supply();
    expected == actual
}

public fun total_sui_supply_correct_base(ctx: &mut TxContext) {
    let strg = storage::new(ctx);
    cvlm_assert(total_supply_correct(&strg));
    ghost_destroy(strg);
}

public fun total_sui_supply_correct_step(
    target: Function,
    strg: &mut Storage,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    cvlm_assume_msg(strg.validators().length() <= 1, b"Only one validator");

    cvlm_assume_msg(ctx.epoch() > strg.last_refresh_epoch(), b"Assume fresh state");
    strg.refresh(system_state, ctx);


    cvlm_assume_msg(total_supply_correct(strg), b"Assume invariant holds in pre state");

    invoke(target, strg, system_state, ctx);

    strg.refresh(system_state, ctx); // No necessary but to be extra sure everything is up to date
    cvlm_assert(total_supply_correct(strg));
}


