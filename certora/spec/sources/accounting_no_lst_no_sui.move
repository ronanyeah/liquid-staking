module spec::accounting_no_lst_no_sui;

use cvlm::asserts::{cvlm_assert, cvlm_assume_msg};
use cvlm::function::Function;
use cvlm::manifest::{target, invoker, rule};
use liquid_staking::liquid_staking::{LiquidStakingInfo};
use spec::dummy::DummyToken;
use sui_system::sui_system::SuiSystemState;
use spec::common::setup_fresh;
use spec::solvency::is_solvent;

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

    invoke(target, lsi, system_state, ctx);

    let lst_post = lsi.total_lst_supply();
    let sui_post = lsi.total_sui_supply();

    // sui_pre/lst_pre <= sui_post/lst_post
    // <==> sui_pre*lst_post <= sui_post*lst_pre

    cvlm_assert(sui_post != 0 || lst_post == 0);
}