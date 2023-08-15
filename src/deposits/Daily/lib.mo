import Buffer "mo:base/Buffer";
import Error "mo:base/Error";
import Int "mo:base/Int";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Time "mo:base/Time";

import Neurons "../Neurons";
import PendingTransfers "../PendingTransfers";
import Referrals "../Referrals";
import Staking "../Staking";
import Withdrawals "../Withdrawals";
import Ledger "../../nns-ledger";
import Metrics "../../metrics/types";
import Token "../../DIP20/motoko/src/token";
import Account "../../DIP20/motoko/src/account";

import ApplyInterest "./ApplyInterest";
import FlushPendingDeposits "./FlushPendingDeposits";
import SplitNewWithdrawalNeurons "./SplitNewWithdrawalNeurons";

module {
    public type UpgradeData = {
        #v1: {
            applyInterestJob: ?ApplyInterest.UpgradeData;
            applyInterestResult: ?ApplyInterest.ApplyInterestResult;
            flushPendingDepositsResult: ?FlushPendingDeposits.FlushPendingDepositsResult;
            splitNewWithdrawalNeuronsResult: ?SplitNewWithdrawalNeurons.SplitNewWithdrawalNeuronsResultV1;
        };
        #v2: {
            applyInterestJob: ?ApplyInterest.UpgradeData;
            applyInterestResult: ?ApplyInterest.ApplyInterestResult;
            flushPendingDepositsResult: ?FlushPendingDeposits.FlushPendingDepositsResult;
            splitNewWithdrawalNeuronsResult: ?SplitNewWithdrawalNeurons.SplitNewWithdrawalNeuronsResult;
        };
    };

    public type DailyResult = (?ApplyInterest.ApplyInterestResult, ?FlushPendingDeposits.FlushPendingDepositsResult, ?SplitNewWithdrawalNeurons.SplitNewWithdrawalNeuronsResult);

    // Job is the state machine that manages the daily
    // merging/splitting/interest.
    public class Job(args: {
        ledger: Ledger.Self;
        neurons: Neurons.Manager;
        referralTracker: Referrals.Tracker;
        staking: Staking.Manager;
        token: Token.Token;
        pendingTransfers: PendingTransfers.Tracker;
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
            pendingTransfers = args.pendingTransfers;
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

        public func setInitialSnapshot(): async (Text, [(Account.Account, Nat)]) {
            await applyInterestJob.setInitialSnapshot()
        };

        public func getAppliedInterest(): [ApplyInterest.ApplyInterestSummary] {
            return applyInterestJob.getAppliedInterest();
        };

        public func getAppliedInterestMerges(): [[(Nat64, Nat64, Neurons.NeuronResult)]] {
            return applyInterestJob.getMerges();
        };


        public func setAppliedInterest(elems: [ApplyInterest.ApplyInterestSummary]) {
            applyInterestJob.setAppliedInterest(elems);
        };

        public func getMeanAprMicrobips() : Nat64 {
            return applyInterestJob.getMeanAprMicrobips();
        };

        public func getTotalMaturity() : Nat64 {
            return applyInterestJob.getTotalMaturity();
        };

        public func setTotalMaturity(v: Nat64) {
            applyInterestJob.setTotalMaturity(v);
        };

        public func getResults(): DailyResult {
            (applyInterestResult, flushPendingDepositsResult, splitNewWithdrawalNeuronsResult)
        };

        public func flushPendingDeposits(
            refreshAvailableBalance: FlushPendingDeposits.RefreshAvailableBalanceFn
        ): async ?FlushPendingDeposits.FlushPendingDepositsResult {
            flushPendingDepositsResult := null;
            let flush = try {
                await flushPendingDepositsJob.run(refreshAvailableBalance)
            } catch (error) {
                #err(#Other(Error.message(error)))
            };
            flushPendingDepositsResult := ?flush;
            flushPendingDepositsResult
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
            let lastHeartbeatAt: ?Int = switch (applyInterestResult) {
                case (?#ok(a)) { ?a.timestamp };
                case (_) { null };
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
            switch (lastHeartbeatAt) {
                case (null) {};
                case (?last) {
                    ms.add({
                        name = "last_heartbeat_at";
                        t = "gauge";
                        help = ?"nanosecond timestamp of the last time heartbeat ran";
                        labels = [];
                        value = Int.toText(last);
                    });
                };
            };

            ms.toArray()
        };

        // ===== JOB START FUNCTION =====

        public func run(
            now: Time.Time,
            root: Account.Account,
            queueMint: ApplyInterest.QueueMintFn,
            refreshAvailableBalance: FlushPendingDeposits.RefreshAvailableBalanceFn
        ) : async DailyResult {
            applyInterestResult := null;
            flushPendingDepositsResult := null;
            splitNewWithdrawalNeuronsResult := null;

            let apply = try {
                await applyInterestJob.run(now, root, queueMint, refreshAvailableBalance)
            } catch (error) {
                #err(#Other(Error.message(error)))
            };
            applyInterestResult := ?apply;

            let flush = try {
                await flushPendingDepositsJob.run(refreshAvailableBalance)
            } catch (error) {
                #err(#Other(Error.message(error)))
            };
            flushPendingDepositsResult := ?flush;

            let split = try {
                await splitNewWithdrawalNeuronsJob.run()
            } catch (error) {
                #err(#Other(Error.message(error)))
            };
            splitNewWithdrawalNeuronsResult := ?split;

            (?apply, ?flush, ?split)
        };

        // ===== UPGRADE FUNCTIONS =====

        public func preupgrade() : ?UpgradeData {
            return ?#v2({
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
                    postupgrade(?#v2({
                        applyInterestJob = data.applyInterestJob;
                        applyInterestResult = data.applyInterestResult;
                        flushPendingDepositsResult = data.flushPendingDepositsResult;
                        splitNewWithdrawalNeuronsResult = SplitNewWithdrawalNeurons.upgradeResultV1(
                            data.splitNewWithdrawalNeuronsResult
                        );
                    }));
                };
                case (?#v2(data)) {
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
