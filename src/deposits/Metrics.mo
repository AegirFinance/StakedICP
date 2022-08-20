import Neurons "./Neurons";
import Referrals "./Referrals";
import Scheduler "./Scheduler";
import Staking "./Staking";
import Withdrawals "./Withdrawals";

module {
    public type Metrics = {
        aprMicrobips: Nat64;
        balances: [(Text, Nat64)];
        pendingMintsE8s: Nat64;
        pendingMintsCount: Nat;
        neurons: Neurons.Metrics;
        referrals: Referrals.Metrics;
        scheduler: Scheduler.Metrics;
        staking: Staking.Metrics;
        withdrawals: Withdrawals.Metrics;
    };
};
