use xb77::{Action, ErrorCode, Xb77, Xb77Error};

fn load() -> Xb77 {
    Xb77::load().expect("load xb77_core.wasm")
}

#[test]
fn abi_version_is_1_x() {
    let sdk = load();
    assert_eq!(sdk.abi_major, 1);
}

#[test]
fn keystore_seal_unseal_roundtrip() {
    let mut sdk = load();
    let plain = b"the quick brown fox jumps over the lazy dog";
    let blob = sdk.keystore_seal(plain, "correct horse battery staple").unwrap();
    assert_eq!(blob.len(), plain.len() + 44);

    let recovered = sdk.keystore_unseal(&blob, "correct horse battery staple").unwrap();
    assert_eq!(recovered, plain);
}

#[test]
fn keystore_wrong_password_returns_invalid_password() {
    let mut sdk = load();
    let blob = sdk.keystore_seal(b"secret", "right-pw").unwrap();
    let err = sdk.keystore_unseal(&blob, "wrong-pw").unwrap_err();
    match err {
        Xb77Error::Abi { code, .. } => assert_eq!(code, ErrorCode::InvalidPassword),
        other => panic!("expected InvalidPassword, got {:?}", other),
    }
}

#[test]
fn keystore_two_seals_differ_random_salt_nonce() {
    let mut sdk = load();
    let plain = b"deterministic? no.";
    let a = sdk.keystore_seal(plain, "pw").unwrap();
    let b = sdk.keystore_seal(plain, "pw").unwrap();
    assert_ne!(a, b);
}

#[test]
fn keystore_pubkey_extracts_trailing_32_bytes() {
    let mut sdk = load();
    let mut priv_bytes = [0u8; 64];
    priv_bytes[..32].fill(0xAA);
    priv_bytes[32..].fill(0xBB);
    let pk = sdk.keystore_pubkey(&priv_bytes).unwrap();
    assert_eq!(pk, [0xBB; 32]);
}

#[test]
fn keystore_pubkey_wrong_length_errors() {
    let mut sdk = load();
    let err = sdk.keystore_pubkey(&[0u8; 32]).unwrap_err();
    matches!(err, Xb77Error::Abi { code: ErrorCode::InvalidInput, .. });
}

