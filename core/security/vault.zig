const std = @import("std");
const crypto = @import("../security/crypto.zig");
const types = @import("../protocol/types.zig");
const solana = @import("../chain/solana.zig");
const keystore = @import("../keystore/keystore.zig");

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
            .history = std.ArrayListUnmanaged(SpendRecord).empty,
            .storage_path = try allocator.dupe(u8, storage_path),
        };
        errdefer allocator.free(v.storage_path);
        
        try v.ensureKeys(mnemonic, password);
        try v.loadHistory();
        return v;
    }

    fn ensureKeys(self: *Vault, mnemonic: ?[]const u8, password: ?[]const u8) !void {
        const key_path = try std.fmt.allocPrint(self.allocator, "{s}.key", .{self.storage_path});
        defer self.allocator.free(key_path);

        const PLAIN_LEN: usize = 96; // sol_secret[64] || eth_secret[32]
        const BLOB_LEN: usize = PLAIN_LEN + keystore.SEAL_OVERHEAD; // 140

        if (std.Io.Dir.cwd().openFile(std.Io.Threaded.global_single_threaded.io(), key_path, .{})) |file| {
            defer file.close(std.Io.Threaded.global_single_threaded.io());
            var buf: [BLOB_LEN]u8 = undefined;
            var read_tmp: [1024]u8 = undefined;
            var r = file.reader(std.Io.Threaded.global_single_threaded.io(), &read_tmp);
            try r.interface.readSliceAll(&buf);
            const bytes_read = buf.len; // readSliceAll returns void on success
            if (bytes_read == buf.len) {
                if (password) |pwd| {
                    var decrypted: [PLAIN_LEN]u8 = undefined;
                    keystore.unseal(&buf, pwd, &decrypted) catch |err| {
                        std.debug.print("\n[Vault]  Password incorrecto o Vault corrupto: {}\n", .{err});
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
                    std.debug.print("\n[Vault] ️ Vault cifrado detectado. Se requiere Master Password.\n", .{});
                    return error.PasswordRequired;
                }
            }
        } else |_| {}

        // Si llegamos acá es un Vault nuevo o no existe el archivo
        if (mnemonic) |m| {
            const wdk = @import("../security/wdk.zig");
            var provider = try wdk.WdkProvider.init(self.allocator, m);
            defer provider.deinit();

            self.sol_kp = provider.deriveSolanaKeypair();
            self.eth_kp = try provider.deriveEvmKeypair();
        } else {
            self.sol_kp = crypto.generateKeypair();
            self.eth_kp = try crypto.generateEthKeypair();
        }

        if (password) |pwd| {
            var plain: [PLAIN_LEN]u8 = undefined;
            @memcpy(plain[0..64], &self.sol_kp.secret);
            @memcpy(plain[64..96], &self.eth_kp.?.secret);

            var blob: [BLOB_LEN]u8 = undefined;
            try keystore.seal(&plain, pwd, &blob);

            const file = try std.Io.Dir.cwd().createFile(std.Io.Threaded.global_single_threaded.io(), key_path, .{});
            defer file.close(std.Io.Threaded.global_single_threaded.io());
            try file.writeStreamingAll(std.Io.Threaded.global_single_threaded.io(), &blob);

            std.debug.print("\n[Vault]  Bunker Vault inicializado y cifrado con AES-GCM.\n", .{});
        } else {
            // En modo Deluxe, la soberanía requiere responsabilidad.
            // Prohibimos el guardado en texto plano para proteger al usuario.
            std.debug.print("\n[Vault] ️ ERROR CRÍTICO: No se puede inicializar el Vault sin un Master Password.\n", .{});
            std.debug.print("         La seguridad es obligatoria en el protocolo xB77.\n", .{});
            return error.EncryptionRequired;
        }
    }

    pub fn deinit(self: *Vault) void {
        for (self.history.items) |record| {
            self.allocator.free(record.asset.symbol);
        }
        self.history.deinit(self.allocator);
        self.policy.blacklist.deinit();
        self.allocator.free(self.storage_path);
    }

    fn loadHistory(self: *Vault) !void {
        const file = std.Io.Dir.cwd().openFile(std.Io.Threaded.global_single_threaded.io(), self.storage_path, .{}) catch return;
        defer file.close(std.Io.Threaded.global_single_threaded.io());

        var read_buf: [1024]u8 = undefined;
        var r_interface = file.reader(std.Io.Threaded.global_single_threaded.io(), &read_buf).interface; const content = try r_interface.allocRemaining(self.allocator, .unlimited);
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
            .arc => try allocator.dupe(u8, "0x7777...arc"), // Mock for demo
            .sui => try allocator.dupe(u8, "0x7777...sui"), // Mock for demo
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

        const now = std.Io.Timestamp.now(std.Io.Threaded.global_single_threaded.io(), .real).toMilliseconds();
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
        const ts = std.Io.Timestamp.now(std.Io.Threaded.global_single_threaded.io(), .real).toMilliseconds();
        try self.history.append(self.allocator, .{
            .timestamp = ts,
            .amount = amount,
            .asset = .{ .chain = asset.chain, .symbol = try self.allocator.dupe(u8, asset.symbol) },
        });

        const file = try std.Io.Dir.cwd().createFile(std.Io.Threaded.global_single_threaded.io(), self.storage_path, .{ .truncate = false });
        defer file.close(std.Io.Threaded.global_single_threaded.io());
        var fmt_buf: [256]u8 = undefined;
        const line = try std.fmt.bufPrint(&fmt_buf, "{d},{d},{s}\n", .{ ts, amount, asset.symbol });
        const vault_end = try file.length(std.Io.Threaded.global_single_threaded.io());
        try std.Io.File.writePositionalAll(file, std.Io.Threaded.global_single_threaded.io(), line, vault_end);
    }
};

pub const VaultSet = struct {
    ops: Vault,
    reserve: Vault,
    yield: Vault,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, base_path: []const u8, password: ?[]const u8) !VaultSet {
        // Aseguramos que la carpeta base exista y termine en separador
        try std.Io.Dir.cwd().createDirPath(std.Io.Threaded.global_single_threaded.io(), base_path);

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

/// True when XB77_DEMO is set. Used only to suppress cosmetic WARN/ERR
/// log lines that would otherwise pollute the cinematic demo. Real errors
/// keep propagating via return values.
fn isQuietMode(allocator: std.mem.Allocator) bool {
    _ = allocator;
    return std.c.getenv("XB77_DEMO") != null;
}
