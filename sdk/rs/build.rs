// Build script: locate the xb77_core.wasm artifact so the lib can embed it
// via include_bytes!. We try the canonical source-tree paths and fall back
// to an env override (XB77_CORE_WASM) for CI / packaged builds.

use std::env;
use std::path::PathBuf;

fn main() {
    println!("cargo:rerun-if-env-changed=XB77_CORE_WASM");
    println!("cargo:rerun-if-changed=build.rs");

    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());

    let path = if let Ok(p) = env::var("XB77_CORE_WASM") {
        PathBuf::from(p)
    } else {
        // sdk/rs/ -> ../../zig-out/bin/xb77_core.wasm
        manifest_dir
            .parent()
            .unwrap()
            .parent()
            .unwrap()
            .join("zig-out/bin/xb77_core.wasm")
    };

    let abs = path.canonicalize().unwrap_or_else(|e| {
        panic!(
            "xb77_core.wasm not found at {:?} (set XB77_CORE_WASM or run `zig build sdk-wasm`): {}",
            path, e
        );
    });
    println!("cargo:rustc-env=XB77_CORE_WASM_PATH={}", abs.display());
    println!("cargo:rerun-if-changed={}", abs.display());
}
