module spec::solvency;

use cvlm::asserts::{cvlm_assert, cvlm_assume_msg};
use cvlm::function::Function;
use cvlm::ghost::ghost_destroy;
use cvlm::manifest::{target, invoker, rule};
use cvlm::nondet::nondet;
use liquid_staking::fees::validate_fees;
use liquid_staking::liquid_staking::{Self, LiquidStakingInfo};
use spec::dummy::DummyToken;
use sui_system::sui_system::SuiSystemState;

public fun cvlm_manifest() {
    // Public mut functions

    target(@spec, b"dummy", b"mint");
    target(@spec, b"dummy", b"redeem");
    target(@spec, b"dummy", b"custom_redeem_request");
    target(@spec, b"dummy", b"custom_redeem");
    target(@spec, b"dummy", b"change_validator_priority");
    target(@spec, b"dummy", b"increase_validator_stake");
    target(@spec, b"dummy", b"decrease_validator_stake");
    target(@spec, b"dummy", b"collect_fees");
    target(@spec, b"dummy", b"update_fees");
    target(@spec, b"dummy", b"refresh");
    target(@spec, b"dummy", b"update_metadata");

    invoker(b"invoke");

    rule(b"solvency_base");
    rule(b"solvency_base_staker");
    rule(b"solvency_step");
    rule(b"insolvency_bound");

    rule(b"monotonicity");
    rule(b"no_lst_no_sui");
    rule(b"no_sui_no_lst");
}

const MAX_VALIDATORS: u64 = 1;

native fun invoke(
    target: Function,
    lis: &mut LiquidStakingInfo<DummyToken>,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
);

fun setup_fresh<T>(
    lsi: &mut LiquidStakingInfo<T>,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    cvlm_assume_msg(ctx.epoch() > lsi.storage().last_refresh_epoch(), b"Refresh");

    let mut i = 0;
    while (i < lsi.storage().validators().length()) {
        let validator = &lsi.storage().validators()[i];
        let pool_id = validator.staking_pool_id();
        let active = validator.active_stake();
        let inactive = lsi.storage().validators()[i].inactive_stake();
        if (active.is_some()) {
            cvlm_assume_msg(active.borrow().pool_id() == pool_id, b"Matching pool ids");
        };
        if (inactive.is_some()) {
            cvlm_assume_msg(inactive.borrow().pool_id() == pool_id, b"Matching pool ids");
        };

        i = i+1;
    };

    lsi.refresh(system_state, ctx);
}

/// lsi.total_sui_supply()/lsi.total_lst_supply() >= 1
/// <==> lsi.total_sui_supply() >= lsi.total_lst_supply()
fun is_solvent<T>(lsi: &LiquidStakingInfo<T>): bool {
    let sui_supply = lsi.total_sui_supply();
    let lst_supply = lsi.total_lst_supply();

    sui_supply >= lst_supply
}

/// The base case for the induction.
public fun solvency_base<P: drop>() {
    let fee_config = nondet();
    let lst_treasury_cap = nondet();
    let mut ctx = nondet();
    let (cap, lsi) = liquid_staking::create_lst<P>(fee_config, lst_treasury_cap, &mut ctx);

    cvlm_assert(is_solvent(&lsi));

    ghost_destroy(cap);
    ghost_destroy(lsi);
}

/// The base case for the induction.
public fun solvency_base_staker<P: drop>() {
    let fee_config = nondet();
    let mut system_state = nondet();
    let lst_treasury_cap = nondet();
    let mut ctx = nondet();
    let fungible_staked_suis = nondet();
    let sui = nondet();
    let (cap, lsi) = liquid_staking::create_lst_with_stake<P>(
        &mut system_state,
        fee_config,
        lst_treasury_cap,
        fungible_staked_suis,
        sui,
        &mut ctx,
    );

    cvlm_assert(is_solvent(&lsi));

    ghost_destroy(cap);
    ghost_destroy(lsi);
    ghost_destroy(system_state);
}

/// The induction steps for the solvency invariant.
public fun solvency_step(
    target: Function,
    lsi: &mut LiquidStakingInfo<DummyToken>,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    cvlm_assume_msg(
        lsi.storage().validators().length() <= MAX_VALIDATORS,
        b"Restrict number of validators",
    );
    setup_fresh(lsi, system_state, ctx);

    // cvlm_assume_msg(lsi.accrued_spread_fees() == 0, b"No fees");
    // cvlm_assume_msg(lsi.total_lst_supply() <= 10000 && lsi.total_lst_supply() <= 10000, b"Reasonable values for CEX");
    cvlm_assume_msg(is_solvent(lsi), b"Assume solvency in pre state");

    validate_fees(lsi.fee_config());

    invoke(target, lsi, system_state, ctx);

    cvlm_assert(is_solvent(lsi));
}

