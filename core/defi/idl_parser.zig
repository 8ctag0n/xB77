const std = @import("std");

/// Representa una cuenta requerida por una instrucción de Solana
pub const IdlAccount = struct {
    name: []const u8,
    is_mut: bool,
    is_signer: bool,
    desc: ?[]const u8 = null,
};

/// Representa un argumento (parámetro) de una instrucción
pub const IdlArg = struct {
    name: []const u8,
    type_str: []const u8, // Simplificado a string (ej. "u64", "publicKey")
};

/// Representa una instrucción dentro del contrato inteligente
pub const IdlInstruction = struct {
    name: []const u8,
    accounts: []const IdlAccount,
    args: []const IdlArg,
};

/// El motor de Ingesta Dinámica de IDLs
pub const IdlParser = struct {
    allocator: std.mem.Allocator,
    program_name: []const u8,
    instructions: std.ArrayListUnmanaged(IdlInstruction),

    pub fn init(allocator: std.mem.Allocator, name: []const u8) IdlParser {
        return .{
            .allocator = allocator,
            .program_name = name,
            .instructions = std.ArrayListUnmanaged(IdlInstruction).empty,
        };
    }

    pub fn deinit(self: *IdlParser) void {
        for (self.instructions.items) |ix| {
            self.allocator.free(ix.accounts);
            self.allocator.free(ix.args);
        }
        self.instructions.deinit(self.allocator);
    }

    /// Parsea un JSON crudo de un IDL de Anchor/Solana
    pub fn parseJson(self: *IdlParser, json_data: []const u8) !void {
        const parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, json_data, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        const root = parsed.value.object;
        
        // Extraer instrucciones
        if (root.get("instructions")) |ixs_val| {
            if (ixs_val == .array) {
                for (ixs_val.array.items) |ix_val| {
                    if (ix_val != .object) continue;
                    const ix_obj = ix_val.object;
                    
                    const name = ix_obj.get("name").?.string;
                    
                    // Parsear Accounts
                    var accounts = std.ArrayList(IdlAccount).init(self.allocator);
                    defer accounts.deinit();
                    if (ix_obj.get("accounts")) |accs_val| {
                        if (accs_val == .array) {
                            for (accs_val.array.items) |acc_val| {
                                const acc_obj = acc_val.object;
                                try accounts.append(.{
                                    .name = try self.allocator.dupe(u8, acc_obj.get("name").?.string),
                                    .is_mut = acc_obj.get("isMut").?.bool,
                                    .is_signer = acc_obj.get("isSigner").?.bool,
                                });
                            }
                        }
                    }

                    // Parsear Args
                    var args = std.ArrayList(IdlArg).init(self.allocator);
                    defer args.deinit();
                    if (ix_obj.get("args")) |args_val| {
                        if (args_val == .array) {
                            for (args_val.array.items) |arg_val| {
                                const arg_obj = arg_val.object;
                                // Simplificación: guardamos el tipo como string para el LLM
                                try args.append(.{
                                    .name = try self.allocator.dupe(u8, arg_obj.get("name").?.string),
                                    .type_str = try self.allocator.dupe(u8, "type"), 
                                });
                            }
                        }
                    }

                    try self.instructions.append(self.allocator, .{
                        .name = try self.allocator.dupe(u8, name),
                        .accounts = try accounts.toOwnedSlice(),
                        .args = try args.toOwnedSlice(),
                    });
                }
            }
        }
    }

    /// Genera un "Contexto LLM-Friendly" para que Gemma/QVAC entienda el protocolo
    pub fn generateLlmContext(self: *const IdlParser) ![]const u8 {
        var buf = std.ArrayListUnmanaged(u8).empty;
        const writer = buf.writer(self.allocator);

        try writer.print("PROTOCOL: {s}\n", .{self.program_name});
        try writer.print("AVAILABLE INSTRUCTIONS:\n", .{});

        for (self.instructions.items) |ix| {
            try writer.print("- {s} (", .{ix.name});
            for (ix.args, 0..) |arg, i| {
                if (i > 0) try writer.print(", ", .{});
                try writer.print("{s}: {s}", .{arg.name, arg.type_str});
            }
            try writer.print(")\n  ACCOUNTS REQUIRED:\n", .{});
            
            for (ix.accounts) |acc| {
                const mut_str = if (acc.is_mut) "MUTABLE" else "READONLY";
                const sig_str = if (acc.is_signer) "SIGNER" else "NON-SIGNER";
                try writer.print("    * {s} [{s}, {s}]\n", .{acc.name, mut_str, sig_str});
            }
        }

        return buf.toOwnedSlice(self.allocator);
    }
};
