import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Time "mo:base/Time";

import Neurons "../Neurons";
import Referrals "../Referrals";
import Staking "../Staking";
import Withdrawals "../Withdrawals";
import Ledger "../../ledger/Ledger";
import Token "../../DIP20/motoko/src/token";

import ApplyInterest "./ApplyInterest";
import FlushPendingDeposits "./FlushPendingDeposits";
import SplitNewWithdrawalNeurons "./SplitNewWithdrawalNeurons";

module {
    public type UpgradeData = {
        #v1: {
            applyInterestJob: ?ApplyInterest.UpgradeData;
            applyInterestResult: ?ApplyInterest.ApplyInterestResult;
            flushPendingDepositsResult: ?FlushPendingDeposits.FlushPendingDepositsResult;
            splitNewWithdrawalNeuronsResult: ?SplitNewWithdrawalNeurons.SplitNewWithdrawalNeuronsResult;
        };
    };

    public type Metrics = {
        lastHeartbeatOk: Bool;
        lastHeartbeatInterestApplied: Nat64;
    };

    // Job is the state machine that manages the daily
    // merging/splitting/interest.
    public class Job(args: {
        ledger: Ledger.Self;
        neurons: Neurons.Manager;
        referralTracker: Referrals.Tracker;
        staking: Staking.Manager;
        token: Token.Token;
        withdrawals: Withdrawals.Manager;
    }) {

        private var applyInterestJob = ApplyInterest.Job({
            neurons = args.neurons;
            referralTracker = args.referralTracker;
            staking = args.staking;
            token = args.token;
        });

        private var flushPendingDepositsJob = FlushPendingDeposits.Job({
            ledger = args.ledger;
            neurons = args.neurons;
            staking = args.staking;
            token = args.token;
            withdrawals = args.withdrawals;
        });

        private var splitNewWithdrawalNeuronsJob = SplitNewWithdrawalNeurons.Job({
            neurons = args.neurons;
            staking = args.staking;
            withdrawals = args.withdrawals;
        });

        private var applyInterestResult: ?ApplyInterest.ApplyInterestResult = null;
        private var flushPendingDepositsResult: ?FlushPendingDeposits.FlushPendingDepositsResult = null;
        private var splitNewWithdrawalNeuronsResult: ?SplitNewWithdrawalNeurons.SplitNewWithdrawalNeuronsResult = null;

        // ===== GETTER/SETTER FUNCTIONS =====

        public func setInitialSnapshot(): async (Text, [(Principal, Nat)]) {
            await applyInterestJob.setInitialSnapshot()
        };

        // ===== METRICS FUNCTIONS =====

        public func metrics(): Metrics {
            let lastHeartbeatOk = switch (applyInterestResult, flushPendingDepositsResult, splitNewWithdrawalNeuronsResult) {
                // Something failed
                case (?#err(_),        _,        _) { false };
                // flush cannot fail, so no need to check it.
                case (       _,        _, ?#err(_)) { false };
                // Still running, or all good
                case (       _,        _,        _) { true };
            };
            let lastHeartbeatInterestApplied: Nat64 = switch (applyInterestResult) {
                case (?#ok(a)) {
                    a.applied.e8s + a.remainder.e8s + Nat64.fromNat(a.affiliatePayouts)
                };
                case (_) { 0 };
            };
            return {
                lastHeartbeatOk = lastHeartbeatOk;
                lastHeartbeatInterestApplied = lastHeartbeatInterestApplied;
            };
        };

        // ===== JOB START FUNCTION =====

        public func start(
            now: Time.Time,
            root: Principal,
            queueMint: ApplyInterest.QueueMintFn,
            availableBalance: FlushPendingDeposits.AvailableBalanceFn,
            refreshAvailableBalance: FlushPendingDeposits.RefreshAvailableBalanceFn
        ) : async (ApplyInterest.ApplyInterestResult, FlushPendingDeposits.FlushPendingDepositsResult, SplitNewWithdrawalNeurons.SplitNewWithdrawalNeuronsResult) {
            applyInterestResult := null;
            flushPendingDepositsResult := null;
            splitNewWithdrawalNeuronsResult := null;

            let apply = await applyInterestJob.start(now, root, queueMint);
            applyInterestResult := ?apply;

            let flush = await flushPendingDepositsJob.start(availableBalance, refreshAvailableBalance);
            flushPendingDepositsResult := ?flush;

            let split = await splitNewWithdrawalNeuronsJob.start();
            splitNewWithdrawalNeuronsResult := ?split;

            (apply, flush, split)
        };

        // ===== UPGRADE FUNCTIONS =====

        public func preupgrade() : ?UpgradeData {
            return ?#v1({
                applyInterestJob = applyInterestJob.preupgrade();
                applyInterestResult = applyInterestResult;
                flushPendingDepositsResult = flushPendingDepositsResult;
                splitNewWithdrawalNeuronsResult = splitNewWithdrawalNeuronsResult;
            });
        };

        public func postupgrade(upgradeData : ?UpgradeData) {
            switch (upgradeData) {
                case (?#v1(data)) {
                    applyInterestJob.postupgrade(data.applyInterestJob);
                    applyInterestResult := data.applyInterestResult;
                    flushPendingDepositsResult := data.flushPendingDepositsResult;
                    splitNewWithdrawalNeuronsResult := data.splitNewWithdrawalNeuronsResult;
                };
                case (_) { return; }
            };
        };
    };
};
