use ic_cdk::{
    api::{
        self,
        management_canister::ecdsa::{
            EcdsaCurve,
            EcdsaKeyId,
            ecdsa_public_key,
            EcdsaPublicKeyArgument,
            EcdsaPublicKeyResponse,
            SignWithEcdsaArgument,
            SignWithEcdsaResponse,
        },
    },
    export::{
        candid::CandidType,
        serde::{Deserialize, Serialize},
        Principal,
    },
    init, post_upgrade, pre_upgrade, storage, update,
};
use ic_ledger_types::{AccountIdentifier, Subaccount, DEFAULT_SUBACCOUNT};
use std::cell::RefCell;
use std::str::FromStr;

mod metrics;

fn mgmt_canister_id() -> Principal {
    Principal::from_str(&"aaaaa-aa").unwrap()
}

thread_local! {
    static KEY_ID: RefCell<EcdsaKeyId> = RefCell::new(EcdsaKeyIds::TestKeyLocalDevelopment.to_key_id());
    static METRICS_CANISTER: RefCell<Option<Principal>> = RefCell::new(None);
    static OWNERS: RefCell<Vec<Principal>> = RefCell::new(Vec::default());
}

#[derive(CandidType, Deserialize)]
struct StableState {
    key_id: EcdsaKeyId,
    metrics_canister: Option<Principal>,
    owners: Vec<Principal>,
}

#[pre_upgrade]
fn pre_upgrade() {
    let state = StableState {
        key_id: KEY_ID.with(|k| k.borrow().clone()),
        metrics_canister: METRICS_CANISTER.with(|k| k.borrow().clone()),
        owners: OWNERS.with(|o| o.borrow().clone()),
    };
    storage::stable_save((state,)).unwrap();
}

#[post_upgrade]
fn post_upgrade() {
    let (s,): (StableState,) = storage::stable_restore().unwrap();
    KEY_ID.with(|k| {
        *k.borrow_mut() = s.key_id;
    });
    METRICS_CANISTER.with(|m| {
        *m.borrow_mut() = s.metrics_canister;
    });
    OWNERS.with(|o| {
        let mut owners = o.borrow_mut();
        owners.clear();
        for p in s.owners.iter() {
            owners.push(*p);
        }
    });
}

#[derive(CandidType, Serialize, Debug)]
struct PrincipalReply {
    pub p: Principal,
}

#[derive(CandidType, Serialize, Debug)]
struct PublicKeyReply {
    pub public_key: Vec<u8>,
}

#[derive(CandidType, Serialize, Debug)]
struct SignatureReply {
    pub signature: Vec<u8>,
}

#[derive(CandidType, Deserialize, Serialize, Debug, Clone)]
struct InitArgs {
    pub key_id: String,
    pub metrics_canister: Option<Principal>,
    pub owners: Vec<Principal>,
}

#[init]
async fn init(args: InitArgs) {
    let parsed_key_id: EcdsaKeyId = EcdsaKeyIds::try_from(args.key_id).unwrap().to_key_id();
    KEY_ID.with(|key| {
        let mut k = key.borrow_mut();
        *k = parsed_key_id;
    });
    METRICS_CANISTER.with(|m| {
        *m.borrow_mut() = args.metrics_canister;
    });
    OWNERS.with(|owners| {
        let mut o = owners.borrow_mut();
        for p in args.owners.iter() {
            o.push(*p);
        }
    });
}

fn is_owner(user: &Principal) -> bool {
    OWNERS.with(|owners| (*owners.borrow()).contains(user))
}

fn require_owner(user: &Principal) {
    assert!(is_owner(user), "Caller is not an owner");
}

#[update]
async fn add_owner(owner: Principal) {
    require_owner(&api::caller());
    OWNERS.with(|owners| {
        let mut o = owners.borrow_mut();
        o.push(owner);
    });
}

#[update]
async fn remove_owner(owner: Principal) {
    require_owner(&api::caller());
    OWNERS.with(|owners| {
        let mut o = owners.borrow_mut();
        o.retain(|p| p != &owner);
    });
}

