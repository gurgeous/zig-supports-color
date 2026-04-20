/// Simple test main for supports-color
pub fn main(init: std.process.Init) !u8 {
    var buf: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writer(init.io, &buf);
    defer stdout.interface.flush() catch {};

    try supports_color.debug(init.gpa, &stdout.interface, init.io, init.environ_map);
    return 0;
}

const std = @import("std");
const supports_color = @import("supports_color");
