const std = @import("std");
const semantic = @import("core").security.semantic;
const Semantic = semantic.Semantic;

test "Semantic Similarity - Fixed Point" {
    var v1 = [_]i32{0} ** Semantic.DIMENSIONS;
    var v2 = [_]i32{0} ** Semantic.DIMENSIONS;
    
    // Scale 10,000
    // Vector 1: [1.0, 0, ...] -> [10000, 0, ...]
    // Vector 2: [1.0, 0, ...] -> [10000, 0, ...]
    v1[0] = 10000;
    v2[0] = 10000;
    
    const sim = Semantic.cosineSimilarityFixed(v1, v2);
    // (10000 * 10000 * 10000) / (10000 * 10000) = 10000 (which is 1.0 in our scale)
    try std.testing.expectEqual(@as(i32, 10000), sim);
}

test "Semantic Similarity - Rejection Threshold" {
    const intent = [_]i32{1000} ** Semantic.DIMENSIONS;
    const blocked = [_]i32{1000} ** Semantic.DIMENSIONS;
    
    const similarity = Semantic.cosineSimilarityFixed(intent, blocked);
    // (1000 * 1000 * 128) / 10000 = 12800000 / 10000 = 12800
    // 12800 > 8000 threshold
    try std.testing.expect(similarity > 8000);
}
