const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var process = std.process.Child.init(&[_][]const u8{ "adb", "-s", "16384", "exec-out", "screencap" }, allocator);

    process.stdout_behavior = .Pipe;
    process.stdout_behavior = .Pipe;

    try process.spawn();

    const stdout = process.stdout.?;
    // const reader = stdout.reader();

    std.debug.print("{}", @sizeOf(stdout));
}