public fun insolvency_bound(
    target: Function,
    lsi: &mut LiquidStakingInfo<DummyToken>,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    cvlm_assume_msg(
        lsi.storage().validators().length() <= MAX_VALIDATORS,
        b"Restrict number of validators",
    );
    setup_fresh(lsi, system_state, ctx);

    // cvlm_assume_msg(lsi.accrued_spread_fees() == 0, b"No fees");
    // cvlm_assume_msg(lsi.total_lst_supply() <= 10000 && lsi.total_lst_supply() <= 10000, b"Reasonable values for CEX");
    cvlm_assume_msg(is_solvent(lsi), b"Assume solvency in pre state");

    validate_fees(lsi.fee_config());

    invoke(target, lsi, system_state, ctx);

    cvlm_assert(lsi.total_lst_supply() +1 >= lsi.total_lst_supply());
}

public fun no_lst_no_sui(
    target: Function,
    lsi: &mut LiquidStakingInfo<DummyToken>,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    cvlm_assume_msg(
        lsi.storage().validators().length() <= MAX_VALIDATORS,
        b"Restrict number of validators",
    );
    setup_fresh(lsi, system_state, ctx);

    cvlm_assume_msg(is_solvent(lsi), b"Assume solvency in pre state");

    let lst_pre = lsi.total_lst_supply();
    let sui_pre = lsi.total_sui_supply();

    //      lst=0 -> sui = 0
    // <==> lst != 0 || sui = 0
    cvlm_assume_msg(lst_pre != 0 || sui_pre == 0, b"Assume in pre-state");

    //let mut ctx2: TxContext = nondet();
    //cvlm_assume_msg(ctx.epoch() <= ctx2.epoch(), b"Time");

    invoke(target, lsi, system_state, ctx);

    let lst_post = lsi.total_lst_supply();
    let sui_post = lsi.total_sui_supply();

    // sui_pre/lst_pre <= sui_post/lst_post
    // <==> sui_pre*lst_post <= sui_post*lst_pre

    cvlm_assert(lst_post != 0 || sui_post == 0);
}

public fun no_sui_no_lst(
    target: Function,
    lsi: &mut LiquidStakingInfo<DummyToken>,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    cvlm_assume_msg(
        lsi.storage().validators().length() <= MAX_VALIDATORS,
        b"Restrict number of validators",
    );
    setup_fresh(lsi, system_state, ctx);

    cvlm_assume_msg(is_solvent(lsi), b"Assume solvency in pre state");

    let lst_pre = lsi.total_lst_supply();
    let sui_pre = lsi.total_sui_supply();

    //      sui=0 -> lst=0
    // <==> sui != 0 || lst = 0
    cvlm_assume_msg(sui_pre != 0 || lst_pre == 0, b"Assume in pre-state");

    //let mut ctx2: TxContext = nondet();
    //cvlm_assume_msg(ctx.epoch() <= ctx2.epoch(), b"Time");

    invoke(target, lsi, system_state, ctx);

    let lst_post = lsi.total_lst_supply();
    let sui_post = lsi.total_sui_supply();

    // sui_pre/lst_pre <= sui_post/lst_post
    // <==> sui_pre*lst_post <= sui_post*lst_pre

    cvlm_assert(sui_post != 0 || lst_post == 0);
}

public fun monotonicity(
    target: Function,
    lsi: &mut LiquidStakingInfo<DummyToken>,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    cvlm_assume_msg(
        lsi.storage().validators().length() <= MAX_VALIDATORS,
        b"Restrict number of validators",
    );
    setup_fresh(lsi, system_state, ctx);

    //cvlm_assume_msg(is_solvent(lsi), b"Assume solvency in pre state");

    let lst_pre = lsi.total_lst_supply();
    let sui_pre = lsi.total_sui_supply();

    cvlm_assume_msg(lst_pre > 0 && sui_pre > 0, b"Non-empty reserve");

    //let mut ctx2: TxContext = nondet();
    //cvlm_assume_msg(ctx.epoch() <= ctx2.epoch(), b"Time");

    invoke(target, lsi, system_state, ctx);

    let lst_post = lsi.total_lst_supply();
    let sui_post = lsi.total_sui_supply();

    // sui_pre/lst_pre <= sui_post/lst_post
    // <==> sui_pre*lst_post <= sui_post*lst_pre

    cvlm_assert(sui_pre*lst_post <= sui_post*lst_pre);
}
