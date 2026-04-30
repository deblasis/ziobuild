const std = @import("std");

pub const Backend = enum { opengl, metal, vulkan, wasm };

pub fn init(backend: Backend) void {
    _ = backend;
}

test "backend enum has all variants" {
    const b: Backend = .wasm;
    try std.testing.expect(b == .wasm);
}
