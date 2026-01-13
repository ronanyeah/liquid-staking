module spec::common;

use liquid_staking::liquid_staking::LiquidStakingInfo;
use sui_system::sui_system::SuiSystemState;
use cvlm::asserts::cvlm_assume_msg;


public fun setup_fresh<T>(
    lsi: &mut LiquidStakingInfo<T>,
    system_state: &mut SuiSystemState,
    ctx: &mut TxContext,
) {
    cvlm_assume_msg(ctx.epoch() > lsi.storage().last_refresh_epoch(), b"Force refresh");

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

public fun log<T>(_: &T) {}