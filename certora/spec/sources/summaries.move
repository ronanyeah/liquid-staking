module spec::summaries;

use cvlm::manifest::summary;
use liquid_staking::storage::Storage;
use sui_system::staking_pool::PoolTokenExchangeRate;
use sui_system::sui_system::SuiSystemState;
use cvlm::nondet::nondet;
use std::option::some;
use cvlm::asserts::cvlm_assume_msg;
use cvlm::manifest::ghost;
use sui_system::validator::staking_pool_id;
use sui_system::staking_pool::StakedSui;
use sui::balance::Balance;
use sui::sui::SUI;
use sui::kiosk::withdraw;
use cvlm::ghost::ghost_destroy;
use cvlm::asserts::cvlm_assert_msg;
use sui::token::amount;
use liquid_staking::storage;
use liquid_staking::storage::get_sui_amount;
use sui_system::staking_pool::FungibleStakedSui;

public fun cvlm_manifest() {

    ghost(b"exchange_rate");
    summary(b"get_latest_exchange_rate", @liquid_staking, b"storage", b"get_latest_exchange_rate");

    summary(b"active_validator_addresses", @sui_system, b"sui_system", b"active_validator_addresses");
    summary(b"request_withdraw_stake_non_entry", @sui_system, b"sui_system", b"request_withdraw_stake_non_entry");
}

native fun exchange_rate(epoch: u64, staking_pool_id: &ID): PoolTokenExchangeRate;

fun get_exr(epoch: u64, staking_pool_id: &ID): PoolTokenExchangeRate {
  let er: PoolTokenExchangeRate = exchange_rate(epoch, staking_pool_id);
  cvlm_assume_msg(er.sui_amount() > er.pool_token_amount(), b"solvent");
  er
}



fun get_latest_exchange_rate(
    _self: &Storage,
    staking_pool_id: &ID,
    _system_state: &mut SuiSystemState,
    ctx: &TxContext,
): Option<PoolTokenExchangeRate> {

  some(get_exr(ctx.epoch(), staking_pool_id))
}


public fun active_validator_addresses(_wrapper: &mut SuiSystemState): vector<address> {
    nondet()
}

public fun request_withdraw_stake_non_entry(
    _wrapper: &mut SuiSystemState,
    staked_sui: StakedSui,
    ctx: &mut TxContext,
): Balance<SUI> {
    
    let exr =  get_exr(ctx.epoch(), &staked_sui.pool_id());
    let am = storage::get_sui_amount(&exr, staked_sui.amount());

    let w: Balance<SUI>  = nondet();
    cvlm_assume_msg(w.value() == am, b"Exchange");
    ghost_destroy(staked_sui);
    w
}
