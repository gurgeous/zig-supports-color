/// ANSI color levels
pub const ColorLevel = enum {
    none, // no support for color
    ansi, // basic 16 color palette (often customized)
    ansi256, // standard 256 color palette
    ansi16m, // 16m rgb ("truecolor"), the modern standard
};

/// Infer the terminal color level from env vars.
pub fn onEnv(env: *const std.process.Environ.Map) ColorLevel {
    // NO_COLOR always wins
    const e = Env.init(env);
    if (e.NO_COLOR) return .none;

    // heuristics
    const level = onEnv0(&e);

    // at least use ansi if FORCE_COLOR
    if (e.FORCE_COLOR and level == .none) return .ansi;
    return level;
}

/// Infer the terminal color level for a specific file.
pub fn onFile(io: std.Io, env: *const std.process.Environ.Map, file: std.Io.File) !ColorLevel {
    // NO_COLOR always wins
    const e = Env.init(env);
    if (e.NO_COLOR) return .none;
    // tty? bail if !FORCE_COLOR
    if (!e.FORCE_COLOR and !try file.isTty(io)) return .none;

    // heuristics
    const level = onEnv0(&e);

    // at least use ansi if FORCE_COLOR
    if (e.FORCE_COLOR and level == .none) return .ansi;
    return level;
}

/// Infer the terminal color level for stdout.
pub fn onStdout(io: std.Io, env: *const std.process.Environ.Map) !ColorLevel {
    return onFile(io, env, .stdout());
}

/// Infer the terminal color level for stderr.
pub fn onStderr(io: std.Io, env: *const std.process.Environ.Map) !ColorLevel {
    return onFile(io, env, .stderr());
}

/// Infer the terminal color level for /dev/tty.
pub fn onDevTty(io: std.Io, env: *const std.process.Environ.Map) !ColorLevel {
    const tty = try std.Io.Dir.openFileAbsolute(io, "/dev/tty", .{});
    defer tty.close(io);
    return onFile(io, env, tty);
}

/// Prints a simple debug view.
pub fn debug(alloc: std.mem.Allocator, writer: *std.Io.Writer, io: std.Io, env: *const std.process.Environ.Map) !void {
    var set: std.ArrayListUnmanaged([]const u8) = .empty;
    defer set.deinit(alloc);
    var unset: std.ArrayListUnmanaged([]const u8) = .empty;
    defer unset.deinit(alloc);

    // env
    inline for (std.meta.fields(Env)) |field| {
        const key = field.name;
        const present = if (env.get(key)) |v| v.len > 0 else false;
        if (present) {
            try set.append(alloc, key);
        } else {
            try unset.append(alloc, key);
        }
    }
    if (set.items.len > 0) {
        try writer.print("set\n", .{});
        for (set.items) |key| {
            const value = env.get(key) orelse unreachable;
            try writer.print("${s}={s}\n", .{ key, value });
        }
    }
    if (unset.items.len > 0) {
        if (set.items.len > 0) try writer.print("\n", .{});
        try writer.print("unset\n", .{});
        for (unset.items) |key| {
            try writer.print("${s}=\n", .{key});
        }
    }

    // api
    try writer.print("\nlevels\n", .{});
    try writer.print("onEnv     = {s}\n", .{@tagName(onEnv(env))});
    try writer.print("onStdout  = {s}\n", .{@tagName(try onStdout(io, env))});
    try writer.print("onStderr  = {s}\n", .{@tagName(try onStderr(io, env))});
    if (onDevTty(io, env)) |dev_tty| {
        try writer.print("onDevTty  = {s}\n", .{@tagName(dev_tty)});
    } else |err| {
        try writer.print("onDevTty  = {s}\n", .{@errorName(err)});
    }

    // sample text
    try writer.print("\nsample text\n", .{});
    try writer.print("\x1b[34m{s}\x1b[0m\n", .{"ansi16  fg 34"});
    try writer.print("\x1b[38;5;33m{s}\x1b[0m\n", .{"ansi256 color 5;33"});
    try writer.print("\x1b[38;2;0;120;255m{s}\x1b[0m\n", .{"ansi16m #0078ff"});
}

