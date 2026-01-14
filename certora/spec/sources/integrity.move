module spec::integrity;

use cvlm::asserts::{cvlm_assert, cvlm_assume_msg};
use cvlm::ghost::ghost_destroy;
use cvlm::manifest::rule;
use cvlm::nondet::nondet;
use liquid_staking::fees::validate_fees;
use liquid_staking::liquid_staking::{LiquidStakingInfo};
use spec::dummy::DummyToken;
use sui_system::sui_system::SuiSystemState;
use spec::common::setup_fresh;
use sui::coin::Coin;

use sui::sui::SUI;


public fun cvlm_manifest() {
    rule(b"no_lost_funds_on_redeem");
    rule(b"no_lost_funds_on_mint");
    rule(b"fees_dont_eat_deposit");
    rule(b"fees_dont_eat_redemption");
    rule(b"no_arbitrage_opportunity");
}

public fun no_lost_funds_on_redeem(
    lsi: &mut LiquidStakingInfo<DummyToken>,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    setup_fresh(lsi, system_state, ctx);

    // Solvency is sufficient to make the rule pass.
    // However, since the system is not solvent at all times, it is not safe to assume it here.
    //cvlm_assume_msg(is_solvent(lsi), b"Solvency");

    let coin: Coin<DummyToken> = nondet();

    let fees_pre = lsi.fees();
    
    cvlm_assume_msg(coin.value() > 0, b"Non-zero value");
    let sui = lsi.redeem(coin, system_state, ctx);

    let fees = lsi.fees() - fees_pre;

    cvlm_assert(sui.value() + fees > 0);
    ghost_destroy(sui);
}



public fun no_lost_funds_on_mint(
    lsi: &mut LiquidStakingInfo<DummyToken>,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    setup_fresh(lsi, system_state, ctx);

    let coin: Coin<SUI> = nondet();

    let fees_pre = lsi.fees();
    
    cvlm_assume_msg(coin.value() > 0, b"Non-zero value");
    let lst = lsi.mint(system_state, coin, ctx);
    let fees = lsi.fees() - fees_pre;

    cvlm_assert(lst.value()+fees > 0);
    ghost_destroy(lst);
}





public fun no_arbitrage_opportunity(
    lsi: &mut LiquidStakingInfo<DummyToken>,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    setup_fresh(lsi, system_state, ctx);
    validate_fees(lsi.fee_config());
    
    // The rule fails if we have 0 LST but non-zero SUI supply
    // This state, however, should not be possible to reach (check rule `no_lst_no_sui` in `solvency.move`)
    cvlm_assume_msg(lsi.total_lst_supply() != 0 || lsi.total_sui_supply() == 0, b"No LST means no SUI supply");

    let sui_in: Coin<SUI> = nondet();
    let sui_in_value = sui_in.value();

    let lst = lsi.mint(system_state, sui_in, ctx);
    let sui_out = lsi.redeem(lst, system_state, ctx);

    cvlm_assert(sui_out.value() <= sui_in_value);
    ghost_destroy(sui_out);
}
