const std = @import("std");

const n_error = error{ ZeroArrayLength, ToDo, ShouldNotHappen, TypeNotSupport };

pub fn xsr256_with_time_seed() std.Random.Xoshiro256 {
    const time_seed: u64 = @abs(std.time.timestamp()) *| 2; // @abs(i64) -> u64
    const xsr256 = std.Random.Xoshiro256.init(time_seed);
    return xsr256;
}

pub fn generate_random_array(comptime T: type, allocator: std.mem.Allocator, array_len: usize, xsr: *std.Random.Xoshiro256) ![]T {
    // 不支持数组长度为0
    if (array_len == 0) return error.ZeroArrayLength;

    // 判断是否为可处理的类型
    var type_indicator = false;
    const pri_type = [_]type{ u64, u32, u16, u8, f64, f32 };
    inline for (pri_type) |type_can_be_handle| {
        if (T == type_can_be_handle) type_indicator = true;
    }

    // 先进行错误处理，如果不支持该类型，则返回error
    if (type_indicator == false) {
        std.debug.print("Type Not Support\n", .{});
        return error.ToDo;
    } else {
        // 如果支持则申请对应的内存空间并赋值
        var arr: []T = try allocator.alloc(T, array_len);
        var i: usize = 0; // array index

        if (T == u64) {
            for (arr[0..array_len]) |*val| val.* = xsr.next();
        } else if (T == u32) {
            while (i < array_len) {
                const xsr_value = xsr.next();

                arr[i] = @truncate(xsr_value);
                i += 1;

                if (i < array_len) arr[i] = @truncate(xsr_value >> 32);
                i += 1;
            }
        } else if (T == u16) {
            while (i < array_len) {
                const xsr_value = xsr.next();
                inline for (0..4) |j| {
                    if (i >= array_len) break;
                    arr[i] = @truncate(xsr_value >> (j * 16));
                    i += 1;
                }
            }
        } else if (T == u8) {
            while (i < array_len) {
                const xsr_value = xsr.next();
                inline for (0..8) |j| {
                    if (i >= array_len) break;
                    arr[i] = @truncate(xsr_value >> (j * 8));
                    i += 1;
                }
            }
        } else if (T == f64) {
            const base = @as(f64, @floatFromInt(std.math.maxInt(u64)));

            for (arr[0..array_len]) |*val| {
                const value = @as(f64, @floatFromInt(xsr.next()));
                val.* = value / base;
            }
        } else if (T == f32) {
            const base = @as(f32, @floatFromInt(std.math.maxInt(u32)));

            while (i < array_len) {
                const xsr_value = xsr.next();
                const value1: u32 = @truncate(xsr_value);
                const value2: u32 = @truncate(xsr_value >> 32);

                arr[i] = @as(f32, @floatFromInt(value1)) / base;
                i += 1;

                if (i < array_len) {
                    arr[i] = @as(f32, @floatFromInt(value2)) / base;
                    i += 1;
                }
            }
        } else unreachable;

        // 内存占用方面
        // 1 百万个实体(粒子，NPC，着色器线程)
        // xoshiro128 节省 16 MB 内存

        // 精度只能达到1/2^64或1/2^32的精度
        // 更高的精度，可以使用std.Random.float(r: Random, comptime T: type) T
        return arr;
    }
}

pub fn generate_std_int_array(comptime T: type, allocator: std.mem.Allocator, array_len: usize, xsr: *std.Random.Xoshiro256) ![]T {
    if (@typeInfo(T) != .int) return error.TypeNotSupport;
    if (array_len == 0) return error.ZeroArrayLength;

    // const type_bits = @typeInfo(T).int.bits;
    var arr: []T = try allocator.alloc(T, array_len);
    var i: usize = 0;

    if (T == u64) {
        for (arr[0..array_len]) |*val| val.* = xsr.next();
    } else if (T == u32) {
        while (i < array_len) {
            const xsr_value = xsr.next();

            arr[i] = @truncate(xsr_value);
            i += 1;

            if (i < array_len) arr[i] = @truncate(xsr_value >> 32);
            i += 1;
        }
    } else if (T == u16) {
        while (i < array_len) {
            const xsr_value = xsr.next();
            inline for (0..4) |j| {
                if (i >= array_len) break;
                arr[i] = @truncate(xsr_value >> (j * 16));
                i += 1;
            }
        }
    } else if (T == u8) {
        while (i < array_len) {
            const xsr_value = xsr.next();
            inline for (0..8) |j| {
                if (i >= array_len) break;
                arr[i] = @truncate(xsr_value >> (j * 8));
                i += 1;
            }
        }
    } else {
        const random_machine = xsr.random();

        for (arr[0..array_len]) |*val| {
            val.* = random_machine.int(T);
        }
    }

    return arr;
}

// test "xsr256_test1" {
//     var xsr = xsr256_with_time_seed();

//     var gpa = std.heap.DebugAllocator(.{}){};
//     defer _ = gpa.deinit();
//     const allocator = gpa.allocator();

//     // const type_arr = [_]type{ u64, u32, u16, u8, f64, f32 };
//     const type_arr = [_]type{ u64, u32, u16, u8 };
//     inline for (0..10) |_| {
//         const time = std.time.nanoTimestamp();

//         inline for (type_arr) |T| {
//             const arr: []T = try generate_random_array(T, allocator, 5000, &xsr);
//             defer allocator.free(arr);
//             // std.debug.print("\ntest of the type: {any}\n", .{T});
//             // for (arr) |i| std.debug.print("{any}\n", .{i});
//         }

//         std.debug.print("xsr256_test1 ---> Success ---> {}ns\n", .{std.time.nanoTimestamp() - time});
//     }
// }

test "xsr256_test2" {
    var xsr = xsr256_with_time_seed();

    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const type_arr = [_]type{ u8, u16, u24, u32, u40, u48, u56, u64, u72, u80, u88, u96, u104, u112, u120, u128, i8, i16, i24, i32, i40, i48, i56, i64, i72, i80, i88, i96, i104, i112, i120, i128 };

    inline for (0..10) |_| {
        const time = std.time.nanoTimestamp();

        inline for (type_arr) |T| {
            const arr = try generate_std_int_array(T, allocator, 5000, &xsr);
            defer allocator.free(arr);
        }

        std.debug.print("xsr256_test2 ---> Success ---> {}ns\n", .{std.time.nanoTimestamp() - time});
    }
}
