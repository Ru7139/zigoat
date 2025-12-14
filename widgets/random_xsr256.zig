const std = @import("std");

const n_error = error{ ZeroArrayLenth, ToDo };

pub fn xsr256_with_time_seed() std.Random.Xoshiro256 {
    const time_seed: u64 = @abs(std.time.timestamp()) *| 2; // @abs(i64) -> u64
    const xsr256 = std.Random.Xoshiro256.init(time_seed);
    return xsr256;
}

pub fn generate_random_array(comptime T: type, allocator: std.mem.Allocator, array_len: usize, xsr: *std.Random.Xoshiro256) ![]T {
    if (array_len == 0) return error.ZeroArrayLenth;
    if (T == u64) {
        var arr = try allocator.alloc(u64, array_len);
        for (arr[0..array_len]) |*i| {
            i.* = xsr.next();
        }
        return arr;
    } else if (T == f64) {
        var arr = try allocator.alloc(f64, array_len);
        const base = @as(f64, @floatFromInt(std.math.maxInt(u64)));
        for (arr[0..array_len]) |*i| {
            i.* = @as(f64, @floatFromInt(xsr.next())) / base;
        }
        return arr;
    } else {
        return error.ToDo;
    }
}

test "xsr256_test" {
    var xsr = xsr256_with_time_seed();

    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const arr: []f64 = try generate_random_array(f64, allocator, 100, &xsr);
    defer allocator.free(arr);

    std.debug.print("{any}", .{arr});
}