/// Infer the color level from Env (ignoring NO/FORCE_COLOR)
fn onEnv0(env: *const Env) ColorLevel {
    // lowercase versions of TERM and COLORTERM
    var colorterm: [256]u8 = undefined;
    var term: [256]u8 = undefined;
    const COLORTERM = lower(&colorterm, env.COLORTERM);
    const TERM = lower(&term, env.TERM);

    //
    // CI - certain providers support 16m, otherwise assume 256
    //

    if (env.CI) {
        if (env.CIRCLECI or env.GITHUB_ACTIONS or env.GITEA_ACTIONS) return .ansi16m;
        return .ansi256;
    }

    //
    // TERM-based early exit - missing or dumb, tmux, etc
    //

    if (TERM.len == 0) {
        // Could be Windows, which has supported truecolor for a decade
        if (builtin.os.tag == .windows) return .ansi16m;
        return .none;
    }
    if (std.mem.eql(u8, TERM, "dumb")) return .none;
    if (std.mem.startsWith(u8, TERM, "screen")) return .ansi256;
    if (std.mem.startsWith(u8, TERM, "tmux")) return .ansi256;

    //
    // COLORTERM
    //
    // The most common way for terminals to indicate truecolor support. It
    // disappears when you ssh to another machine, though
    //

    if (std.mem.eql(u8, COLORTERM, "24bit") or
        std.mem.eql(u8, COLORTERM, "true") or
        std.mem.eql(u8, COLORTERM, "truecolor"))
    {
        return .ansi16m;
    }

    //
    // Look for popular terminals in case COLORTERM is missing
    //

    if (contains(TERM, "alacritty") or
        contains(TERM, "contour") or
        contains(TERM, "foot") or
        contains(TERM, "ghostty") or
        contains(TERM, "kitty") or
        contains(TERM, "rio") or
        contains(TERM, "wezterm"))
    {
        return .ansi16m;
    }

    //
    // Fallback to common pattern matching
    // https://invisible-island.net/ncurses/terminfo.src.html
    //

    if (std.mem.endsWith(u8, TERM, "direct")) return .ansi16m;
    if (std.mem.endsWith(u8, TERM, "256")) return .ansi256;
    if (std.mem.endsWith(u8, TERM, "256color")) return .ansi256;

    // anything with TERM is assumed to handle at least ansi
    return .ansi;
}

/// Stores the environment variables used during color detection.
const Env = struct {
    COLORTERM: []const u8,
    FORCE_COLOR: bool,
    NO_COLOR: bool,
    TERM: []const u8,

    // CI
    CI: bool,
    CIRCLECI: bool,
    GITEA_ACTIONS: bool,
    GITHUB_ACTIONS: bool,

    // also see https://no-color.org & https://force-color.org
    // note: no support for legacy CLICOLOR

    /// Returns the environment variables used during color detection.
    fn init(env: *const std.process.Environ.Map) Env {
        return .{
            // strings
            .COLORTERM = env.get("COLORTERM") orelse "",
            .TERM = env.get("TERM") orelse "",
            // truthy
            .CI = truthy(env.get("CI")),
            .CIRCLECI = truthy(env.get("CIRCLECI")),
            .FORCE_COLOR = truthy(env.get("FORCE_COLOR")),
            .GITEA_ACTIONS = truthy(env.get("GITEA_ACTIONS")),
            .GITHUB_ACTIONS = truthy(env.get("GITHUB_ACTIONS")),
            .NO_COLOR = truthy(env.get("NO_COLOR")),
        };
    }

    /// Returns whether an env value is truthy.
    fn truthy(value: ?[]const u8) bool {
        const v = value orelse return false;
        return (std.ascii.eqlIgnoreCase(v, "1") or
            std.ascii.eqlIgnoreCase(v, "on") or
            std.ascii.eqlIgnoreCase(v, "true") or
            std.ascii.eqlIgnoreCase(v, "yes"));
    }
};

