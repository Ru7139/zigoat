const std = @import("std");
// const useful_struct = @import("to_be_used_struct.zig");

const print = std.debug.print;
const assert = std.debug.assert;

test "it was main" {

    // print
    try std.fs.File.stdout().writeAll("Hello");
    print(" {s}\n", .{"World!"});

    // i32 & f32 & value form convert
    const i32_val_example: i32 = 23 + 37;
    const f32_val_example: f32 = @as(f32, i32_val_example) / std.math.pi;
    print("i32: {}, f32: {}\n", .{ i32_val_example, f32_val_example });

    // bool & if
    const and_process: bool = true and false;
    const or_process: bool = true or false;
    if (and_process == or_process) {
        print("Something not right\n", .{});
    } else {
        print("and process, one false is false\n", .{});
        print("or process, one true is true\n", .{});
    }

    // var & optional & assert
    var opt_u8_array: ?[]const u8 = null;
    opt_u8_array = "Hi";
    assert(opt_u8_array != null);

    // anyerror type
    var error_val_example: anyerror!i32 = error.ArgNotFound;
    print("error_val_example.type = {}, val = {!}\n", .{ @TypeOf(error_val_example), error_val_example });
    error_val_example = 2345;
    print("error_val_example.type = {}, val = {!}\n", .{ @TypeOf(error_val_example), error_val_example });

    // matrix
    const vec_3x3_example: [3][3]u8 = .{ .{ 1, 2, 3 }, .{ 1, 2, 3 }, .{ 1, 2, 3 } };
    print("{any}\n", .{vec_3x3_example});

    // struct
    const some_primitives_struct = PrimitiveTypesStruct{
        .void_type = {},
        .bool_type = true,
        .type_type = @TypeOf(std.math.F80.fromFloat(3.14)),
        .int_pointer_sized = std.math.maxInt(i64),
        .unsigned_pointer_sized = std.math.maxInt(u64),
        .float_32_ = std.math.pi,
        .compile_time_float = std.math.pi,
    };
    print("{any}\n\n", .{some_primitives_struct});
}

pub const PrimitiveTypesStruct = struct {
    void_type: void,
    bool_type: bool,
    // anyopaque_type: anyopaque, // for type-erased poninters
    // noreturn_type: noreturn, // break, continue, unreachable
    type_type: type, // type of types
    // error_type: anyerror, // an error code
    // int
    // int_8_: i8,
    // int_16_: i16,
    // int_32_: i32,
    // int_64_: i64,
    // int_128_: i128,
    int_pointer_sized: isize,
    // unsigned_int
    // unsigned_8_: u8,
    // unsigned_16_: u16,
    // unsigned_32_: u32,
    // unsigned_64_: u64,
    // unsigned_128_: u128,
    unsigned_pointer_sized: usize,
    // float
    // float_16_: f16,
    float_32_: f32,
    // float_64_: f64,
    // float_80_: f80, // long double
    // float_128: f128,
    // for ABI compatibility with C
    // the_c_char: c_char,
    // the_c_short: c_short,
    // the_c_ushort: c_ushort,
    // the_c_int: c_int,
    // the_c_uint: c_uint,
    // the_c_long: c_long,
    // the_c_ulong: c_ulong,
    // the_c_longlong: c_longlong,
    // the_c_longdouble: c_longdouble,
    // comptime                 // only allow for comptime-known values
    // compile_time_int: comptime_int,
    compile_time_float: comptime_float,
};
