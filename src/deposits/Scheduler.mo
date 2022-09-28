import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Error "mo:base/Error";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Option "mo:base/Option";
import P "mo:base/Prelude";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import TrieMap "mo:base/TrieMap";

import Metrics "../metrics/types";

module {
    public type UpgradeData = {
        #v1: {
            lastJobResults: [(Text, JobResult)];
        };
    };

    public type JobMetrics = {
        startedAt: Time.Time;
        completedAt: ?Time.Time;
        ok: Bool;
    };

    public type Job = {
        name : Text;
        interval : Int;
        function : (now: Time.Time) -> async Result.Result<Any, Text>;
    };

    public type JobResult = {
        startedAt : Time.Time;
        completedAt : ?Time.Time;
        result : ?Result.Result<Any, Text>;
    };

    // Scheduler manages regularly performed background jobs at a regular
    // interval. Jobs are scheduled to run "concurrently" (using "ignore"), but
    // if a job is already running, the scheduler will wait for it to finish
    // before starting it again.
    public class Scheduler() {
        // Makes date math simpler
        let second : Int = 1_000_000_000;
        let minute : Int = 60 * second;
        let hour : Int = 60 * minute;
        let day : Int = 24 * hour;

        let defaultJobResult : JobResult = {
            startedAt = 0;
            completedAt = null;
            result = null;
        };

        private var lastJobResults = TrieMap.TrieMap<Text, JobResult>(Text.equal, Text.hash);

        // ===== METRICS FUNCTIONS =====

        // Expose metrics to track canister performance, and behaviour. These are
        // ingested and served by the "metrics" canister.
        public func metrics() : [Metrics.Metric] {
            let ms = Buffer.Buffer<Metrics.Metric>(lastJobResults.size());
            for ((name, {startedAt; completedAt; result}) in lastJobResults.entries()) {
                ms.add({
                    name = "scheduler_job_started_at";
                    t = "gauge";
                    help = ?"nanosecond timestamp of the last time the job started";
                    labels = [("job", name)];
                    value = Int.toText(startedAt);
                });
                switch (completedAt) {
                    case (null) {};
                    case (?completedAt) {
                        ms.add({
                            name = "scheduler_job_completed_at";
                            t = "gauge";
                            help = ?"nanosecond timestamp of the last time the job completed";
                            labels = [("job", name)];
                            value = Int.toText(completedAt);
                        });
                    };
                };
                switch (result) {
                    case (null) {};
                    case (?#ok(_)) {
                        ms.add({
                            name = "scheduler_job_ok";
                            t = "gauge";
                            help = ?"0 if the job was successful";
                            labels = [("job", name)];
                            value = "0";
                        });
                    };
                    case (?#err(_)) {
                        ms.add({
                            name = "scheduler_job_ok";
                            t = "gauge";
                            help = ?"0 if the job was successful";
                            labels = [("job", name)];
                            value = "1";
                        });
                    };
                };
            };
            ms.toArray()
        };

        // ===== GETTER/SETTER FUNCTIONS =====

        // For manual recovery, in case of an issue with the most recent heartbeat.
        public func getLastJobResult(name: Text): ?JobResult {
            lastJobResults.get(name)
        };

        // For manual recovery, in case of an issue with the most recent heartbeat.
        public func setLastJobResult(name: Text, r: JobResult): () {
            lastJobResults.put(name, r);
        };

        // ===== HEARTBEAT FUNCTIONS =====

        // Try to run all scheduled jobs. This should be called in the
        // heartbeat function of the importing canister. Most of the time it
        // will be a no-op.
        //
        // NOTE: This must be atomic, so it is safe to run concurrently.
        // Heartbeat system functions can be called in very quick succession.
        // Hence, all actual jobs are started with "ignore" instead of "await",
        // so they do not yield.
        public func heartbeat(now: Time.Time, jobs: [Job]) : async () {
            let jobsToRun = Array.filter(jobs, func({name; interval}: Job): Bool {
                switch (lastJobResults.get(name)) {
                    case (?{startedAt; completedAt}) {
                        if (completedAt == null) {
                            // Currently running
                            return false;
                        };
                        let next = startedAt + interval;
                        if (now < next) {
                            // Not scheduled yet
                            return false;
                        };
                    };
                    case (_) { };
                };
                return true;
            });

            // Set all jobs as "currently running", to lock out other calls to this, which might overlap
            for ({name} in jobsToRun.vals()) {
                lastJobResults.put(name, {
                    startedAt = now;
                    completedAt = null;
                    result = null;
                });
            };

            // Start all jobs
            for (j in jobsToRun.vals()) {
                ignore runJob(j, now)
            };
        };

        // Asynchronously run a job and store the result
        func runJob({name; interval; function}: Job, now: Time.Time): async () {
            try {
                let result = await function(now);
                lastJobResults.put(name, {
                    startedAt = now;
                    completedAt = ?Time.now();
                    result = ?result;
                });
            } catch (error) {
                lastJobResults.put(name, {
                    startedAt = now;
                    completedAt = ?Time.now();
                    result = ?#err(Error.message(error));
                });
            };
        };

        // ===== UPGRADE FUNCTIONS =====

        public func preupgrade() : ?UpgradeData {
            return ?#v1({
                lastJobResults = Iter.toArray(lastJobResults.entries());
            });
        };

        public func postupgrade(upgradeData : ?UpgradeData) {
            switch (upgradeData) {
                case (?#v1(data)) {
                    lastJobResults := TrieMap.fromEntries(
                        data.lastJobResults.vals(),
                        Text.equal,
                        Text.hash
                    );
                };
                case (_) { return; }
            };
        };
    };
};
