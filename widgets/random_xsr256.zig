const std = @import("std");

const n_error = error{ ZeroArrayLength, ToDo, ShouldNotHappen, TypeNotSupport };

pub fn xsr256_with_time_seed() std.Random.Xoshiro256 {
    const time_seed: u64 = @abs(std.time.timestamp()) *| 2; // @abs(i64) -> u64
    const xsr256 = std.Random.Xoshiro256.init(time_seed);
    return xsr256;
}

pub fn generate_std_int_array(comptime T: type, allocator: std.mem.Allocator, array_len: usize, xsr: *std.Random.Xoshiro256) ![]T {
    if (@typeInfo(T) != .int) return error.TypeNotSupport;
    if (array_len == 0) return error.ZeroArrayLength;

    var arr: []T = try allocator.alloc(T, array_len); // 申请内存

    const type_bits = @typeInfo(T).int.bits;

    if (@typeName(T)[0] == 'u') {
        if (type_bits == 64) {
            for (arr[0..array_len]) |*val| val.* = xsr.next();
        } else if (type_bits < 64) {
            var i: usize = 0;
            while (i < array_len) {
                const num = xsr.next();
                const trunc_times = @as(usize, @divTrunc(64, type_bits));
                inline for (0..trunc_times) |j| {
                    if (i >= array_len) break;
                    arr[i] = @truncate(num >> (j * type_bits));
                    i = i + 1;
                }
            }
        }
    } else if (@typeName(T)[0] == 'i') {
        const random_machine = xsr.random();
        for (arr[0..array_len]) |*val| val.* = random_machine.int(T);
    } else {
        unreachable;
    }

    return arr;
}

test "xsr256_test" {
    var xsr = xsr256_with_time_seed();

    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const type_arr = [_]type{ u8, u16, u24, u32, u40, u48, u56, u64, u72, u80, u88, u96, u104, u112, u120, u128, i8, i16, i24, i32, i40, i48, i56, i64, i72, i80, i88, i96, i104, i112, i120, i128 };

    inline for (0..20) |_| {
        const time = std.time.milliTimestamp();

        inline for (type_arr) |T| {
            const arr = try generate_std_int_array(T, allocator, 1_000_000, &xsr);
            defer allocator.free(arr);
        }

        std.debug.print("xsr256_test ---> Success ---> {}ms\n", .{std.time.milliTimestamp() - time});
    }
}
