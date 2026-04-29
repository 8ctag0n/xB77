const std = @import("std");
const crypto = @import("../crypto/crypto.zig");
const bn254 = @import("../crypto/bn254.zig");
const poseidon = @import("../crypto/poseidon.zig");
const types = @import("../protocol/types.zig");

const Fr = bn254.Fr;
const Poseidon = poseidon.Poseidon;

/// Sovereign Identity: Privacidad ZK para agentes y usuarios en la Mesh.
/// Permite operar con un "Alias" generado via Poseidon sin revelar la Pubkey real.
pub const Identity = struct {
    pub const Alias = [32]u8;

    /// Genera un Alias ZK a partir de una Pubkey y un secreto (salt).
    /// Alias = Poseidon(Pubkey_Bytes, Secret_Salt)
    pub fn createAlias(pubkey: types.Pubkey, salt: u256) Alias {
        // Convertimos la Pubkey (32 bytes) a un Field Element (u256)
        const pk_u256 = @as(u256, @bitCast(pubkey));
        
        // H(pk, salt)
        const hash_val = Poseidon.hash2(pk_u256, salt);
        
        return @bitCast(hash_val);
    }

    /// Genera un Nullifier para una transacción específica.
    /// Útil para probar que sos el dueño del Alias sin revelar el secreto.
    pub fn computeNullifier(secret: u256, context_id: u256) u256 {
        return Poseidon.hash2(secret, context_id);
    }
};
