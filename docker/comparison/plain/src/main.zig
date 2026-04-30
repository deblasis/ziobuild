const std = @import("std");

pub const Config = struct {
    host: []const u8,
    port: u16,
    verbose: bool,

    pub fn default() Config {
        return .{
            .host = "127.0.0.1",
            .port = 8080,
            .verbose = false,
        };
    }
};

pub fn run(config: Config, writer: anytype) !void {
    try writer.print("Server listening on {s}:{d} (verbose={})\n", .{
        config.host,
        config.port,
        config.verbose,
    });
}

test "Config.default has expected values" {
    const c = Config.default();
    try std.testing.expectEqualStrings("127.0.0.1", c.host);
    try std.testing.expectEqual(@as(u16, 8080), c.port);
    try std.testing.expectEqual(false, c.verbose);
}

test "run prints server info" {
    var buf: [256]u8 = undefined;
    var w = std.Io.Writer.fixed(&buf);
    try run(.default(), &w);
    try std.testing.expect(std.mem.indexOf(u8, buf[0..w.end], "127.0.0.1:8080") != null);
}
