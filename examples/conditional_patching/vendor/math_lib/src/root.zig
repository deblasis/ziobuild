//! A simple math library. Version 0.1.0 — written for Zig 0.15.x.
//!
//! This version uses `std.math.divTrunc` which was renamed in
//! Zig 0.16. A patch in patches/math_lib/fix-zig-0.16.patch fixes
//! the incompatibility.

pub fn add(a: i64, b: i64) i64 {
    return a + b;
}

pub fn div(a: i64, b: i64) !i64 {
    // This would break on Zig 0.16 — the patch fixes it to
    // use the correct API.
    return a / b;
}

pub const version = "0.1.0-patched";
