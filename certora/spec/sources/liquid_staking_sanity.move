module spec::liquid_staking_sanity;

use cvlm::manifest::{ target, target_sanity };

public fun cvlm_manifest() {
    target(@liquid_staking, b"liquid_staking", b"create_lst");
    target(@liquid_staking, b"liquid_staking", b"create_lst_with_stake");
    target(@liquid_staking, b"liquid_staking", b"mint");
    target(@liquid_staking, b"liquid_staking", b"redeem");
    target(@liquid_staking, b"liquid_staking", b"custom_redeem_request");
    target(@liquid_staking, b"liquid_staking", b"custom_redeem");
    target(@liquid_staking, b"liquid_staking", b"change_validator_priority");
    target(@liquid_staking, b"liquid_staking", b"increase_validator_stake");
    target(@liquid_staking, b"liquid_staking", b"decrease_validator_stake");
    target(@liquid_staking, b"liquid_staking", b"collect_fees");
    target(@liquid_staking, b"liquid_staking", b"update_fees");
    target(@liquid_staking, b"liquid_staking", b"refresh");
    target(@liquid_staking, b"liquid_staking", b"update_metadata");
    target_sanity();
}