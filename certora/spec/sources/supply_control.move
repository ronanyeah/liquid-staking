module spec::supply_control;

use cvlm::asserts::{cvlm_assert, cvlm_assume_msg};
use cvlm::function::Function;

use cvlm::manifest::{target, invoker, rule};

use liquid_staking::liquid_staking::LiquidStakingInfo;
use spec::accounting_total_sui_supply::total_supply_correct;
use spec::common::{setup_fresh, can_decrease_supply, can_increase_supply};
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

    rule(b"only_redemption_decreases_sui_supply");
    rule(b"only_redemption_decreases_lst_supply");
    rule(b"only_minting_increases_sui_supply");
    rule(b"only_minting_increases_lst_supply");

}

native fun invoke(
    target: Function,
    lsi: &mut LiquidStakingInfo<DummyToken>,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
);

public fun only_redemption_decreases_sui_supply(
    target: Function,
    lsi: &mut LiquidStakingInfo<DummyToken>,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    setup_fresh(lsi, system_state, ctx);
    let sui_pre = lsi.total_sui_supply();

    cvlm_assume_msg(total_supply_correct(lsi.storage()), b"Sound state");
    invoke(target, lsi, system_state, ctx);

    let sui_post = lsi.total_sui_supply();

    let sui_decrease = sui_post < sui_pre;


    let decreased = sui_decrease;

    cvlm_assert(!decreased || can_decrease_supply(target));
}

public fun only_redemption_decreases_lst_supply(
    target: Function,
    lsi: &mut LiquidStakingInfo<DummyToken>,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    setup_fresh(lsi, system_state, ctx);
    let lst_pre = lsi.total_lst_supply();

    invoke(target, lsi, system_state, ctx);

    let lst_post = lsi.total_lst_supply();
    let lst_decrease = lst_post < lst_pre;

    let decreased = lst_decrease;

    cvlm_assert(!decreased || can_decrease_supply(target));
}

public fun only_minting_increases_lst_supply(
    target: Function,
    lsi: &mut LiquidStakingInfo<DummyToken>,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    setup_fresh(lsi, system_state, ctx);

    let lst_pre = lsi.total_lst_supply();

    invoke(target, lsi, system_state, ctx);

    let lst_post = lsi.total_lst_supply();
    
    let lst_increase = lst_post > lst_pre;

    let increased = lst_increase;

    cvlm_assert(!increased || can_increase_supply(target));
}

public fun only_minting_increases_sui_supply(
    target: Function,
    lsi: &mut LiquidStakingInfo<DummyToken>,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    setup_fresh(lsi, system_state, ctx);

    let sui_pre = lsi.total_sui_supply();

    
    invoke(target, lsi, system_state, ctx);

    let sui_post = lsi.total_sui_supply();

    let sui_increase = sui_post > sui_pre;
    

    let increased = sui_increase;

    cvlm_assert(!increased || can_increase_supply(target));
}
