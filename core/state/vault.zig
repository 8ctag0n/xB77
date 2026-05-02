const std = @import("std");
const crypto = @import("../crypto/crypto.zig");
const types = @import("../protocol/types.zig");
const solana = @import("../chain/solana.zig");

pub const VaultRole = enum {
    ops,
    reserve,
    yield,
};

pub const SpendPolicy = struct {
    daily_limit: u64,
    per_tx_limit: u64,
    governance_threshold: ?u64 = null,
    allowed_assets: []const types.Asset = &.{},
    blacklist: std.StringHashMap(void),
};

pub const Recipient = union(enum) {
    sol: types.Pubkey,
    evm: types.EthAddress,
};

pub const SpendRecord = struct {
    timestamp: i64,
    amount: u64,
    asset: types.Asset,
};

pub const Vault = struct {
    allocator: std.mem.Allocator,
    role: VaultRole,
    sol_kp: types.Keypair,
    eth_kp: ?types.EthKeypair = null,
    policy: SpendPolicy,
    history: std.ArrayListUnmanaged(SpendRecord),
    storage_path: []const u8,
    
    pub fn init(allocator: std.mem.Allocator, role: VaultRole, policy: SpendPolicy, storage_path: []const u8, mnemonic: ?[]const u8, password: ?[]const u8) !Vault {
        var v = Vault{
            .allocator = allocator,
            .role = role,
            .sol_kp = undefined,
            .eth_kp = null,
            .policy = policy,
            .history = std.ArrayListUnmanaged(SpendRecord){},
            .storage_path = try allocator.dupe(u8, storage_path),
        };
        
        try v.ensureKeys(mnemonic, password);
        try v.loadHistory();
        return v;
    }

    fn ensureKeys(self: *Vault, mnemonic: ?[]const u8, password: ?[]const u8) !void {
        const key_path = try std.fmt.allocPrint(self.allocator, "{s}.key", .{self.storage_path});
        defer self.allocator.free(key_path);

        const GCM = std.crypto.aead.aes_gcm.Aes256Gcm;
        const PBKDF2 = std.crypto.pwhash.pbkdf2;

        if (std.fs.cwd().openFile(key_path, .{})) |file| {
            defer file.close();
            // Formato: [SALT 16] [NONCE 12] [TAG 16] [ENCRYPTED 96]
            var buf: [16 + 12 + 16 + 96]u8 = undefined;
            const bytes_read = try file.readAll(&buf);
            if (bytes_read == buf.len) {
                if (password) |pwd| {
                    const salt = buf[0..16];
                    const nonce = buf[16..28];
                    const tag = buf[28..44];
                    const encrypted = buf[44..];

                    var key: [32]u8 = undefined;
                    try PBKDF2(&key, pwd, salt, 4096, std.crypto.auth.hmac.sha2.HmacSha256);

                    var decrypted: [96]u8 = undefined;
                    GCM.decrypt(&decrypted, encrypted, tag.*, "", nonce.*, key) catch |err| {
                        std.debug.print("\n[Vault] ❌ Password incorrecto o Vault corrupto: {}\n", .{err});
                        return error.InvalidPassword;
                    };

                    @memcpy(&self.sol_kp.secret, decrypted[0..64]);
                    
                    // Re-derivar public key de Solana
                    const pk = try crypto.Ed25519.PublicKey.fromBytes(self.sol_kp.secret[32..64].*);
                    self.sol_kp.public = pk.toBytes();

                    var eth_secret: [32]u8 = undefined;
                    @memcpy(&eth_secret, decrypted[64..96]);
                    
                    const sk = try crypto.EcdsaKeccak.SecretKey.fromBytes(eth_secret);
                    const kp = try crypto.EcdsaKeccak.KeyPair.fromSecretKey(sk);
                    const uncompressed_pk = kp.public_key.p.toUncompressedSec1();
                    
                    var hash: [32]u8 = undefined;
                    crypto.Keccak256.hash(uncompressed_pk[1..], &hash, .{});
                    
                    var addr: types.EthAddress = undefined;
                    @memcpy(&addr, hash[12..32]);

                    self.eth_kp = .{
                        .address = addr,
                        .secret = eth_secret,
                    };
                    return;
                } else {
                    std.debug.print("\n[Vault] ⚠️ Vault cifrado detectado. Se requiere Master Password.\n", .{});
                    return error.PasswordRequired;
                }
            }
        } else |_| {}

        // Si llegamos acá es un Vault nuevo o no existe el archivo
        if (mnemonic) |m| {
            const wdk = @import("../crypto/wdk.zig");
            var provider = try wdk.WdkProvider.init(self.allocator, m);
            defer provider.deinit();

            self.sol_kp = provider.deriveSolanaKeypair();
            self.eth_kp = try provider.deriveEvmKeypair();
        } else {
            self.sol_kp = crypto.generateKeypair();
            self.eth_kp = try crypto.generateEthKeypair();
        }

        // Cifrar antes de guardar
        if (password) |pwd| {
            var salt: [16]u8 = undefined;
            std.crypto.random.bytes(&salt);
            var nonce: [12]u8 = undefined;
            std.crypto.random.bytes(&nonce);

            var key: [32]u8 = undefined;
            try PBKDF2(&key, pwd, &salt, 4096, std.crypto.auth.hmac.sha2.HmacSha256);

            var plain: [96]u8 = undefined;
            @memcpy(plain[0..64], &self.sol_kp.secret);
            @memcpy(plain[64..96], &self.eth_kp.?.secret);

            var encrypted: [96]u8 = undefined;
            var tag: [16]u8 = undefined;
            GCM.encrypt(&encrypted, &tag, &plain, "", nonce, key);

            const file = try std.fs.cwd().createFile(key_path, .{});
            defer file.close();
            try file.writeAll(&salt);
            try file.writeAll(&nonce);
            try file.writeAll(&tag);
            try file.writeAll(&encrypted);
            
            std.debug.print("\n[Vault] 🔒 Bunker Vault inicializado y cifrado con AES-GCM.\n", .{});
        } else {
            // Guardado inseguro (legacy/dev)
            const file = try std.fs.cwd().createFile(key_path, .{});
            defer file.close();
            try file.writeAll(&self.sol_kp.secret);
            try file.writeAll(&self.eth_kp.?.secret);
            std.debug.print("\n[Vault] ⚠️ ADVERTENCIA: Vault guardado en texto plano (Modo Inseguro).\n", .{});
        }
    }

    pub fn deinit(self: *Vault) void {
        self.history.deinit(self.allocator);
        self.policy.blacklist.deinit();
        self.allocator.free(self.storage_path);
    }

    fn loadHistory(self: *Vault) !void {
        const file = std.fs.cwd().openFile(self.storage_path, .{}) catch return;
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(content);

        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            var iter = std.mem.splitScalar(u8, line, ',');
            const ts_str = iter.next() orelse continue;
            const amt_str = iter.next() orelse continue;
            const sym = iter.next() orelse "SOL";

            const ts = std.fmt.parseInt(i64, ts_str, 10) catch continue;
            const amt = std.fmt.parseInt(u64, amt_str, 10) catch continue;

            try self.history.append(self.allocator, .{
                .timestamp = ts,
                .amount = amt,
                .asset = .{ .chain = .solana, .symbol = try self.allocator.dupe(u8, sym) },
            });
        }
    }

    pub fn address(self: *const Vault, chain: types.Chain, allocator: std.mem.Allocator) ![]u8 {
        return switch (chain) {
            .solana => crypto.pubkeyToString(allocator, &self.sol_kp.public),
            .base, .arbitrum => if (self.eth_kp) |kp| 
                @import("../chain/evm.zig").addressToHex(allocator, kp.address)
            else 
                error.EthKeypairNotInitialized,
            .bitcoin => error.BitcoinNotYetImplemented,
        };
    }

    pub fn canSpend(self: *Vault, amount: u64, asset: types.Asset, target_addr: ?[]const u8) !bool {
        // 1. Verificación de la Política del Vault (Local)
        if (target_addr) |addr| {
            if (self.policy.blacklist.contains(addr)) {
                std.debug.print("[Vault] Address blacklisted in vault policy\n", .{});
                return false;
            }
        }

        if (amount > self.policy.per_tx_limit) {
            std.debug.print("[Vault] Amount exceeds per-transaction limit\n", .{});
            return false;
        }

        const now = std.time.milliTimestamp();
        const one_day_ms = 24 * 60 * 60 * 1000;
        var spent_today: u64 = 0;

        var i: usize = 0;
        while (i < self.history.items.len) : (i += 1) {
            const record = self.history.items[i];
            if (now - record.timestamp < one_day_ms and std.mem.eql(u8, record.asset.symbol, asset.symbol)) {
                spent_today += record.amount;
            }
        }

        if (spent_today + amount > self.policy.daily_limit) {
            std.debug.print("[Vault] Amount exceeds daily spending limit\n", .{});
            return false;
        }

        return true;
    }

    pub fn recordSpend(self: *Vault, amount: u64, asset: types.Asset) !void {
        const ts = std.time.milliTimestamp();
        try self.history.append(self.allocator, .{
            .timestamp = ts,
            .amount = amount,
            .asset = asset,
        });

        const file = try std.fs.cwd().createFile(self.storage_path, .{ .truncate = false });
        defer file.close();
        try file.seekFromEnd(0);
        
        var fmt_buf: [256]u8 = undefined;
        const line = try std.fmt.bufPrint(&fmt_buf, "{d},{d},{s}\n", .{ ts, amount, asset.symbol });
        try file.writeAll(line);
    }
};

