const std = @import("std");
const http = @import("http.zig");

// --- xB77 Sovereign Experience: ElevenLabs Voice Integration ---
// This module provides voice synthesis for the Agent Gateway.
// It allows the agent to communicate with the operator using high-fidelity AI voices.

pub const VoiceClient = struct {
    allocator: std.mem.Allocator,
    api_key: []const u8,
    voice_id: []const u8, // e.g., "Cyberpunk Narrator"

    pub fn init(allocator: std.mem.Allocator, api_key: []const u8, voice_id: []const u8) VoiceClient {
        return .{
            .allocator = allocator,
            .api_key = api_key,
            .voice_id = voice_id,
        };
    }

    pub fn textToSpeech(self: *VoiceClient, text: []const u8) ![]const u8 {
        var client = http.HttpClient.init(self.allocator);
        defer client.deinit();

        const url = try std.fmt.allocPrint(self.allocator, "https://api.elevenlabs.io/v1/text-to-speech/{s}", .{self.voice_id});
        defer self.allocator.free(url);

        // Build request body (JSON)
        var list = std.ArrayList(u8).init(self.allocator);
        defer list.deinit();
        try list.writer().print("{any}", .{std.json.fmt(.{
            .text = text,
            .model_id = "eleven_monolingual_v1",
            .voice_settings = .{
                .stability = 0.5,
                .similarity_boost = 0.5,
            },
        }, .{})});

        // Set XI-API-KEY Header (Assuming HttpClient supports headers or using a raw request)
        // For the purpose of the real demo, we ensure the client is configured.
        client.setExtraHeader("xi-api-key", self.api_key);
        
        std.debug.print("[VOICE]  Generating sovereign voice for: \"{s}\" (ElevenLabs)...\n", .{text});
        
        const response = try client.post(url, list.items);
        return response; // Devuelve el MP3 binario
    }
};
