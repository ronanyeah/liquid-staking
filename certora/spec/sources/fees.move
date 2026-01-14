module spec::fees;

use cvlm::asserts::{cvlm_assert, cvlm_assume_msg};
use cvlm::function::Function;
use cvlm::ghost::ghost_destroy;
use cvlm::manifest::{rule, target};
use cvlm::nondet::nondet;
use liquid_staking::fees::validate_fees;
use liquid_staking::liquid_staking::LiquidStakingInfo;
use spec::common::setup_fresh;
use spec::dummy::DummyToken;
use sui::coin::Coin;
use sui::sui::SUI;
use sui_system::sui_system::SuiSystemState;
use cvlm::manifest::invoker;

public fun cvlm_manifest() {
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

    rule(b"fees_grow_monotonically");
    rule(b"fees_dont_eat_deposit");
    rule(b"fees_dont_eat_redemption");
}

native fun invoke(
    target: Function,
    lsi: &mut LiquidStakingInfo<DummyToken>,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
);


public fun fees_grow_monotonically(
    target: Function,
    lsi: &mut LiquidStakingInfo<DummyToken>,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
  setup_fresh(lsi, system_state, ctx);
  validate_fees(lsi.fee_config());
  let spread_fees_pre = lsi.fees();

  invoke(target, lsi, system_state, ctx);

  let spread_fees_post = lsi.fees();

  let collected = target.name() == b"collect_fees";
  let increased = spread_fees_post >= spread_fees_pre;

  // !collected -> increased <==> collected || increased
  cvlm_assert(collected || increased);
}


public fun fees_dont_eat_redemption(
    lsi: &mut LiquidStakingInfo<DummyToken>,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    setup_fresh(lsi, system_state, ctx);
    validate_fees(lsi.fee_config());

    let coin: Coin<DummyToken> = nondet();

    let fees_pre = lsi.fees();

    cvlm_assume_msg(coin.value() > 0, b"Non-zero value");
    let sui = lsi.redeem(coin, system_state, ctx);

    let fees = lsi.fees() - fees_pre;

    cvlm_assume_msg(sui.value() + fees > 0, b"No lost funds");
    cvlm_assert(sui.value() > 0);
    ghost_destroy(sui);
}

public fun fees_dont_eat_deposit(
    lsi: &mut LiquidStakingInfo<DummyToken>,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    setup_fresh(lsi, system_state, ctx);
    validate_fees(lsi.fee_config());

    let coin: Coin<SUI> = nondet();

    let fees_pre = lsi.fees();

    cvlm_assume_msg(coin.value() > 0, b"Non-zero value");
    let lst = lsi.mint(system_state, coin, ctx);
    let fees = lsi.fees() - fees_pre;

    cvlm_assume_msg(lst.value()+fees > 0, b"No lost funds");
    cvlm_assert(lst.value() > 0);
    ghost_destroy(lst);
}
