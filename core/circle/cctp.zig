const std = @import("std");
const circle = @import("circle.zig");

pub const AttestationResponse = struct {
    status: []const u8,
    attestation: ?[]const u8 = null,
};

pub fn getAttestation(client: *circle.CircleClient, message_hash: []const u8) !AttestationResponse {
    // Iris API (CCTP Attestation) usually has its own domain
    const iris_url = try std.fmt.allocPrint(client.allocator, "https://iris-api-sandbox.circle.com/attestations/{s}", .{message_hash});
    defer client.allocator.free(iris_url);

    var response = try client.http_client.get(iris_url);
    defer response.deinit();

    if (response.status != 200) return error.ApiError;

    const parsed = try std.json.parseFromSlice(std.json.Value, client.allocator, response.body, .{});
    defer parsed.deinit();

    const status = parsed.value.object.get("status").?.string;
    const attestation = if (parsed.value.object.get("attestation")) |a| try client.allocator.dupe(u8, a.string) else null;

    return AttestationResponse{
        .status = try client.allocator.dupe(u8, status),
        .attestation = attestation,
    };
}
