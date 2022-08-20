import Buffer "mo:base/Buffer";
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
import Metrics "../../metrics/types";
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

        // Sub-steps
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

        // Sub-step results
        private var applyInterestResult: ?ApplyInterest.ApplyInterestResult = null;
        private var flushPendingDepositsResult: ?FlushPendingDeposits.FlushPendingDepositsResult = null;
        private var splitNewWithdrawalNeuronsResult: ?SplitNewWithdrawalNeurons.SplitNewWithdrawalNeuronsResult = null;

        // ===== GETTER/SETTER FUNCTIONS =====

        public func setInitialSnapshot(): async (Text, [(Principal, Nat)]) {
            await applyInterestJob.setInitialSnapshot()
        };

        // ===== METRICS FUNCTIONS =====

        public func metrics(): [Metrics.Metric] {
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

            let ms = Buffer.Buffer<Metrics.Metric>(2);
            ms.add({
                name = "last_heartbeat_ok";
                t = "gauge";
                help = ?"0 if the last heartbeat run was successful";
                labels = [];
                value = if lastHeartbeatOk { "0" } else { "1" };
            });
            ms.add({
                name = "last_heartbeat_interest_applied";
                t = "gauge";
                help = ?"e8s of interest applied at the last heartbeat";
                labels = [];
                value = Nat64.toText(lastHeartbeatInterestApplied);
            });
            ms.toArray()
        };

        // ===== JOB START FUNCTION =====

        public func run(
            now: Time.Time,
            root: Principal,
            queueMint: ApplyInterest.QueueMintFn,
            availableBalance: FlushPendingDeposits.AvailableBalanceFn,
            refreshAvailableBalance: FlushPendingDeposits.RefreshAvailableBalanceFn
        ) : async (ApplyInterest.ApplyInterestResult, FlushPendingDeposits.FlushPendingDepositsResult, SplitNewWithdrawalNeurons.SplitNewWithdrawalNeuronsResult) {
            applyInterestResult := null;
            flushPendingDepositsResult := null;
            splitNewWithdrawalNeuronsResult := null;

            let apply = await applyInterestJob.run(now, root, queueMint);
            applyInterestResult := ?apply;

            let flush = await flushPendingDepositsJob.run(availableBalance, refreshAvailableBalance);
            flushPendingDepositsResult := ?flush;

            let split = await splitNewWithdrawalNeuronsJob.run();
            splitNewWithdrawalNeuronsResult := ?split;

            (apply, flush, split)
        };

        // ===== UPGRADE FUNCTIONS =====

        public func preupgrade() : ?UpgradeData {
            return ?#v1({
                // Only ApplyInterestJob has any upgrade state
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