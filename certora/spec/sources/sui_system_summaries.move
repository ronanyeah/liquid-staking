module spec::sui_system_summaries;

use cvlm::manifest::{ summary, ghost };
use sui_system::sui_system::SuiSystemState;
use sui_system::sui_system_state_inner::SuiSystemStateInnerV2;
use sui_system::staking_pool::PoolTokenExchangeRate;

public fun cvlm_manifest() {
    summary(b"get_sui_amount", @sui_system, b"staking_pool", b"get_sui_amount");
    ghost(b"get_sui_amount");

    summary(b"get_token_amount", @sui_system, b"staking_pool", b"get_token_amount");
    ghost(b"get_token_amount");

    summary(
        b"calculate_fungible_staked_sui_withdraw_amount", 
        @sui_system, 
        b"staking_pool", 
        b"calculate_fungible_staked_sui_withdraw_amount"
    );
    ghost(b"calculate_fungible_staked_sui_withdraw_amount_principal");
    ghost(b"calculate_fungible_staked_sui_withdraw_amount_rewards");
}

public native fun get_sui_amount(exchange_rate: &PoolTokenExchangeRate, token_amount: u64): u64;
public native fun get_token_amount(exchange_rate: &PoolTokenExchangeRate, sui_amount: u64): u64;


public fun calculate_fungible_staked_sui_withdraw_amount(
    latest_exchange_rate: PoolTokenExchangeRate,
    fungible_staked_sui_value: u64,
    fungible_staked_sui_data_principal_amount: u64,
    fungible_staked_sui_data_total_supply: u64,
): (u64, u64) {
    (
        calculate_fungible_staked_sui_withdraw_amount_principal(
            latest_exchange_rate,
            fungible_staked_sui_value,
            fungible_staked_sui_data_principal_amount,
            fungible_staked_sui_data_total_supply,
        ),
        calculate_fungible_staked_sui_withdraw_amount_rewards(
            latest_exchange_rate,
            fungible_staked_sui_value,
            fungible_staked_sui_data_principal_amount,
            fungible_staked_sui_data_total_supply,
        ),
    )
}

native fun calculate_fungible_staked_sui_withdraw_amount_principal(
    latest_exchange_rate: PoolTokenExchangeRate,
    fungible_staked_sui_value: u64,
    fungible_staked_sui_data_principal_amount: u64,
    fungible_staked_sui_data_total_supply: u64,
): u64;

native fun calculate_fungible_staked_sui_withdraw_amount_rewards(
    latest_exchange_rate: PoolTokenExchangeRate,
    fungible_staked_sui_value: u64,
    fungible_staked_sui_data_principal_amount: u64,
    fungible_staked_sui_data_total_supply: u64,
): u64;