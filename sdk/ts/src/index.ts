/**
 * @xb77/sdk — TypeScript wrapper over the xb77_core.wasm SDK core.
 *
 * Public API mirrors the Zig core in `core/sdk/sdk.zig` and exposes the
 * WASM ABI from `sdk/wasm/exports.zig`. See addendum §A for the locked
 * conventions (error codes, length protocol, UTF-8, gateway pubkey pinning).
 */

// ----- Public types -----

export enum Action {
  SubmitOrder = 0x01,
  RegisterAgent = 0x02,
  ClaimCredits = 0x03,
  QueryPulse = 0x04,
}

export enum ErrorCode {
  Ok = 0,
  InvalidInput = 1,
  BufferTooSmall = 2,
  InvalidPassword = 3,
  InvalidSignature = 4,
  InvalidAction = 5,
  OutOfMemory = 6,
  InvalidBlob = 7,
}

export class Xb77Error extends Error {
  constructor(public readonly code: ErrorCode, op: string) {
    super(`[xB77] ${op} failed: ${ErrorCode[code] ?? code}`);
    this.name = "Xb77Error";
  }
}

export interface SignedRequest {
  url: string;
  method: "POST";
  headers: Record<string, string>;
  body: Uint8Array;
}

export interface LoadOptions {
  /** Raw WASM bytes. If omitted, loader looks for ./wasm/xb77_core.wasm */
  wasmBytes?: Uint8Array | ArrayBuffer;
  /** Override gateway pubkey for verifyResponse (32 bytes). */
  gatewayPubkey?: Uint8Array;
}

// ----- ABI shape -----

interface WasmExports {
  memory: WebAssembly.Memory;
  xb77_abi_version(): number;
  wasm_alloc(n: number): number;
  wasm_free(ptr: number, n: number): void;
  keystore_seal(
    plainPtr: number, plainLen: number,
    pwPtr: number, pwLen: number,
    outPtr: number, outMax: number, outLenPtr: number,
  ): number;
  keystore_unseal(
    blobPtr: number, blobLen: number,
    pwPtr: number, pwLen: number,
    outPtr: number, outMax: number, outLenPtr: number,
  ): number;
  keystore_pubkey(privPtr: number, privLen: number, outPubPtr: number): number;
  build_signed_request(
    action: number,
    payloadPtr: number, payloadLen: number,
    privPtr: number, privLen: number,
    timestamp: bigint,
    basePtr: number, baseLen: number,
    urlOut: number, urlMax: number, urlLenPtr: number,
    hdrOut: number, hdrMax: number, hdrLenPtr: number,
    bodyOut: number, bodyMax: number, bodyLenPtr: number,
  ): number;
  verify_response(
    bodyPtr: number, bodyLen: number,
    expectedAction: number,
    timestamp: bigint,
    pkPtr: number, pkLen: number,
    sigPtr: number, sigLen: number,
  ): number;
}

// ----- WASI shim -----
//
// xb77_core.wasm targets wasm32-wasi but only actually uses:
//   - random_get  (entropy for AES-GCM nonce + PBKDF2 salt randomness)
//   - clock_time_get (for any std lib internal — we don't expose clock)
//   - fd_write    (for std.debug.print in debug builds; no-op in release)
//   - proc_exit   (panic path)
//
// This shim provides minimal implementations. No filesystem, no env.

