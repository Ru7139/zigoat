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
        } else if (type_bits > 64) {
            const random_machine = xsr.random();
            for (arr[0..array_len]) |*val| val.* = random_machine.int(T);
        }
    } else if (@typeName(T)[0] == 'i') {
        const random_machine = xsr.random();
        for (arr[0..array_len]) |*val| val.* = random_machine.int(T);
    } else {
        unreachable;
    }

    return arr;
}

test "xsr256_unsigned_test" {
    var xsr = xsr256_with_time_seed();

    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const odd_arr1 = [16]type{ u1, u3, u5, u7, u9, u11, u13, u15, u17, u19, u21, u23, u25, u27, u29, u31 };
    const odd_arr2 = [16]type{ u33, u35, u37, u39, u41, u43, u45, u47, u49, u51, u53, u55, u57, u59, u61, u63 };
    const odd_arr3 = [16]type{ u65, u67, u69, u71, u73, u75, u77, u79, u81, u83, u85, u87, u89, u91, u93, u95 };
    const odd_arr4 = [16]type{ u97, u99, u101, u103, u105, u107, u109, u111, u113, u115, u117, u119, u121, u123, u125, u127 };

    const even_arr1 = [16]type{ u2, u4, u6, u8, u10, u12, u14, u16, u18, u20, u22, u24, u26, u28, u30, u32 };
    const even_arr2 = [16]type{ u34, u36, u38, u40, u42, u44, u46, u48, u50, u52, u54, u56, u58, u60, u62, u64 };
    const even_arr3 = [16]type{ u66, u68, u70, u72, u74, u76, u78, u80, u82, u84, u86, u88, u90, u92, u94, u96 };
    const even_arr4 = [16]type{ u98, u100, u102, u104, u106, u108, u110, u112, u114, u116, u118, u120, u122, u124, u126, u128 };

    const types_hold_arr = [_]*const [16]type{ &odd_arr1, &odd_arr2, &odd_arr3, &odd_arr4, &even_arr1, &even_arr2, &even_arr3, &even_arr4 };

    inline for (types_hold_arr) |types_arr| {
        inline for (0..3) |_| {
            const time = std.time.milliTimestamp();
            defer std.debug.print("xsr256_unsigned_test ---> Success ---> {}ms\n", .{std.time.milliTimestamp() - time});

            inline for (types_arr) |T| {
                const arr = try generate_std_int_array(T, allocator, 1_000_000, &xsr);
                defer allocator.free(arr);
            }
        }
    }
}
