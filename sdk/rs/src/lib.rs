//! `xb77` — Rust SDK for the xB77 Sovereign Commerce Layer.
//!
//! Powered by the same `xb77_core.wasm` artifact (~75 KB) that the
//! TypeScript wrapper consumes. Signed requests are byte-identical
//! across wrappers (see addendum §A.1).
//!
//! ```no_run
//! use xb77::{Xb77, Action};
//!
//! # fn run() -> Result<(), Box<dyn std::error::Error>> {
//! let mut sdk = Xb77::load()?;
//!
//! let sealed = sdk.keystore_seal(b"my private bytes", "correct horse battery staple")?;
//! let recovered = sdk.keystore_unseal(&sealed, "correct horse battery staple")?;
//! assert_eq!(recovered, b"my private bytes");
//!
//! let priv_64 = [0u8; 64]; // your Ed25519 secret in canonical seed||pubkey form
//! let nonce = [0u8; 12]; // in real use: rand::random()
//! let req = sdk.build_signed_request(
//!     "https://gateway.xb77.dev",
//!     Action::SubmitOrder,
//!     br#"{"symbol":"SOL/USDC","amount":1000}"#,
//!     &priv_64,
//!     1_700_000_000_000,
//!     &nonce,
//! )?;
//!
//! // The wrapper does HTTP in its idiomatic style (reqwest, ureq, ...).
//! # Ok(()) }
//! ```

use std::path::Path;
use thiserror::Error;
use wasmtime::{Engine, Func, Linker, Memory, Module, Store, TypedFunc, Val};
use wasmtime_wasi::preview1::WasiP1Ctx;
use wasmtime_wasi::WasiCtxBuilder;

/// Embedded WASM artifact (located by `build.rs`).
const XB77_CORE_WASM: &[u8] = include_bytes!(env!("XB77_CORE_WASM_PATH"));

/// Action enum — matches the locked v1 ABI byte values.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum Action {
    SubmitOrder = 0x01,
    RegisterAgent = 0x02,
    ClaimCredits = 0x03,
    QueryPulse = 0x04,
    LinkAgent = 0x05,
}

/// Error code enum — locked in addendum §A.2.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Error)]
#[repr(u32)]
pub enum ErrorCode {
    #[error("invalid input")]
    InvalidInput = 1,
    #[error("buffer too small")]
    BufferTooSmall = 2,
    #[error("invalid password")]
    InvalidPassword = 3,
    #[error("invalid signature")]
    InvalidSignature = 4,
    #[error("invalid action")]
    InvalidAction = 5,
    #[error("out of memory")]
    OutOfMemory = 6,
    #[error("invalid blob")]
    InvalidBlob = 7,
}

impl ErrorCode {
    fn from_u32(v: u32) -> Option<Self> {
        match v {
            1 => Some(Self::InvalidInput),
            2 => Some(Self::BufferTooSmall),
            3 => Some(Self::InvalidPassword),
            4 => Some(Self::InvalidSignature),
            5 => Some(Self::InvalidAction),
            6 => Some(Self::OutOfMemory),
            7 => Some(Self::InvalidBlob),
            _ => None,
        }
    }
}

