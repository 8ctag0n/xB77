//! Cross-conformance fixture generator (used by the bun test in sdk/ts).
//!
//! Reads inputs from env vars (XB77_PRIV_HEX, XB77_PAYLOAD, XB77_TIMESTAMP,
//! XB77_ACTION, XB77_GATEWAY) and prints a JSON object with the resulting
//! URL, headers (already a JSON string), body (hex), pubkey, and signature.
//!
//! Used to prove byte-identical output across TS ↔ Rust wrappers given
//! the same inputs. Both wrappers consume the same xb77_core.wasm, so the
//! equality is by construction — this test makes it observable.
//!
//! Run via: `cargo run --quiet --example cross_fixture`.

use std::env;
use xb77::{Action, Xb77};

fn main() {
    let priv_hex = env::var("XB77_PRIV_HEX").expect("XB77_PRIV_HEX");
    let payload = env::var("XB77_PAYLOAD").expect("XB77_PAYLOAD");
    let timestamp_unix_ms: u64 = env::var("XB77_TIMESTAMP").expect("XB77_TIMESTAMP").parse().unwrap();
    let nonce_hex = env::var("XB77_NONCE_HEX").expect("XB77_NONCE_HEX");
    let action_byte: u8 = env::var("XB77_ACTION").expect("XB77_ACTION").parse().unwrap();
    let gateway = env::var("XB77_GATEWAY").expect("XB77_GATEWAY");

    let priv_bytes = hex::decode(&priv_hex).expect("priv hex");
    assert_eq!(priv_bytes.len(), 64, "priv must be 64 bytes");
    let mut priv64 = [0u8; 64];
    priv64.copy_from_slice(&priv_bytes);

    let nonce_bytes = hex::decode(&nonce_hex).expect("nonce hex");
    assert_eq!(nonce_bytes.len(), 12, "nonce must be 12 bytes");
    let mut nonce12 = [0u8; 12];
    nonce12.copy_from_slice(&nonce_bytes);

    let action = match action_byte {
        0x01 => Action::SubmitOrder,
        0x02 => Action::RegisterAgent,
        0x03 => Action::ClaimCredits,
        0x04 => Action::QueryPulse,
        other => panic!("bad action byte: {other}"),
    };

    let mut sdk = Xb77::load().expect("load wasm");
    let req = sdk
        .build_signed_request(&gateway, action, payload.as_bytes(), &priv64, timestamp_unix_ms, &nonce12)
        .expect("build_signed_request");

    // Build a flat JSON object identical in shape to what the TS test produces.
    let mut headers_json = String::from("{");
    let mut first = true;
    for (k, v) in &req.headers {
        if !first { headers_json.push(','); }
        first = false;
        headers_json.push('"');
        headers_json.push_str(k);
        headers_json.push_str("\":\"");
        headers_json.push_str(v);
        headers_json.push('"');
    }
    headers_json.push('}');

    let body_hex = hex::encode(&req.body);
    println!(
        "{{\"url\":\"{}\",\"method\":\"{}\",\"headers\":{},\"body_hex\":\"{}\"}}",
        req.url, req.method, headers_json, body_hex
    );
}