function makeWasiShim(memoryRef: { current?: WebAssembly.Memory }) {
  const getMem = () => {
    const m = memoryRef.current;
    if (!m) throw new Error("[xB77] WASI call before memory ready");
    return new DataView(m.buffer);
  };
  const getBytes = (ptr: number, len: number) => {
    const m = memoryRef.current!;
    return new Uint8Array(m.buffer, ptr, len);
  };

  return {
    wasi_snapshot_preview1: {
      random_get(bufPtr: number, bufLen: number): number {
        crypto.getRandomValues(getBytes(bufPtr, bufLen));
        return 0;
      },
      clock_time_get(_clockId: number, _precision: bigint, timePtr: number): number {
        const ns = BigInt(Date.now()) * 1_000_000n;
        getMem().setBigUint64(timePtr, ns, true);
        return 0;
      },
      fd_write(fd: number, iovsPtr: number, iovsLen: number, nwrittenPtr: number): number {
        // Best-effort: collect bytes and write to console for fd 1/2.
        const dv = getMem();
        let total = 0;
        const chunks: Uint8Array[] = [];
        for (let i = 0; i < iovsLen; i++) {
          const base = iovsPtr + i * 8;
          const ptr = dv.getUint32(base, true);
          const len = dv.getUint32(base + 4, true);
          chunks.push(new Uint8Array(getBytes(ptr, len)));
          total += len;
        }
        if (fd === 1 || fd === 2) {
          const txt = new TextDecoder().decode(concat(chunks));
          (fd === 2 ? console.error : console.log)(txt.replace(/\n$/, ""));
        }
        dv.setUint32(nwrittenPtr, total, true);
        return 0;
      },
      proc_exit(code: number): never {
        throw new Error(`[xB77] WASM proc_exit(${code})`);
      },
      // Common stubs so the linker is happy even if std touches them.
      fd_close(): number { return 0; },
      fd_seek(): number { return 0; },
      fd_fdstat_get(): number { return 0; },
      fd_read(_fd: number, _iovs: number, _iovsLen: number, nreadPtr: number): number {
        getMem().setUint32(nreadPtr, 0, true);
        return 0;
      },
      fd_pwrite(_fd: number, _iovs: number, _iovsLen: number, _offset: bigint, nwrittenPtr: number): number {
        getMem().setUint32(nwrittenPtr, 0, true);
        return 0;
      },
      fd_filestat_get(_fd: number, statPtr: number): number {
        const m = memoryRef.current!;
        new Uint8Array(m.buffer, statPtr, 64).fill(0);
        return 0;
      },
      environ_get(): number { return 0; },
      environ_sizes_get(sizesPtr: number, bufSizePtr: number): number {
        const dv = getMem();
        dv.setUint32(sizesPtr, 0, true);
        dv.setUint32(bufSizePtr, 0, true);
        return 0;
      },
      args_get(): number { return 0; },
      args_sizes_get(argcPtr: number, bufSizePtr: number): number {
        const dv = getMem();
        dv.setUint32(argcPtr, 0, true);
        dv.setUint32(bufSizePtr, 0, true);
        return 0;
      },
    },
  };
}

function concat(parts: Uint8Array[]): Uint8Array {
  const total = parts.reduce((s, p) => s + p.length, 0);
  const out = new Uint8Array(total);
  let off = 0;
  for (const p of parts) { out.set(p, off); off += p.length; }
  return out;
}

// ----- Loader -----

export class XB77 {
  private constructor(
    private readonly exports: WasmExports,
    private readonly memory: WebAssembly.Memory,
    public readonly abiVersion: { major: number; minor: number },
  ) {}

  static async load(opts: LoadOptions = {}): Promise<XB77> {
    const bytes = opts.wasmBytes ?? await defaultLoadWasm();
    const memoryRef: { current?: WebAssembly.Memory } = {};
    const imports = makeWasiShim(memoryRef);
    const { instance } = await WebAssembly.instantiate(bytes, imports);
    const exp = instance.exports as unknown as WasmExports;
    memoryRef.current = exp.memory;

    const v = exp.xb77_abi_version();
    const major = (v >>> 16) & 0xffff;
    const minor = v & 0xffff;
    if (major !== 1) {
      throw new Error(`[xB77] unsupported ABI major version ${major} (wrapper expects 1)`);
    }
    return new XB77(exp, exp.memory, { major, minor });
  }

  // ----- low-level helpers -----

  private writeBytes(data: Uint8Array): number {
    if (data.length === 0) return 0;
    const ptr = this.exports.wasm_alloc(data.length);
    if (ptr === 0) throw new Xb77Error(ErrorCode.OutOfMemory, "wasm_alloc");
    new Uint8Array(this.memory.buffer, ptr, data.length).set(data);
    return ptr;
  }

  private writeString(s: string): { ptr: number; len: number } {
    const data = new TextEncoder().encode(s);
    return { ptr: this.writeBytes(data), len: data.length };
  }

  private readBytes(ptr: number, len: number): Uint8Array {
    return new Uint8Array(this.memory.buffer, ptr, len).slice();
  }

  private allocLenSlot(): number {
    return this.exports.wasm_alloc(4);
  }

  private readLen(ptr: number): number {
    return new DataView(this.memory.buffer).getUint32(ptr, true);
  }

  // ----- keystore -----