pub const VaultSet = struct {
    ops: Vault,
    reserve: Vault,
    yield: Vault,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, base_path: []const u8, password: ?[]const u8) !VaultSet {
        // Aseguramos que la carpeta base exista y termine en separador
        try std.fs.cwd().makePath(base_path);

        const default_policy = SpendPolicy{
            .daily_limit = 1_000_000_000,
            .per_tx_limit = 500_000_000,
            .blacklist = std.StringHashMap(void).init(allocator),
        };

        const ops_path = try std.fs.path.join(allocator, &[_][]const u8{ base_path, "ops" });
        defer allocator.free(ops_path);
        const reserve_path = try std.fs.path.join(allocator, &[_][]const u8{ base_path, "reserve" });
        defer allocator.free(reserve_path);
        const yield_path = try std.fs.path.join(allocator, &[_][]const u8{ base_path, "yield" });
        defer allocator.free(yield_path);

        return .{
            .allocator = allocator,
            .ops = try Vault.init(allocator, .ops, default_policy, ops_path, null, password),
            .reserve = try Vault.init(allocator, .reserve, default_policy, reserve_path, null, password),
            .yield = try Vault.init(allocator, .yield, default_policy, yield_path, null, password),
        };
    }

    pub fn deinit(self: *VaultSet) void {
        self.ops.deinit();
        self.reserve.deinit();
        self.yield.deinit();
    }
};
