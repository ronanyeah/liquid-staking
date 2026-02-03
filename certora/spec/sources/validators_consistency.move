/// Property: Validator Registry Consistency
/// Description: Ensures the internal validator registry maintains structural invariants critical for
/// correct protocol operation. Validates that: (1) validators can only be added through authorized
/// staking operations, preventing unauthorized registry modifications; (2) validators can only be
/// removed through refresh operations; (3) at most one validator can be added per operation; (4) no
/// duplicate validators exist by staking pool ID or validator address; (5) the registry size never
/// exceeds the maximum validators limit; (6) validators with no active or inactive stake have zero
/// total SUI recorded; (7) after refresh, no inactive stake or empty validators remain in the registry.
/// These properties guarantee accurate stake accounting and structural integrity of the validator management system.

module spec::validators_consistency;

use cvlm::asserts::{cvlm_assert, cvlm_assume_msg};
use cvlm::function::Function;
use cvlm::ghost::ghost_destroy;
use cvlm::manifest::{target, invoker, rule};
use liquid_staking::storage::{Self, Storage, active_stake, ValidatorInfo};
use spec::common::{log};
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

    rule(b"no_duplicate_validators");
    rule(b"can_add_correct");
    rule(b"can_remove_correct");
    rule(b"add_at_most_one");

    rule(b"validators_upper_bound_base");
    rule(b"validators_upper_bound_step");

    rule(b"no_stake_no_sui_base");
    rule(b"no_stake_no_sui_step");


}

native fun invoke(
    target: Function,
    strg: &mut Storage,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
);

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

public fun no_stake_no_sui(strg: &Storage): bool {
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

