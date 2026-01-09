module spec::solvency;

use cvlm::asserts::{cvlm_assert, cvlm_assume_msg, cvlm_assert_msg};
use cvlm::function::Function;
use cvlm::ghost::ghost_destroy;
use cvlm::manifest::{target, invoker, rule};
use cvlm::nondet::nondet;
use liquid_staking::liquid_staking::{Self, LiquidStakingInfo, AdminCap, CustomRedeemRequest};
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

    rule(b"monotonicity");
    rule(b"rate_changes_only_if");
}

native fun invoke(
    target: Function,
    lis: &mut LiquidStakingInfo<DummyToken>,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
);

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
    cvlm_assume_msg(ctx.epoch() > lsi.storage().last_refresh_epoch(), b"Refresh");
    lsi.refresh(system_state, ctx);
    //lsi.fee_config().validate_fees();
    cvlm_assume_msg(is_solvent(lsi), b"Assume solvency in pre state");

    let mut ctx2: TxContext = nondet();
    cvlm_assume_msg(ctx.epoch() <= ctx2.epoch(), b"Time");

    invoke(target, lsi, system_state, &mut ctx2);

    //lsi.refresh(system_state, ctx);
    cvlm_assert(is_solvent(lsi));
}

public fun monotonicity(
    target: Function,
    lsi: &mut LiquidStakingInfo<DummyToken>,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {

    cvlm_assume_msg(ctx.epoch() > lsi.storage().last_refresh_epoch(), b"Refresh");
    lsi.refresh(system_state, ctx);
    //lsi.fee_config().validate_fees();
    cvlm_assume_msg(is_solvent(lsi), b"Assume solvency in pre state");

    let lst_pre = lsi.total_lst_supply();
    let sui_pre = lsi.total_sui_supply();


    let mut ctx2: TxContext = nondet();
    cvlm_assume_msg(ctx.epoch() <= ctx2.epoch(), b"Time");

    invoke(target, lsi, system_state, &mut ctx2);

    let lst_post = lsi.total_lst_supply();
    let sui_post = lsi.total_sui_supply();

    // sui_pre/lst_pre <= sui_post/lst_post
    // <==> sui_pre*lst_post <= sui_post*lst_pre

    cvlm_assert(sui_pre*lst_post <= sui_post*lst_pre);
}

public fun rate_changes_only_if(
    target: Function,
    lsi: &mut LiquidStakingInfo<DummyToken>,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    let lst_pre = lsi.total_lst_supply();
    let sui_pre = lsi.total_sui_supply();

    let epoch_pre = lsi.storage().last_refresh_epoch();
    cvlm_assume_msg(ctx.epoch() >= epoch_pre, b"Don't perform actions in the past");

    invoke(target, lsi, system_state, ctx);

    let lst_post = lsi.total_lst_supply();
    let sui_post = lsi.total_sui_supply();

    // sui_pre/lst_pre != sui_post/lst_post
    // <==> sui_pre*lst_post != sui_post*lst_pre
    let changed = sui_pre*lst_post != sui_post*lst_pre;
    let is_refresh = target.name() == b"refresh";
    let new_epoch = epoch_pre < lsi.storage().last_refresh_epoch();

    if (changed) {
        cvlm_assert(new_epoch || is_refresh) // must be &&?
    } else {
        cvlm_assert(true) // please the prover
    }
}
