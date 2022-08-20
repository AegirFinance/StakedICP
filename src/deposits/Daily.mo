import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Time "mo:base/Time";

import Neurons "./Neurons";
import Referrals "./Referrals";
import Staking "./Staking";
import Withdrawals "./Withdrawals";
import Ledger "../ledger/Ledger";
import Token "../DIP20/motoko/src/token";

import ApplyInterest "./daily/ApplyInterest";
import FlushPendingDeposits "./daily/FlushPendingDeposits";
import SplitNewWithdrawalNeurons "./daily/SplitNewWithdrawalNeurons";

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

        // ===== JOB START FUNCTION =====

        public func start(
            now: Time.Time,
            root: Principal,
            queueMint: ApplyInterest.QueueMintFn,
            availableBalance: FlushPendingDeposits.AvailableBalanceFn,
            refreshAvailableBalance: FlushPendingDeposits.RefreshAvailableBalanceFn
        ) : async () {
            applyInterestResult := null;
            flushPendingDepositsResult := null;
            splitNewWithdrawalNeuronsResult := null;

            // Can run these in "parallel"
            ignore applyInterest(now, root, queueMint);
            ignore flushPendingDeposits(availableBalance, refreshAvailableBalance);
        };

        // If we're done with the apply/flush/merge, move onto the split
        private func splitIfReady(): async () {
            if (applyInterestResult == null) { return; };
            if (flushPendingDepositsResult == null) { return; };

            ignore splitNewWithdrawalNeurons();
        };

        // Merge the interest
        private func applyInterest(now: Time.Time, root: Principal, queueMint: ApplyInterest.QueueMintFn) : async () {
            applyInterestResult := ?(await applyInterestJob.start(now, root, queueMint));
            ignore splitIfReady();
        };

        // Flush pending deposits
        private func flushPendingDeposits(
            availableBalance: FlushPendingDeposits.AvailableBalanceFn,
            refreshAvailableBalance: FlushPendingDeposits.RefreshAvailableBalanceFn
        ) : async () {
            flushPendingDepositsResult := ?(await flushPendingDepositsJob.start(availableBalance, refreshAvailableBalance));
            ignore splitIfReady();
        };

        // Split off as many staking neurons as we need to ensure withdrawals
        // will be satisfied.
        //
        // Note: This needs to happen *after* everything above, hence the awaits.
        private func splitNewWithdrawalNeurons() : async () {
            splitNewWithdrawalNeuronsResult := ?(await splitNewWithdrawalNeuronsJob.start());
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