#[update]
async fn get_principal() -> Result<PrincipalReply, String> {
    let public_key = get_public_key().await?;
    Ok(PrincipalReply {
        p: Principal::self_authenticating(public_key),
    })
}

#[update]
async fn address(subaccount: Option<Vec<u8>>) -> String {
    let public_key = Principal::self_authenticating(get_public_key().await.unwrap());
    let sub: [u8; 32] = subaccount
        .unwrap_or(DEFAULT_SUBACCOUNT.0.to_vec())
        .try_into()
        .unwrap();
    AccountIdentifier::new(&public_key, &Subaccount(sub)).to_string()
}

#[update]
async fn public_key() -> Result<PublicKeyReply, String> {
    let public_key = get_public_key().await?;
    Ok(PublicKeyReply { public_key })
}

#[update]
async fn sign(message: Vec<u8>) -> Result<SignatureReply, String> {
    require_owner(&api::caller());
    assert!(message.len() == 32);

    let (res,): (SignWithEcdsaResponse,) = ic_cdk::api::call::call_with_payment(
        mgmt_canister_id(),
        "sign_with_ecdsa",
        (SignWithEcdsaArgument {
            message_hash: message.clone(),
            derivation_path: derivation_path(),
            key_id: key_id(),
        },),
        25_000_000_000,
    )
    .await
    .map_err(|e| format!("Failed to call sign_with_ecdsa {}", e.1))?;

    Ok(SignatureReply {
        signature: res.signature,
    })
}

#[update]
async fn set_metrics(new_value: Option<Principal>) {
    require_owner(&api::caller());
    METRICS_CANISTER.with(|m| {
        *m.borrow_mut() = new_value;
    });
}

#[update]
async fn metrics() -> Vec<metrics::Metric> {
    if !is_owner(&api::caller()) {
        let caller = api::caller();
        METRICS_CANISTER.with(|m| {
            assert!(Some(caller) == *m.borrow());
        });
    }
    metrics::metrics().await
}

fn key_id() -> EcdsaKeyId {
    KEY_ID.with(|k| k.borrow().clone())
}

fn derivation_path() -> Vec<Vec<u8>> {
    vec![]
}

enum EcdsaKeyIds {
    #[allow(unused)]
    TestKeyLocalDevelopment,
    #[allow(unused)]
    TestKey1,
    #[allow(unused)]
    ProductionKey1,
}

impl EcdsaKeyIds {
    fn to_key_id(&self) -> EcdsaKeyId {
        EcdsaKeyId {
            curve: EcdsaCurve::Secp256k1,
            name: match self {
                Self::TestKeyLocalDevelopment => "dfx_test_key",
                Self::TestKey1 => "test_key_1",
                Self::ProductionKey1 => "key_1",
            }
            .to_string(),
        }
    }
}

#[derive(CandidType, Deserialize, Debug)]
enum ParseEcdsaKeyIdError {
    UnknownKeyId,
}

impl TryFrom<String> for EcdsaKeyIds {
    type Error = ParseEcdsaKeyIdError;

    fn try_from(s: String) -> Result<Self, Self::Error> {
        match s.as_str() {
            "dfx_test_key" => Ok(Self::TestKeyLocalDevelopment),
            "test_key_1" => Ok(Self::TestKey1),
            "key_1" => Ok(Self::ProductionKey1),
            _ => Err(ParseEcdsaKeyIdError::UnknownKeyId),
        }
    }
}

async fn get_public_key() -> Result<Vec<u8>, String> {
    let (res,): (EcdsaPublicKeyResponse,) =
         ecdsa_public_key(EcdsaPublicKeyArgument{
            canister_id: None,
            derivation_path: derivation_path(),
            key_id: key_id(),
         })
            .await
            .map_err(|e| format!("Failed to call ecdsa_public_key {}", e.1))?;

    Ok(res.public_key)
}
