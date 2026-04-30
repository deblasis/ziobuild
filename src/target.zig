//! Cross-compile target presets and the escape hatch into raw
//! `std.Target.Query`. Used by `Context.releases` to produce one
//! executable per target without forcing the caller to spell out
//! cpu/os/abi triples.

const std = @import("std");

/// A small, opinionated set of release targets that covers the common
/// shipping matrix. Pair with `releases(.{ .targets = &.{ .linux_x64, ... } })`.
/// For anything outside this set, use `CustomTarget`.
pub const Target = enum {
    linux_x64,
    linux_arm64,
    darwin_x64,
    darwin_arm64,
    windows_x64,
    windows_arm64,

    /// Map a `Target` to a concrete `std.Target.Query`. Defaults to
    /// `gnu` on Linux, `musl` is left as a future toggle. macOS uses
    /// the `none` abi that std picks. Windows uses `gnu` to keep the
    /// build hermetic on CI runners that lack a Visual Studio
    /// toolchain. Callers that need a different abi can use
    /// `CustomTarget`.
    pub fn query(self: Target) std.Target.Query {
        return switch (self) {
            .linux_x64 => .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
            .linux_arm64 => .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .gnu },
            .darwin_x64 => .{ .cpu_arch = .x86_64, .os_tag = .macos },
            .darwin_arm64 => .{ .cpu_arch = .aarch64, .os_tag = .macos },
            .windows_x64 => .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu },
            .windows_arm64 => .{ .cpu_arch = .aarch64, .os_tag = .windows, .abi = .gnu },
        };
    }

    /// Stable directory name used under `zig-out/release/<dir>/`.
    pub fn dirName(self: Target) []const u8 {
        return switch (self) {
            .linux_x64 => "linux-x86_64",
            .linux_arm64 => "linux-aarch64",
            .darwin_x64 => "macos-x86_64",
            .darwin_arm64 => "macos-aarch64",
            .windows_x64 => "windows-x86_64",
            .windows_arm64 => "windows-aarch64",
        };
    }
};

/// Escape hatch for advanced cases: pass a fully-formed
/// `std.Target.Query` plus a stable directory name.
pub const CustomTarget = struct {
    /// Stable directory name under `zig-out/release/<name>/`.
    name: []const u8,
    /// Raw target query.
    query: std.Target.Query,
};

test "Target.query: linux_x64 maps to x86_64-linux-gnu" {
    const q = Target.linux_x64.query();
    try std.testing.expectEqual(std.Target.Cpu.Arch.x86_64, q.cpu_arch.?);
    try std.testing.expectEqual(std.Target.Os.Tag.linux, q.os_tag.?);
    try std.testing.expectEqual(std.Target.Abi.gnu, q.abi.?);
}

test "Target.query: darwin_arm64 maps to aarch64-macos" {
    const q = Target.darwin_arm64.query();
    try std.testing.expectEqual(std.Target.Cpu.Arch.aarch64, q.cpu_arch.?);
    try std.testing.expectEqual(std.Target.Os.Tag.macos, q.os_tag.?);
}

test "Target.query: windows_x64 maps to x86_64-windows-gnu" {
    const q = Target.windows_x64.query();
    try std.testing.expectEqual(std.Target.Cpu.Arch.x86_64, q.cpu_arch.?);
    try std.testing.expectEqual(std.Target.Os.Tag.windows, q.os_tag.?);
    try std.testing.expectEqual(std.Target.Abi.gnu, q.abi.?);
}

test "Target.dirName: every variant has a non-empty name" {
    inline for (std.meta.fields(Target)) |f| {
        const t: Target = @field(Target, f.name);
        const name = t.dirName();
        try std.testing.expect(name.len > 0);
    }
}

test "Target.dirName: stable for known variants" {
    try std.testing.expectEqualStrings("linux-x86_64", Target.linux_x64.dirName());
    try std.testing.expectEqualStrings("macos-aarch64", Target.darwin_arm64.dirName());
    try std.testing.expectEqualStrings("windows-x86_64", Target.windows_x64.dirName());
}
