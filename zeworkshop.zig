const std = @import("std");

pub fn main() !void {
    for (0..128) |i| {
        const index = i + 1;
        std.debug.print("u{},", .{index * 4});
    }
}
