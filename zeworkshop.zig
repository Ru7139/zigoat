const std = @import("std");

pub fn main() !void {
    for (0..16) |i| {
        const index = i + 1;
        std.debug.print("i{},", .{index * 8});
    }
}
