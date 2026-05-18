//! Composable build-time expressions. Leaf constructors create
//! primitive predicates (version checks, target OS, etc.). Combinator
//! methods compose them with logical AND/OR/NOT. Evaluation is
//! performed against a `Context`.

const std = @import("std");

pub const Cmp = enum {
    lt,
    lte,
    eq,
    gte,
    gt,
    neq,
};

pub const Expr = union(enum) {
    zig_version: struct { cmp: Cmp, version: []const u8 },
    target_os: std.Target.Os.Tag,
    target_arch: std.Target.Cpu.Arch,
    optimize_mode: std.builtin.OptimizeMode,
    env_var: struct { key: []const u8, value: []const u8 },
    @"and": struct { left: *Expr, right: *Expr },
    @"or": struct { left: *Expr, right: *Expr },
    negate: *Expr,
    always: bool,

    /// True when the Zig compiler version satisfies the comparison.
    pub fn zigVersion(cmp: Cmp, version: []const u8) Expr {
        return .{ .zig_version = .{ .cmp = cmp, .version = version } };
    }

    /// True when the resolved target OS matches.
    pub fn targetOs(os: std.Target.Os.Tag) Expr {
        return .{ .target_os = os };
    }

    /// True when the resolved target arch matches.
    pub fn targetArch(arch: std.Target.Cpu.Arch) Expr {
        return .{ .target_arch = arch };
    }

    /// True when the optimize mode matches.
    pub fn optimizeMode(mode: std.builtin.OptimizeMode) Expr {
        return .{ .optimize_mode = mode };
    }

    /// True when environment variable `key` equals `value`.
    /// Uses `std.process.getEnvVarOwned` at evaluation time.
    pub fn envVar(key: []const u8, value: []const u8) Expr {
        return .{ .env_var = .{ .key = key, .value = value } };
    }

    /// Always true or always false.
    pub fn literal(val: bool) Expr {
        return .{ .always = val };
    }

    /// Evaluate this expression against build state. Returns `true`
    /// if the condition holds.
    pub fn evaluate(self: Expr, b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) bool {
        switch (self) {
            .always => |val| return val,

            .zig_version => |v| {
                const current = @import("builtin").zig_version;
                const required = std.SemanticVersion.parse(v.version) catch @panic(
                    b.fmt("ziobuild: invalid version string '{s}' in Expr.zigVersion", .{v.version}),
                );
                const ord = current.order(required);
                return switch (v.cmp) {
                    .lt => ord == .lt,
                    .lte => ord != .gt,
                    .eq => ord == .eq,
                    .gte => ord != .lt,
                    .gt => ord == .gt,
                    .neq => ord != .eq,
                };
            },

            .target_os => |os| return target.result.os.tag == os,
            .target_arch => |arch| return target.result.cpu.arch == arch,
            .optimize_mode => |mode| return optimize == mode,

            .env_var => |ev| {
                const val = b.graph.environ_map.get(ev.key) orelse return false;
                return std.mem.eql(u8, val, ev.value);
            },

            .@"and" => |pair| return pair.left.evaluate(b, target, optimize) and pair.right.evaluate(b, target, optimize),
            .@"or" => |pair| return pair.left.evaluate(b, target, optimize) or pair.right.evaluate(b, target, optimize),
            .negate => |inner| return !inner.evaluate(b, target, optimize),
        }
    }

    /// Compose with logical AND. Allocates child pointers on `allocator`.
    pub fn andAlso(self: Expr, other: Expr, allocator: std.mem.Allocator) Expr {
        const left = allocator.create(Expr) catch @panic("OOM");
        left.* = self;
        const right = allocator.create(Expr) catch @panic("OOM");
        right.* = other;
        return .{ .@"and" = .{ .left = left, .right = right } };
    }

    /// Compose with logical OR. Allocates child pointers on `allocator`.
    pub fn orElse(self: Expr, other: Expr, allocator: std.mem.Allocator) Expr {
        const left = allocator.create(Expr) catch @panic("OOM");
        left.* = self;
        const right = allocator.create(Expr) catch @panic("OOM");
        right.* = other;
        return .{ .@"or" = .{ .left = left, .right = right } };
    }

    /// Negate. Allocates child pointer on `allocator`.
    pub fn not(self: Expr, allocator: std.mem.Allocator) Expr {
        const inner = allocator.create(Expr) catch @panic("OOM");
        inner.* = self;
        return .{ .negate = inner };
    }
};

test "Expr.literal true" {
    const e = Expr.literal(true);
    try std.testing.expect(e == .always);
    try std.testing.expect(e.always == true);
}

test "Expr.literal false" {
    const e = Expr.literal(false);
    try std.testing.expect(e == .always);
    try std.testing.expect(e.always == false);
}

test "Expr.zigVersion constructs correctly" {
    const e = Expr.zigVersion(.gte, "0.16.0");
    try std.testing.expect(e == .zig_version);
    try std.testing.expect(e.zig_version.cmp == .gte);
    try std.testing.expect(std.mem.eql(u8, e.zig_version.version, "0.16.0"));
}

test "Expr.targetOs constructs correctly" {
    const e = Expr.targetOs(.linux);
    try std.testing.expect(e == .target_os);
    try std.testing.expect(e.target_os == .linux);
}

test "Expr.targetArch constructs correctly" {
    const e = Expr.targetArch(.x86_64);
    try std.testing.expect(e == .target_arch);
    try std.testing.expect(e.target_arch == .x86_64);
}

test "Expr.optimizeMode constructs correctly" {
    const e = Expr.optimizeMode(.ReleaseFast);
    try std.testing.expect(e == .optimize_mode);
    try std.testing.expect(e.optimize_mode == .ReleaseFast);
}

test "Expr.envVar constructs correctly" {
    const e = Expr.envVar("CI", "true");
    try std.testing.expect(e == .env_var);
    try std.testing.expect(std.mem.eql(u8, e.env_var.key, "CI"));
    try std.testing.expect(std.mem.eql(u8, e.env_var.value, "true"));
}

test "Expr.andAlso constructs correctly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const left = Expr.targetOs(.linux);
    const right = Expr.zigVersion(.gte, "0.16.0");
    const combined = left.andAlso(right, arena.allocator());
    try std.testing.expect(combined == .@"and");
}

test "Expr.orElse constructs correctly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const left = Expr.targetOs(.linux);
    const right = Expr.targetOs(.macos);
    const combined = left.orElse(right, arena.allocator());
    try std.testing.expect(combined == .@"or");
}

test "Expr.not constructs correctly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const inner = Expr.targetOs(.windows);
    const negated = inner.not(arena.allocator());
    try std.testing.expect(negated == .negate);
}
