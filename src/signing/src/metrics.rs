use ic_cdk::{
    api::management_canister::main::{canister_status, CanisterIdRecord},
    export::{candid::CandidType, serde::Deserialize},
};
use num_bigint::BigUint;

#[derive(CandidType, Deserialize)]
pub struct Metric {
    help: Option<String>,
    labels: Vec<(String, String)>,
    name: String,
    t: String,
    value: String,
}

pub async fn metrics() -> Vec<Metric> {
    let response = canister_status(CanisterIdRecord {
        canister_id: ic_cdk::api::id(),
    })
    .await
    .map_err(|e| format!("canister_status failed {}", e.1))
    .unwrap();

    let cycles: BigUint = response.0.cycles.into();

    vec![Metric {
        name: "canister_balance_e8s".to_string(),
        t: "gauge".to_string(),
        help: Some("canister balance for a token in e8s".to_string()),
        labels: vec![
            ("token".to_string(), "cycles".to_string()),
            ("canister".to_string(), "signing".to_string()),
        ],
        value: cycles.to_string(),
    }]
}
