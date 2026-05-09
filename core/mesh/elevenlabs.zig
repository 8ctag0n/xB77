const std = @import("std");
const http = @import("../mesh/http.zig");

pub const VoiceClient = struct {
    allocator: std.mem.Allocator,
    api_key: []const u8,
    voice_id: []const u8,

    pub fn init(allocator: std.mem.Allocator, api_key: []const u8, voice_id: []const u8) VoiceClient {
        return .{
            .allocator = allocator,
            .api_key = api_key,
            .voice_id = voice_id,
        };
    }

    pub fn textToSpeech(self: *VoiceClient, text: []const u8) ![]const u8 {
        var client = http.HttpClient.init(self.allocator);
        // HttpClient has no deinit

        const url = try std.fmt.allocPrint(self.allocator, "https://api.elevenlabs.io/v1/text-to-speech/{s}", .{self.voice_id});
        defer self.allocator.free(url);

        // Build request body (JSON)
        var body = std.ArrayList(u8).init(self.allocator);
        defer body.deinit();
        try body.writer().print("{any}", .{std.json.fmt(.{
            .text = text,
            .model_id = "eleven_monolingual_v1",
            .voice_settings = .{
                .stability = 0.5,
                .similarity_boost = 0.5,
            },
        }, .{})});

        std.debug.print("[VOICE]  Generating sovereign voice for: \"{s}\" (ElevenLabs)...\n", .{text});
        
        var response = try client.post(url, body.items);
        defer response.deinit();

        return try self.allocator.dupe(u8, response.body);
    }
};
