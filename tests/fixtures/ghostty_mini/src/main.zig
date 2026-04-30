const std = @import("std");
const config_mod = @import("config/root.zig");
const terminal = @import("terminal/main.zig");
const renderer = @import("renderer/main.zig");
const font = @import("font/main.zig");
const pty = @import("pty/main.zig");

pub fn main() !void {
    const cfg = config_mod.Config{};
    try cfg.validate();
    renderer.init(.opengl);
    try pty.spawn(cfg.shell);
    std.debug.print("ghostty-mini running on {s}:{d}\n", .{ cfg.host, cfg.port });
}

test "app validates default config" {
    const cfg = config_mod.Config{};
    try cfg.validate();
}

test "font rasterizes" {
    const g = font.rasterize('X');
    try std.testing.expectEqual(@as(u32, 'X'), g.codepoint);
}

test "renderer backend enum" {
    const backends = [_]renderer.Backend{ .opengl, .metal, .vulkan, .wasm };
    try std.testing.expect(backends.len == 4);
}