  readonly keystore = {
    seal: (plain: Uint8Array, password: string): Uint8Array => {
      const plainPtr = this.writeBytes(plain);
      const pw = this.writeString(password);
      // First call with max=0 to learn required size.
      const lenSlot = this.allocLenSlot();
      this.exports.keystore_seal(plainPtr, plain.length, pw.ptr, pw.len, 0, 0, lenSlot);
      const required = this.readLen(lenSlot);
      const outPtr = this.exports.wasm_alloc(required);
      const rc = this.exports.keystore_seal(
        plainPtr, plain.length, pw.ptr, pw.len,
        outPtr, required, lenSlot,
      );
      const blob = this.readBytes(outPtr, required);
      this.exports.wasm_free(plainPtr, plain.length);
      this.exports.wasm_free(pw.ptr, pw.len);
      this.exports.wasm_free(outPtr, required);
      this.exports.wasm_free(lenSlot, 4);
      if (rc !== 0) throw new Xb77Error(rc, "keystore_seal");
      return blob;
    },

    unseal: (blob: Uint8Array, password: string): Uint8Array => {
      const blobPtr = this.writeBytes(blob);
      const pw = this.writeString(password);
      const lenSlot = this.allocLenSlot();
      // Query required size by calling with max=0.
      this.exports.keystore_unseal(blobPtr, blob.length, pw.ptr, pw.len, 0, 0, lenSlot);
      const required = this.readLen(lenSlot);
      const outPtr = this.exports.wasm_alloc(Math.max(required, 1));
      const rc = this.exports.keystore_unseal(
        blobPtr, blob.length, pw.ptr, pw.len,
        outPtr, required, lenSlot,
      );
      const out = this.readBytes(outPtr, required);
      this.exports.wasm_free(blobPtr, blob.length);
      this.exports.wasm_free(pw.ptr, pw.len);
      this.exports.wasm_free(outPtr, Math.max(required, 1));
      this.exports.wasm_free(lenSlot, 4);
      if (rc !== 0) throw new Xb77Error(rc, "keystore_unseal");
      return out;
    },

    pubkey: (privkey: Uint8Array): Uint8Array => {
      if (privkey.length !== 64) {
        throw new Xb77Error(ErrorCode.InvalidInput, "keystore_pubkey: privkey must be 64 bytes");
      }
      const privPtr = this.writeBytes(privkey);
      const outPtr = this.exports.wasm_alloc(32);
      const rc = this.exports.keystore_pubkey(privPtr, 64, outPtr);
      const pk = this.readBytes(outPtr, 32);
      this.exports.wasm_free(privPtr, 64);
      this.exports.wasm_free(outPtr, 32);
      if (rc !== 0) throw new Xb77Error(rc, "keystore_pubkey");
      return pk;
    },
  };

  // ----- signed request -----

