const std = @import("std");

pub fn spawn(shell: []const u8) !void {
    if (shell.len == 0) return error.EmptyShell;
}

test "spawn rejects empty shell" {
    try std.testing.expectError(error.EmptyShell, spawn(""));
}
