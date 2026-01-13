module spec::accounting_value_conservation;

use cvlm::asserts::{cvlm_assert, cvlm_assume_msg};
use cvlm::function::Function;
use cvlm::ghost::ghost_destroy;
use cvlm::manifest::{target, invoker, rule};
use cvlm::nondet::nondet;
use liquid_staking::liquid_staking::LiquidStakingInfo;
use spec::accounting_total_sui_supply::total_supply_correct;
use spec::common::{setup_fresh, log, can_decrease_supply};
use spec::dummy::DummyToken;
use sui::coin::Coin;
use sui::sui::SUI;
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

    rule(b"sui_value_conservation");
    rule(b"lst_value_conservation");

    rule(b"deposit_value_conservation");
    rule(b"redeem_value_conservation");
}

native fun invoke(
    target: Function,
    lsi: &mut LiquidStakingInfo<DummyToken>,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
);

public fun sui_value_conservation(
    target: Function,
    lsi: &mut LiquidStakingInfo<DummyToken>,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    setup_fresh(lsi, system_state, ctx);
    let sui_pre = lsi.total_sui_supply();

    cvlm_assume_msg(!can_decrease_supply(target), b"Cannot decrease sui supply");
    cvlm_assume_msg(total_supply_correct(lsi.storage()), b"Sound state");
    invoke(target, lsi, system_state, ctx);

    let sui_post = lsi.total_sui_supply();

    cvlm_assert(sui_post >= sui_pre);
}

public fun lst_value_conservation(
    target: Function,
    lsi: &mut LiquidStakingInfo<DummyToken>,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    setup_fresh(lsi, system_state, ctx);
    let lst_pre = lsi.total_lst_supply();
    cvlm_assume_msg(!can_decrease_supply(target), b"Cannot decrease sui supply");
    invoke(target, lsi, system_state, ctx);

    let lst_post = lsi.total_lst_supply();

    cvlm_assert(lst_post >= lst_pre);
}

public fun deposit_value_conservation(
    lsi: &mut LiquidStakingInfo<DummyToken>,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    setup_fresh(lsi, system_state, ctx);
    cvlm_assume_msg(total_supply_correct(lsi.storage()), b"Sound state");

    let sui: Coin<SUI> = nondet();
    let sui_value = sui.value();
    let fees_pre = lsi.fees();
    let sui_pre = lsi.total_sui_supply();
    let lst = lsi.mint(system_state, sui, ctx);

    cvlm_assert(lsi.total_sui_supply() >= sui_pre);
    cvlm_assert(lsi.fees() >= fees_pre);
    let sui_increase = lsi.total_sui_supply() - sui_pre;
    let fee_increase = lsi.fees() - fees_pre;

    cvlm_assert(sui_increase + fee_increase == sui_value);

    ghost_destroy(lst);
}

public fun redeem_value_conservation(
    lsi: &mut LiquidStakingInfo<DummyToken>,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    setup_fresh(lsi, system_state, ctx);
    cvlm_assume_msg(total_supply_correct(lsi.storage()), b"Sound state");

    let lst: Coin<DummyToken> = nondet();

    let fees_pre = lsi.fees();
    let sui_pre = lsi.total_sui_supply();

    let sui = lsi.redeem(lst, system_state, ctx);

    cvlm_assert(lsi.total_sui_supply() <= sui_pre);
    cvlm_assert(lsi.fees() >= fees_pre);

    let sui_decrease = sui_pre - lsi.total_sui_supply();
    let fee_increase = lsi.fees() - fees_pre;

    log(&fee_increase);
    log(&sui.value());
    log(&(fee_increase + sui.value()));
    log(&sui_decrease);
    cvlm_assert(fee_increase + sui.value() == sui_decrease);

    ghost_destroy(sui);
}
