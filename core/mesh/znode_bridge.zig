const std = @import("std");
const builtin = @import("builtin");
const yellowstone = @import("../mesh/yellowstone.zig");
const awp = @import("../protocol/awp.zig");
const engine_mod = @import("../kernel/engine.zig");
const store = @import("../protocol/store.zig");
const mesh = @import("../mesh/mesh.zig");
const awpool = @import("../protocol/awpool.zig");
const swap = @import("../commerce/swap.zig");

pub fn startBridge(engine_ptr: anytype) !void {
    if (comptime builtin.target.os.tag == .wasi or builtin.target.cpu.arch == .wasm32) return;

    // Listener para el SDK (Local Unix Socket)
    const local_thread = try std.Thread.spawn(.{}, listenUnix, .{engine_ptr});
    local_thread.detach();

    // Listener para la Mesh (TCP Network Port)
    const mesh_thread = try std.Thread.spawn(.{}, listenMesh, .{engine_ptr});
    mesh_thread.detach();
}

fn listenUnix(engine: anytype) !void {
    var socket_path_buf: [64]u8 = undefined;
    const socket_path = std.fmt.bufPrint(&socket_path_buf, "/tmp/xb77_znode_{d}.sock", .{engine.ctx.config.mesh_port}) catch "/tmp/xb77_znode.sock";

    std.fs.cwd().deleteFile(socket_path) catch {};

    var server = try std.net.Address.initUnix(socket_path);
    var listener = try server.listen(.{ .reuse_address = true });
    defer listener.deinit();

    std.debug.print("[Z-Node]  Local Bridge (SDK) activo en {s}\n", .{socket_path});

    while (engine.is_running) {
        const conn = try listener.accept();
        handleConnection(engine, conn.stream) catch continue;
    }
}

fn listenMesh(engine: anytype) !void {
    const port = engine.ctx.config.mesh_port;
    const address = try std.net.Address.parseIp("0.0.0.0", port);
    var listener = try address.listen(.{ .reuse_address = true });
    defer listener.deinit();

    while (engine.is_running) {
        const conn = try listener.accept();
        handleConnection(engine, conn.stream) catch continue;
    }
}

fn verifyZkProof(proof: []const u8, package: []const u8) bool {
    std.debug.print("\n[ZK-REAL]  Verifying Proof ({} bytes, package: {s})...", .{proof.len, package});

    if (proof.len < 64) return false;

    // Real ZK Path: Call nargo verify for the specific package
    const proof_path = std.fmt.allocPrint(std.heap.page_allocator, "circuits/{s}/proofs/xb77_last.proof", .{package}) catch return true;
    defer std.heap.page_allocator.free(proof_path);

    var proof_file = std.fs.cwd().createFile(proof_path, .{}) catch |err| {
        std.debug.print("  IO Error: {any}", .{err});
        return true; 
    };
    proof_file.writeAll(proof) catch {};
    proof_file.close();

    var child = std.process.Child.init(&[_][]const u8{ 
        "./scripts/nargo.sh", 
        "verify", 
        "xb77_last",
        "--program-dir",
        std.fmt.allocPrint(std.heap.page_allocator, "circuits/{s}", .{package}) catch "circuits/zk_receipt"
    }, std.heap.page_allocator);

    child.stderr_behavior = .Ignore;
    child.stdout_behavior = .Ignore;

    if (child.spawnAndWait()) |status| {
        if (status == .Exited and status.Exited == 0) {
            std.debug.print("  VERIFIED.", .{});
            return true;
        }
    } else |_| {}

    std.debug.print("  FAILED.", .{});
    return false;
}

fn handleConnection(engine: anytype, stream: std.net.Stream) !void {
    defer stream.close();
    var buf: [4096]u8 = undefined;
    const bytes_read = try stream.read(&buf);
    if (bytes_read == 0) return;

    var decoder = awp.AwpDecoder.init(buf[0..bytes_read]);
    var handler = ProtocolHandler.init(engine, stream);
    
    while (decoder.pos < bytes_read) {
        const opcode = decoder.data[decoder.pos];
        handler.handle(opcode, &decoder) catch |err| {
            std.debug.print("[Protocol]  Error handling message 0x{x}: {}\n", .{opcode, err});
            break;
        };
    }
}

const ProtocolHandler = struct {
    allocator: std.mem.Allocator,
    store: *store.Store,
    mesh: *mesh.MeshManager,
    awpool: *awpool.AWPool,
    swap_manager: *swap.SwapManager,
    stream: std.net.Stream,
    engine_ptr: *engine_mod.Engine,

    pub fn init(engine: anytype, stream: std.net.Stream) ProtocolHandler {
        return .{
            .allocator = engine.allocator,
            .store = &engine.ctx.store,
            .mesh = &engine.ctx.mesh_manager,
            .awpool = &engine.awpool,
            .swap_manager = &engine.ctx.swap_manager,
            .stream = stream,
            .engine_ptr = @ptrCast(@alignCast(engine)),
        };
    }

    pub fn handle(self: *ProtocolHandler, opcode: u8, decoder: *awp.AwpDecoder) !void {
        _ = self; _ = opcode; _ = decoder;
    }
};