#[test]
fn build_signed_request_url_and_headers_well_formed() {
    use ed25519_dalek::{SigningKey, VerifyingKey};
    use rand::rngs::OsRng;

    let mut sdk = load();
    let signing_key = SigningKey::generate(&mut OsRng);
    let verifying_key: VerifyingKey = signing_key.verifying_key();
    let mut priv64 = [0u8; 64];
    priv64[..32].copy_from_slice(&signing_key.to_bytes());
    priv64[32..].copy_from_slice(verifying_key.as_bytes());

    let req = sdk.build_signed_request(
        "https://gateway.xb77.dev",
        Action::SubmitOrder,
        br#"{"symbol":"SOL/USDC","amount":1000}"#,
        &priv64,
        1_700_000_000,
    ).unwrap();

    assert_eq!(req.method, "POST");
    assert_eq!(req.url, "https://gateway.xb77.dev/submit_order");

    let h: std::collections::HashMap<_, _> = req.headers.iter().cloned().collect();
    assert_eq!(h.get("Content-Type").map(String::as_str), Some("application/json"));
    assert_eq!(h.get("X-Xb77-Timestamp").map(String::as_str), Some("1700000000"));
    assert_eq!(h.get("X-Xb77-Pubkey").unwrap().len(), 64); // hex
    assert_eq!(h.get("X-Xb77-Signature").unwrap().len(), 128); // hex
    assert_eq!(req.body, br#"{"symbol":"SOL/USDC","amount":1000}"#);
}

#[test]
fn all_four_actions_map_to_canonical_paths() {
    use ed25519_dalek::SigningKey;
    use rand::rngs::OsRng;

    let mut sdk = load();
    let signing_key = SigningKey::generate(&mut OsRng);
    let vk = signing_key.verifying_key();
    let mut priv64 = [0u8; 64];
    priv64[..32].copy_from_slice(&signing_key.to_bytes());
    priv64[32..].copy_from_slice(vk.as_bytes());

    let cases = [
        (Action::SubmitOrder, "submit_order"),
        (Action::RegisterAgent, "register_agent"),
        (Action::ClaimCredits, "claim_credits"),
        (Action::QueryPulse, "query_pulse"),
    ];
    for (action, suffix) in cases {
        let req = sdk.build_signed_request("https://g.xb77/", action, b"{}", &priv64, 1).unwrap();
        assert_eq!(req.url, format!("https://g.xb77/{}", suffix));
    }
}

#[test]
fn wasm_signature_verifies_under_independent_ed25519_dalek() {
    use ed25519_dalek::{Signature, SigningKey, Verifier, VerifyingKey};
    use rand::rngs::OsRng;

    let mut sdk = load();
    let signing_key = SigningKey::generate(&mut OsRng);
    let verifying_key: VerifyingKey = signing_key.verifying_key();
    let mut priv64 = [0u8; 64];
    priv64[..32].copy_from_slice(&signing_key.to_bytes());
    priv64[32..].copy_from_slice(verifying_key.as_bytes());

    let payload = br#"{"order":"buy 1 SOL"}"#;
    let ts: u64 = 1_700_000_123;
    let req = sdk.build_signed_request("https://g", Action::SubmitOrder, payload, &priv64, ts).unwrap();

    let sig_hex = req.headers.iter().find(|(k, _)| k == "X-Xb77-Signature").unwrap().1.clone();
    let sig_bytes = hex::decode(&sig_hex).unwrap();
    let signature = Signature::from_slice(&sig_bytes).unwrap();

    // Reconstruct canonical bytes per addendum §A.1.
    let mut canonical = Vec::with_capacity(1 + 8 + payload.len());
    canonical.push(Action::SubmitOrder as u8);
    canonical.extend_from_slice(&ts.to_be_bytes());
    canonical.extend_from_slice(payload);

    // Independent verifier: ed25519-dalek (zero overlap with our Zig WASM).
    verifying_key.verify(&canonical, &signature).expect("dalek must accept WASM signature");
}

#[test]
fn verify_response_accepts_dalek_signed_payload() {
    use ed25519_dalek::{Signer, SigningKey};
    use rand::rngs::OsRng;

    let mut sdk = load();
    let gateway = SigningKey::generate(&mut OsRng);
    let gateway_pub = gateway.verifying_key().to_bytes();

    let body = br#"{"status":"ok","order_id":"abc123"}"#;
    let ts: u64 = 1_700_001_000;

    let mut canonical = Vec::with_capacity(1 + 8 + body.len());
    canonical.push(Action::SubmitOrder as u8);
    canonical.extend_from_slice(&ts.to_be_bytes());
    canonical.extend_from_slice(body);

    let sig = gateway.sign(&canonical).to_bytes();
    sdk.verify_response(body, Action::SubmitOrder, ts, &gateway_pub, &sig)
        .expect("WASM must accept dalek-signed response");
}

#[test]
fn verify_response_rejects_tampered_body() {
    use ed25519_dalek::{Signer, SigningKey};
    use rand::rngs::OsRng;

    let mut sdk = load();
    let gateway = SigningKey::generate(&mut OsRng);
    let gateway_pub = gateway.verifying_key().to_bytes();

    let body = br#"{"status":"ok"}"#;
    let ts: u64 = 1_700_001_000;

    let mut canonical = Vec::with_capacity(1 + 8 + body.len());
    canonical.push(Action::SubmitOrder as u8);
    canonical.extend_from_slice(&ts.to_be_bytes());
    canonical.extend_from_slice(body);
    let sig = gateway.sign(&canonical).to_bytes();

    let tampered = br#"{"status":"!!"}"#;
    let err = sdk.verify_response(tampered, Action::SubmitOrder, ts, &gateway_pub, &sig).unwrap_err();
    match err {
        Xb77Error::Abi { code, .. } => assert_eq!(code, ErrorCode::InvalidSignature),
        other => panic!("expected InvalidSignature, got {:?}", other),
    }
}
