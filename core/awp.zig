const std = @import("std");
const types = @import("types.zig");
const crypto = @import("crypto.zig");
pub const awp = @import("awp"); // Importamos el paquete universal

/// Puente (Bridge) entre el Core de xB77 y el Paquete AWP Universal.
/// Mantiene la compatibilidad con el código existente mientras usa el módulo independiente.

pub const MessageType = awp.MessageType;
pub const Side = awp.Side;
pub const OrderMsg = awp.OrderMsg;
pub const HandshakeMsg = awp.HandshakeMsg;
pub const SignalType = awp.SignalType;
pub const SignalMsg = awp.SignalMsg;
pub const TransferMsg = awp.TransferMsg;

pub const AwpEncoder = awp.AwpEncoder;
pub const AwpDecoder = awp.AwpDecoder;

/// Convierte un Asset del Core al formato AWP
pub fn toAwpAsset(core_asset: types.Asset) awp.Asset {
    return .{
        .chain = @enumFromInt(@intFromEnum(core_asset.chain) + 1), // Mapeo de enum core (0-indexed) a AWP (1-indexed)
        .symbol = core_asset.symbol,
    };
}

/// Convierte una cadena de AWP al formato Core
pub fn fromAwpChain(awp_chain: awp.Chain) types.Chain {
    return @enumFromInt(@intFromEnum(awp_chain) - 1);
}

/// Convierte una cadena del Core al formato AWP
pub fn toAwpChain(core_chain: types.Chain) awp.Chain {
    return @enumFromInt(@intFromEnum(core_chain) + 1);
}
