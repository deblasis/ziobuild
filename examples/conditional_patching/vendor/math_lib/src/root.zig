//! A small vendored math library, version 0.1.0.
//!
//! This file is committed in its pristine state. Building the example
//! applies patches/math_lib/bump-version.patch on top of it, which
//! rewrites the version string below. The patch edits this file in
//! place, so a build leaves your working tree dirty. That is what
//! ctx.patch() does.

pub fn add(a: i64, b: i64) i64 {
    return a + b;
}

pub fn div(a: i64, b: i64) !i64 {
    return a / b;
}

pub const version = "0.1.0";