  buildSignedRequest(args: {
    gatewayBase: string;
    action: Action;
    payload: Uint8Array | string;
    privkey: Uint8Array; // 64 bytes
    timestampUnix?: number; // defaults to Date.now()/1000
  }): SignedRequest {
    if (args.privkey.length !== 64) {
      throw new Xb77Error(ErrorCode.InvalidInput, "build_signed_request: privkey must be 64 bytes");
    }
    const payloadBytes = typeof args.payload === "string"
      ? new TextEncoder().encode(args.payload)
      : args.payload;
    const ts = BigInt(args.timestampUnix ?? Math.floor(Date.now() / 1000));

    const payloadPtr = this.writeBytes(payloadBytes);
    const privPtr = this.writeBytes(args.privkey);
    const baseStr = this.writeString(args.gatewayBase);
    const urlLenSlot = this.allocLenSlot();
    const hdrLenSlot = this.allocLenSlot();
    const bodyLenSlot = this.allocLenSlot();

    // Probe with max=0 to learn sizes.
    this.exports.build_signed_request(
      args.action,
      payloadPtr, payloadBytes.length,
      privPtr, 64,
      ts,
      baseStr.ptr, baseStr.len,
      0, 0, urlLenSlot,
      0, 0, hdrLenSlot,
      0, 0, bodyLenSlot,
    );
    const urlLen = this.readLen(urlLenSlot);
    const hdrLen = this.readLen(hdrLenSlot);
    const bodyLen = this.readLen(bodyLenSlot);

    const urlPtr = this.exports.wasm_alloc(urlLen);
    const hdrPtr = this.exports.wasm_alloc(hdrLen);
    const bodyPtr = this.exports.wasm_alloc(Math.max(bodyLen, 1));

    const rc = this.exports.build_signed_request(
      args.action,
      payloadPtr, payloadBytes.length,
      privPtr, 64,
      ts,
      baseStr.ptr, baseStr.len,
      urlPtr, urlLen, urlLenSlot,
      hdrPtr, hdrLen, hdrLenSlot,
      bodyPtr, Math.max(bodyLen, 1), bodyLenSlot,
    );

    const url = new TextDecoder().decode(this.readBytes(urlPtr, urlLen));
    const headersJson = new TextDecoder().decode(this.readBytes(hdrPtr, hdrLen));
    const body = this.readBytes(bodyPtr, bodyLen);

    this.exports.wasm_free(payloadPtr, payloadBytes.length);
    this.exports.wasm_free(privPtr, 64);
    this.exports.wasm_free(baseStr.ptr, baseStr.len);
    this.exports.wasm_free(urlLenSlot, 4);
    this.exports.wasm_free(hdrLenSlot, 4);
    this.exports.wasm_free(bodyLenSlot, 4);
    this.exports.wasm_free(urlPtr, urlLen);
    this.exports.wasm_free(hdrPtr, hdrLen);
    this.exports.wasm_free(bodyPtr, Math.max(bodyLen, 1));

    if (rc !== 0) throw new Xb77Error(rc, "build_signed_request");

    return {
      url,
      method: "POST",
      headers: JSON.parse(headersJson) as Record<string, string>,
      body,
    };
  }

  verifyResponse(args: {
    body: Uint8Array;
    expectedAction: Action;
    timestampUnix: number;
    gatewayPubkey: Uint8Array; // 32 bytes
    signature: Uint8Array;     // 64 bytes
  }): void {
    if (args.gatewayPubkey.length !== 32) {
      throw new Xb77Error(ErrorCode.InvalidInput, "verify_response: pubkey must be 32 bytes");
    }
    if (args.signature.length !== 64) {
      throw new Xb77Error(ErrorCode.InvalidInput, "verify_response: signature must be 64 bytes");
    }
    const bodyPtr = this.writeBytes(args.body);
    const pkPtr = this.writeBytes(args.gatewayPubkey);
    const sigPtr = this.writeBytes(args.signature);

    const rc = this.exports.verify_response(
      bodyPtr, args.body.length,
      args.expectedAction,
      BigInt(args.timestampUnix),
      pkPtr, 32,
      sigPtr, 64,
    );

    this.exports.wasm_free(bodyPtr, args.body.length);
    this.exports.wasm_free(pkPtr, 32);
    this.exports.wasm_free(sigPtr, 64);

    if (rc !== 0) throw new Xb77Error(rc, "verify_response");
  }
}

async function defaultLoadWasm(): Promise<Uint8Array> {
  // Node / Bun: read from co-located wasm/xb77_core.wasm
  // (Node typings are not a hard dep — wrapper works without @types/node.)
  if (typeof process !== "undefined" && (process as { versions?: { node?: string } }).versions?.node) {
    // @ts-ignore — node:fs/promises resolved at runtime in Node/Bun.
    const { readFile } = await import("node:fs/promises");
    // @ts-ignore — node:url resolved at runtime.
    const { fileURLToPath } = await import("node:url");
    // @ts-ignore — node:path resolved at runtime.
    const path = await import("node:path");
    const here = path.dirname(fileURLToPath(import.meta.url));
    // @ts-ignore — Node-only typing for path.resolve return.
    const candidates = [
      path.resolve(here, "../wasm/xb77_core.wasm"),
      path.resolve(here, "./wasm/xb77_core.wasm"),
      path.resolve(here, "../../../zig-out/bin/xb77_core.wasm"),
    ];
    for (const p of candidates) {
      try { return new Uint8Array(await readFile(p)); } catch {}
    }
    throw new Error(`[xB77] xb77_core.wasm not found in: ${candidates.join(", ")}`);
  }
  // Browser fallback: fetch from same-origin /xb77_core.wasm
  const res = await fetch("/xb77_core.wasm");
  if (!res.ok) throw new Error(`[xB77] failed to fetch xb77_core.wasm: ${res.status}`);
  return new Uint8Array(await res.arrayBuffer());
}