//
// helpers
//

/// Returns whether `haystack` contains `needle`.
fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

/// Returns a lowercase copy of `value` written into `buf`.
fn lower(buf: []u8, value: []const u8) []const u8 {
    const len = @min(buf.len, value.len);
    const src = value[0..len];
    const dst = buf[0..len];
    @memcpy(dst, src);
    _ = std.ascii.lowerString(dst, dst);
    return dst;
}

//
// testing
//

test "helpers" {
    try testing.expect(contains("abc", "b"));
    try testing.expect(contains("abc", "abc"));

    try testing.expect(Env.truthy("1"));
    try testing.expect(Env.truthy("TrUe"));
    try testing.expect(Env.truthy("yes"));
    try testing.expect(Env.truthy("ON"));
    try testing.expect(!Env.truthy(null));
    try testing.expect(!Env.truthy(""));
    try testing.expect(!Env.truthy("0"));
    try testing.expect(!Env.truthy("false"));

    var buf: [8]u8 = undefined;
    try testing.expectEqualStrings("abc", lower(&buf, "AbC"));
    try testing.expectEqualStrings("toolong!", lower(&buf, "TOOLONG!"));
    try testing.expectEqualStrings("truncate", lower(&buf, "TRUNCATED"));
}

test "TERM is blank" {
    const exp: ColorLevel = if (builtin.os.tag == .windows) .ansi16m else .none;
    const cases = [_]Case{
        .{ .exp = exp },
        .{ .env = &.{.{ .key = "TERM", .value = "" }}, .exp = exp },
        .{ .env = &.{.{ .key = "COLORTERM", .value = "truecolor" }}, .exp = exp },
    };
    try testCases(&cases);
}

test "TERM" {
    for ([_][2][]const u8{
        // TERM, exp
        .{ "dumb", "none" },
        .{ "dumbish", "ansi" },
        .{ "ghostty", "ansi16m" },
        .{ "my-ansi-term", "ansi" },
        .{ "my-color-term", "ansi" },
        .{ "SCREEN-256COLOR", "ansi256" },
        .{ "screen-256color", "ansi256" },
        .{ "tmux", "ansi256" },
        .{ "vt100", "ansi" },
        .{ "wezterm", "ansi16m" },
        .{ "xterm", "ansi" },
        .{ "xterm-256color", "ansi256" },
        .{ "XTERM-DIRECT", "ansi16m" },
        .{ "xterm-direct", "ansi16m" },
    }) |case| {
        try testCases(&.{.{
            .env = &.{.{ .key = "TERM", .value = case[0] }},
            .exp = try testLevelFromString(case[1]),
        }});
    }
}

test "TERM+COLORTERM" {
    for ([_][3][]const u8{
        // TERM, COLORTERM, exp
        .{ "ghostty", "", "ansi16m" },
        .{ "screen-256color", "truecolor", "ansi256" },
        .{ "tmux-256color", "truecolor", "ansi256" },
        .{ "vt100", "24bit", "ansi16m" },
        .{ "vt100", "true", "ansi16m" },
        .{ "vt100", "TRUECOLOR", "ansi16m" },
        .{ "xterm-256color", "nope", "ansi256" },
        .{ "xterm-256color", "truecolor", "ansi16m" },
    }) |case| {
        try testCases(&.{.{
            .env = &.{ .{ .key = "COLORTERM", .value = case[1] }, .{ .key = "TERM", .value = case[0] } },
            .exp = try testLevelFromString(case[2]),
        }});
    }
}