#[derive(Debug, Error)]
pub enum Xb77Error {
    #[error("xb77 ABI error ({op}): {code}")]
    Abi { op: &'static str, code: ErrorCode },
    #[error("xb77 wasm runtime error: {0}")]
    Wasm(#[from] wasmtime::Error),
    #[error("xb77 wasm memory access: {0}")]
    Memory(#[from] wasmtime::MemoryAccessError),
    #[error("xb77 wasm trap: {0}")]
    Trap(String),
    #[error("xb77: unsupported ABI major version {major} (expected 1)")]
    UnsupportedAbi { major: u32 },
}

pub type Xb77Result<T> = Result<T, Xb77Error>;

#[derive(Debug, Clone)]
pub struct SignedRequest {
    pub url: String,
    pub method: &'static str, // always "POST"
    pub headers: Vec<(String, String)>,
    pub body: Vec<u8>,
}

/// SDK instance. Holds an instantiated WASM module + a wasmtime store.
///
/// Wrap in a `Mutex` if you need to share across threads — the WASM
/// instance is stateful (linear memory).
pub struct Xb77 {
    store: Store<WasiP1Ctx>,
    memory: Memory,
    fns: Fns,
    pub abi_major: u16,
    pub abi_minor: u16,
}

struct Fns {
    abi_version: TypedFunc<(), u32>,
    wasm_alloc: TypedFunc<u32, u32>,
    wasm_free: TypedFunc<(u32, u32), ()>,
    keystore_seal: TypedFunc<(u32, u32, u32, u32, u32, u32, u32), u32>,
    keystore_unseal: TypedFunc<(u32, u32, u32, u32, u32, u32, u32), u32>,
    keystore_pubkey: TypedFunc<(u32, u32, u32), u32>,
    /// Untyped: wasmtime TypedFunc tuples cap at 16 params, this fn takes 19.
    build_signed_request: Func,
    verify_response: TypedFunc<(u32, u32, u32, u64, u32, u32, u32, u32), u32>,
}

impl Xb77 {
    /// Load using the embedded WASM artifact.
    pub fn load() -> Xb77Result<Self> {
        Self::load_bytes(XB77_CORE_WASM)
    }

    /// Load from a custom WASM path.
    pub fn load_from_path(path: impl AsRef<Path>) -> Xb77Result<Self> {
        let bytes = std::fs::read(path).map_err(|e| Xb77Error::Trap(format!("read wasm: {e}")))?;
        Self::load_bytes(&bytes)
    }

    /// Load from raw bytes.
    pub fn load_bytes(bytes: &[u8]) -> Xb77Result<Self> {
        let engine = Engine::default();
        let module = Module::from_binary(&engine, bytes)?;

        let mut linker: Linker<WasiP1Ctx> = Linker::new(&engine);
        wasmtime_wasi::preview1::add_to_linker_sync(&mut linker, |s| s)?;

        let wasi = WasiCtxBuilder::new().inherit_stderr().build_p1();
        let mut store = Store::new(&engine, wasi);
        let instance = linker.instantiate(&mut store, &module)?;

        let memory = instance
            .get_memory(&mut store, "memory")
            .ok_or_else(|| Xb77Error::Trap("missing memory export".into()))?;

        let fns = Fns {
            abi_version: instance.get_typed_func(&mut store, "xb77_abi_version")?,
            wasm_alloc: instance.get_typed_func(&mut store, "wasm_alloc")?,
            wasm_free: instance.get_typed_func(&mut store, "wasm_free")?,
            keystore_seal: instance.get_typed_func(&mut store, "keystore_seal")?,
            keystore_unseal: instance.get_typed_func(&mut store, "keystore_unseal")?,
            keystore_pubkey: instance.get_typed_func(&mut store, "keystore_pubkey")?,
            build_signed_request: instance
                .get_func(&mut store, "build_signed_request")
                .ok_or_else(|| Xb77Error::Trap("missing export: build_signed_request".into()))?,
            verify_response: instance.get_typed_func(&mut store, "verify_response")?,
        };

        let v = fns.abi_version.call(&mut store, ())?;
        let major = ((v >> 16) & 0xffff) as u16;
        let minor = (v & 0xffff) as u16;
        if major != 1 {
            return Err(Xb77Error::UnsupportedAbi { major: major as u32 });
        }

        Ok(Self { store, memory, fns, abi_major: major, abi_minor: minor })
    }

    // ----- low-level helpers -----

    fn write_bytes(&mut self, data: &[u8]) -> Xb77Result<u32> {
        if data.is_empty() {
            return Ok(0);
        }
        let ptr = self.fns.wasm_alloc.call(&mut self.store, data.len() as u32)?;
        if ptr == 0 {
            return Err(Xb77Error::Abi { op: "wasm_alloc", code: ErrorCode::OutOfMemory });
        }
        self.memory.write(&mut self.store, ptr as usize, data)?;
        Ok(ptr)
    }

    fn alloc_len_slot(&mut self) -> Xb77Result<u32> {
        let ptr = self.fns.wasm_alloc.call(&mut self.store, 4)?;
        if ptr == 0 {
            return Err(Xb77Error::Abi { op: "wasm_alloc", code: ErrorCode::OutOfMemory });
        }
        Ok(ptr)
    }

    fn read_u32(&self, ptr: u32) -> Xb77Result<u32> {
        let mut buf = [0u8; 4];
        self.memory.read(&self.store, ptr as usize, &mut buf)?;
        Ok(u32::from_le_bytes(buf))
    }

    fn read_bytes(&self, ptr: u32, len: u32) -> Xb77Result<Vec<u8>> {
        let mut buf = vec![0u8; len as usize];
        if len == 0 {
            return Ok(buf);
        }
        self.memory.read(&self.store, ptr as usize, &mut buf)?;
        Ok(buf)
    }

    fn free(&mut self, ptr: u32, len: u32) {
        if ptr != 0 && len != 0 {
            let _ = self.fns.wasm_free.call(&mut self.store, (ptr, len));
        }
    }

    fn check(&self, op: &'static str, rc: u32) -> Xb77Result<()> {
        if rc == 0 {
            Ok(())
        } else if let Some(code) = ErrorCode::from_u32(rc) {
            Err(Xb77Error::Abi { op, code })
        } else {
            Err(Xb77Error::Trap(format!("{op}: unknown rc={rc}")))
        }
    }

    // ----- keystore -----

    pub fn keystore_seal(&mut self, plain: &[u8], password: &str) -> Xb77Result<Vec<u8>> {
        let plain_ptr = self.write_bytes(plain)?;
        let pw = password.as_bytes();
        let pw_ptr = self.write_bytes(pw)?;
        let len_slot = self.alloc_len_slot()?;

        // Probe required size.
        let _ = self.fns.keystore_seal.call(
            &mut self.store,
            (plain_ptr, plain.len() as u32, pw_ptr, pw.len() as u32, 0, 0, len_slot),
        )?;
        let required = self.read_u32(len_slot)?;
        let out_ptr = self.fns.wasm_alloc.call(&mut self.store, required)?;
        if out_ptr == 0 {
            self.free(plain_ptr, plain.len() as u32);
            self.free(pw_ptr, pw.len() as u32);
            self.free(len_slot, 4);
            return Err(Xb77Error::Abi { op: "wasm_alloc", code: ErrorCode::OutOfMemory });
        }

        let rc = self.fns.keystore_seal.call(
            &mut self.store,
            (plain_ptr, plain.len() as u32, pw_ptr, pw.len() as u32, out_ptr, required, len_slot),
        )?;
        let blob = self.read_bytes(out_ptr, required)?;
        self.free(plain_ptr, plain.len() as u32);
        self.free(pw_ptr, pw.len() as u32);
        self.free(out_ptr, required);
        self.free(len_slot, 4);
        self.check("keystore_seal", rc)?;
        Ok(blob)
    }

    pub fn keystore_unseal(&mut self, blob: &[u8], password: &str) -> Xb77Result<Vec<u8>> {
        let blob_ptr = self.write_bytes(blob)?;
        let pw = password.as_bytes();
        let pw_ptr = self.write_bytes(pw)?;
        let len_slot = self.alloc_len_slot()?;

        let _ = self.fns.keystore_unseal.call(
            &mut self.store,
            (blob_ptr, blob.len() as u32, pw_ptr, pw.len() as u32, 0, 0, len_slot),
        )?;
        let required = self.read_u32(len_slot)?;
        let alloc_size = required.max(1);
        let out_ptr = self.fns.wasm_alloc.call(&mut self.store, alloc_size)?;
        if out_ptr == 0 {
            self.free(blob_ptr, blob.len() as u32);
            self.free(pw_ptr, pw.len() as u32);
            self.free(len_slot, 4);
            return Err(Xb77Error::Abi { op: "wasm_alloc", code: ErrorCode::OutOfMemory });
        }

        let rc = self.fns.keystore_unseal.call(
            &mut self.store,
            (blob_ptr, blob.len() as u32, pw_ptr, pw.len() as u32, out_ptr, required, len_slot),
        )?;
        let out = self.read_bytes(out_ptr, required)?;
        self.free(blob_ptr, blob.len() as u32);
        self.free(pw_ptr, pw.len() as u32);
        self.free(out_ptr, alloc_size);
        self.free(len_slot, 4);
        self.check("keystore_unseal", rc)?;
        Ok(out)
    }

    pub fn keystore_pubkey(&mut self, privkey: &[u8]) -> Xb77Result<[u8; 32]> {
        if privkey.len() != 64 {
            return Err(Xb77Error::Abi { op: "keystore_pubkey", code: ErrorCode::InvalidInput });
        }
        let priv_ptr = self.write_bytes(privkey)?;
        let out_ptr = self.fns.wasm_alloc.call(&mut self.store, 32)?;
        let rc = self.fns.keystore_pubkey.call(&mut self.store, (priv_ptr, 64, out_ptr))?;
        let bytes = self.read_bytes(out_ptr, 32)?;
        self.free(priv_ptr, 64);
        self.free(out_ptr, 32);
        self.check("keystore_pubkey", rc)?;
        let mut out = [0u8; 32];
        out.copy_from_slice(&bytes);
        Ok(out)
    }

    // ----- signed request -----

    pub fn build_signed_request(
        &mut self,
        gateway_base: &str,
        action: Action,
        payload: &[u8],
        privkey: &[u8; 64],
        timestamp_unix_ms: u64,
        nonce: &[u8; 12],
    ) -> Xb77Result<SignedRequest> {
        let payload_ptr = self.write_bytes(payload)?;
        let priv_ptr = self.write_bytes(privkey)?;
        let nonce_ptr = self.write_bytes(nonce)?;
        let base = gateway_base.as_bytes();
        let base_ptr = self.write_bytes(base)?;
        let url_slot = self.alloc_len_slot()?;
        let hdr_slot = self.alloc_len_slot()?;
        let body_slot = self.alloc_len_slot()?;

        let action_byte = action as u32;

        let mk_args = |url_out: u32, url_max: u32, hdr_out: u32, hdr_max: u32, body_out: u32, body_max: u32| -> [Val; 19] {
            [
                Val::I32(action_byte as i32),
                Val::I32(payload_ptr as i32), Val::I32(payload.len() as i32),
                Val::I32(priv_ptr as i32), Val::I32(64),
                Val::I64(timestamp_unix_ms as i64),
                Val::I32(nonce_ptr as i32), Val::I32(12),
                Val::I32(base_ptr as i32), Val::I32(base.len() as i32),
                Val::I32(url_out as i32), Val::I32(url_max as i32), Val::I32(url_slot as i32),
                Val::I32(hdr_out as i32), Val::I32(hdr_max as i32), Val::I32(hdr_slot as i32),
                Val::I32(body_out as i32), Val::I32(body_max as i32), Val::I32(body_slot as i32),
            ]
        };
        let mut ret = [Val::I32(0); 1];

        // Probe sizes (max = 0).
        self.fns.build_signed_request.call(
            &mut self.store,
            &mk_args(0, 0, 0, 0, 0, 0),
            &mut ret,
        )?;
        let url_len = self.read_u32(url_slot)?;
        let hdr_len = self.read_u32(hdr_slot)?;
        let body_len = self.read_u32(body_slot)?;

        let url_ptr = self.fns.wasm_alloc.call(&mut self.store, url_len)?;
        let hdr_ptr = self.fns.wasm_alloc.call(&mut self.store, hdr_len)?;
        let body_ptr = self.fns.wasm_alloc.call(&mut self.store, body_len.max(1))?;

        self.fns.build_signed_request.call(
            &mut self.store,
            &mk_args(url_ptr, url_len, hdr_ptr, hdr_len, body_ptr, body_len.max(1)),
            &mut ret,
        )?;
        let rc = match ret[0] {
            Val::I32(v) => v as u32,
            _ => return Err(Xb77Error::Trap("build_signed_request: non-i32 return".into())),
        };

        let url = String::from_utf8(self.read_bytes(url_ptr, url_len)?)
            .map_err(|e| Xb77Error::Trap(format!("url not utf-8: {e}")))?;
        let headers_json = String::from_utf8(self.read_bytes(hdr_ptr, hdr_len)?)
            .map_err(|e| Xb77Error::Trap(format!("headers not utf-8: {e}")))?;
        let body = self.read_bytes(body_ptr, body_len)?;

        self.free(payload_ptr, payload.len() as u32);
        self.free(priv_ptr, 64);
        self.free(nonce_ptr, 12);
        self.free(base_ptr, base.len() as u32);
        self.free(url_slot, 4);
        self.free(hdr_slot, 4);
        self.free(body_slot, 4);
        self.free(url_ptr, url_len);
        self.free(hdr_ptr, hdr_len);
        self.free(body_ptr, body_len.max(1));

        self.check("build_signed_request", rc)?;

        // headers_json is a flat {"k":"v",...} — parse minimally without serde.
        let headers = parse_flat_json_object(&headers_json)
            .map_err(|e| Xb77Error::Trap(format!("headers parse: {e}")))?;
        Ok(SignedRequest { url, method: "POST", headers, body })
    }

    pub fn verify_response(
        &mut self,
        body: &[u8],
        expected_action: Action,
        timestamp_unix_ms: u64,
        gateway_pubkey: &[u8; 32],
        signature: &[u8; 64],
    ) -> Xb77Result<()> {
        let body_ptr = self.write_bytes(body)?;
        let pk_ptr = self.write_bytes(gateway_pubkey)?;
        let sig_ptr = self.write_bytes(signature)?;
        let rc = self.fns.verify_response.call(
            &mut self.store,
            (
                body_ptr, body.len() as u32,
                expected_action as u32,
                timestamp_unix_ms,
                pk_ptr, 32,
                sig_ptr, 64,
            ),
        )?;
        self.free(body_ptr, body.len() as u32);
        self.free(pk_ptr, 32);
        self.free(sig_ptr, 64);
        self.check("verify_response", rc)
    }
}

/// Tiny parser for a flat JSON object of the form
/// `{"k1":"v1","k2":"v2",...}`. Good enough for our headers payload —
/// avoids pulling serde just for one parse path.
fn parse_flat_json_object(s: &str) -> Result<Vec<(String, String)>, String> {
    let s = s.trim();
    if !s.starts_with('{') || !s.ends_with('}') {
        return Err("not an object".into());
    }
    let inner = &s[1..s.len() - 1];
    let mut out = Vec::new();
    let mut chars = inner.chars().peekable();
    while chars.peek().is_some() {
        skip_ws(&mut chars);
        if chars.peek().is_none() { break; }
        let k = read_string(&mut chars)?;
        skip_ws(&mut chars);
        if chars.next() != Some(':') { return Err("expected ':'".into()); }
        skip_ws(&mut chars);
        let v = read_string(&mut chars)?;
        out.push((k, v));
        skip_ws(&mut chars);
        match chars.peek() {
            Some(',') => { chars.next(); }
            None => break,
            other => return Err(format!("expected ',' or end, got {:?}", other)),
        }
    }
    Ok(out)
}

fn skip_ws(it: &mut std::iter::Peekable<std::str::Chars>) {
    while let Some(&c) = it.peek() {
        if c.is_whitespace() { it.next(); } else { break; }
    }
}

fn read_string(it: &mut std::iter::Peekable<std::str::Chars>) -> Result<String, String> {
    if it.next() != Some('"') { return Err("expected '\"'".into()); }
    let mut s = String::new();
    while let Some(c) = it.next() {
        match c {
            '"' => return Ok(s),
            '\\' => match it.next() {
                Some('"') => s.push('"'),
                Some('\\') => s.push('\\'),
                Some(other) => { s.push('\\'); s.push(other); }
                None => return Err("unterminated escape".into()),
            },
            other => s.push(other),
        }
    }
    Err("unterminated string".into())
}
