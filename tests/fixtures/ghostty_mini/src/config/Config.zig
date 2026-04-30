//! Configuration types for the terminal emulator.
//! Mirrors ghostty's src/config/ pattern.

host: []const u8 = "127.0.0.1",
port: u16 = 8080,
verbose: bool = false,
max_scrollback: u32 = 10000,
font_size: f32 = 13.0,
theme: []const u8 = "dark",
cursor_blink: bool = true,
shell: []const u8 = "/bin/bash",
term: []const u8 = "xterm-256color",

pub const Runtime = enum { native, none, wasm };

pub fn validate(self: @This()) !void {
    if (self.port == 0) return error.InvalidPort;
    if (self.font_size <= 0) return error.InvalidFontSize;
    if (self.max_scrollback > 1_000_000) return error.InvalidScrollback;
}