test "NO/FORCE" {
    const no_term: ColorLevel = if (builtin.os.tag == .windows) .ansi16m else .ansi;
    try testCases(&.{
        .{ .env = &.{ .{ .key = "CI", .value = "1" }, .{ .key = "FORCE_COLOR", .value = "1" } }, .exp = .ansi256 },
        .{ .env = &.{ .{ .key = "NO_COLOR", .value = "" }, .{ .key = "TERM", .value = "direct" } }, .exp = .ansi16m },
        .{ .env = &.{ .{ .key = "NO_COLOR", .value = "1" }, .{ .key = "TERM", .value = "direct" } }, .exp = .none },
        .{ .env = &.{ .{ .key = "NO_COLOR", .value = "1" }, .{ .key = "FORCE_COLOR", .value = "1" } }, .exp = .none },
        .{ .env = &.{ .{ .key = "NO_COLOR", .value = "TrUe" }, .{ .key = "TERM", .value = "direct" } }, .exp = .none },
        .{ .env = &.{ .{ .key = "FORCE_COLOR", .value = "1" }, .{ .key = "TERM", .value = "direct" } }, .exp = .ansi16m },
        .{ .env = &.{.{ .key = "FORCE_COLOR", .value = "ON" }}, .exp = no_term },
        .{ .env = &.{.{ .key = "FORCE_COLOR", .value = "1" }}, .exp = no_term },
    });
}

test "CI" {
    try testCases(&.{
        .{ .env = &.{.{ .key = "CI", .value = "1" }}, .exp = .ansi256 },
        .{ .env = &.{ .{ .key = "CI", .value = "0" }, .{ .key = "GITHUB_ACTIONS", .value = "1" }, .{ .key = "TERM", .value = "xterm" } }, .exp = .ansi },
        .{ .env = &.{ .{ .key = "GITHUB_ACTIONS", .value = "1" }, .{ .key = "TERM", .value = "xterm-256color" } }, .exp = .ansi256 },
        .{ .env = &.{ .{ .key = "CI", .value = "true" }, .{ .key = "GITHUB_ACTIONS", .value = "1" } }, .exp = .ansi16m },
        .{ .env = &.{ .{ .key = "CI", .value = "1" }, .{ .key = "GITEA_ACTIONS", .value = "1" } }, .exp = .ansi16m },
        .{ .env = &.{ .{ .key = "CI", .value = "1" }, .{ .key = "CIRCLECI", .value = "1" } }, .exp = .ansi16m },
    });
}

test "onFile" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const file = try tmp.dir.createFile(testing.io, "out.txt", .{ .read = true });
    defer file.close(testing.io);

    // file - nope
    var env0 = try testEnvMap(&.{});
    defer env0.deinit();
    try testing.expectEqual(.none, try onFile(testing.io, &env0, file));

    // FORCE_COLOR - yup
    const no_term: ColorLevel = if (builtin.os.tag == .windows) .ansi16m else .ansi;
    var env1 = try testEnvMap(&.{.{ .key = "FORCE_COLOR", .value = "1" }});
    defer env1.deinit();
    try testing.expectEqual(no_term, try onFile(testing.io, &env1, file));

    // NO_COLOR - nope
    var env2 = try testEnvMap(&.{
        .{ .key = "NO_COLOR", .value = "1" },
        .{ .key = "FORCE_COLOR", .value = "1" },
    });
    defer env2.deinit();
    try testing.expectEqual(.none, try onFile(testing.io, &env2, file));
}

fn testCases(cases: []const Case) !void {
    for (cases) |case| {
        var env = try testEnvMap(case.env);
        defer env.deinit();
        try testing.expectEqual(case.exp, onEnv(&env));
    }
}

fn testLevelFromString(name: []const u8) !ColorLevel {
    inline for (std.meta.fields(ColorLevel)) |field| {
        if (std.mem.eql(u8, name, field.name)) {
            return @field(ColorLevel, field.name);
        }
    }

    return error.InvalidName;
}

fn testEnvMap(entries: []const Pair) !std.process.Environ.Map {
    var env = std.process.Environ.Map.init(testing.allocator);
    errdefer env.deinit();

    for (entries) |entry| {
        try env.put(entry.key, entry.value);
    }

    return env;
}

const Case = struct { env: []const Pair = &.{}, exp: ColorLevel };
const Pair = struct { key: []const u8, value: []const u8 };

const builtin = @import("builtin");
const std = @import("std");
const testing = std.testing;
