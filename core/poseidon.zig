const std = @import("std");
const bn254 = @import("bn254.zig");
const Fr = bn254.Fr;
const constants = @import("poseidon_constants.zig");

pub const Poseidon = struct {
    pub const T = 3;
    pub const RF = 8;
    pub const RP = 57;

    state: [T]Fr,

    pub fn hash2(in0: u256, in1: u256) u256 {
        var p = Poseidon{
            .state = .{
                Fr.fromInt(0),
                Fr.fromInt(in0),
                Fr.fromInt(in1),
            },
        };

        var round: usize = 0;

        // Full rounds
        for (0..RF / 2) |_| {
            p.fullRound(&round);
        }

        // Partial rounds
        for (0..RP) |_| {
            p.partialRound(&round);
        }

        // Full rounds
        for (0..RF / 2) |_| {
            p.fullRound(&round);
        }

        return p.state[0].toInt();
    }

    fn fullRound(self: *Poseidon, round: *usize) void {
        for (0..T) |i| {
            self.state[i] = self.state[i].add(Fr.fromInt(constants.ROUND_CONSTANTS[round.* * T + i]));
        }
        for (0..T) |i| {
            self.state[i] = self.state[i].sbox();
        }
        self.mix();
        round.* += 1;
    }

    fn partialRound(self: *Poseidon, round: *usize) void {
        for (0..T) |i| {
            self.state[i] = self.state[i].add(Fr.fromInt(constants.ROUND_CONSTANTS[round.* * T + i]));
        }
        // En Circomlib/Noir, el S-box se aplica solo al primer elemento en las rondas parciales
        self.state[0] = self.state[0].sbox();
        self.mix();
        round.* += 1;
    }

    fn mix(self: *Poseidon) void {
        var new_state: [T]Fr = undefined;
        for (0..T) |i| {
            var sum = Fr.ZERO;
            for (0..T) |j| {
                const m = Fr.fromInt(constants.MDS_MATRIX[i][j]);
                sum = sum.add(m.mul(self.state[j]));
            }
            new_state[i] = sum;
        }
        self.state = new_state;
    }
};
