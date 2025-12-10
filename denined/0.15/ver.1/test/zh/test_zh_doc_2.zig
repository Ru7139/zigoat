const std = @import("std");
const expect = std.testing.expect;
const assert = std.debug.assert;
const print = std.debug.print;
const mem_euqal = std.mem.eql;

fn assert_u8str_eql(str_x: []const u8, str_y: []const u8) void {
    assert(mem_euqal(u8, str_x, str_y));
}

fn display_it_print_ln(x: anytype) void {
    print("{}\n", .{x});
}

test "2.1 type convert" {
    // 当无法安全得从一个类型转换到另一个类型时
    // 比如 i32 -> u32 -> u8
    // 编译器会自动完成转换

    // (comptime_float / comptime_int)
    // is illegal

    var f: f32 = undefined;
    f = 32 / 5; // 6
    assert(std.math.approxEqAbs(f32, (32.0 / 5.0), f + 0.4, 1e-10));

    // 两者在 [5]u8 情况下几乎没区别
    // 差别主要在 是否考虑结尾 0 和 写法上的显式/隐式
    var buf_0: [5]u8 = "hello".*; // 没有0作为结尾
    const ptr_0: [*]u8 = &buf_0;
    ptr_0[0] = 'X';
    assert_u8str_eql("Xello", &buf_0);

    var buf_1: [3]u8 = "yes".*;
    const ptr_1: ?[*]u8 = &buf_1; // Option<T>
    ptr_1.?[0] = 'K';
    assert_u8str_eql("Kes", &buf_1);

    var buf_2: [4]u8 = "ACBD".*;
    const ptr_2: anyerror!?[*]u8 = &buf_2; // Result<Option<T>, E>
    (try ptr_2).?[3] = 'Z';
    assert_u8str_eql("ACBZ", &buf_2);

    // 联合枚举 union(enum) 可自行推断

    var buf_3: i32 = 1234;
    const ptr_3: *[1]i32 = &buf_3; // 先转化为array
    const ptr_3_b: [*]i32 = ptr_3; // 转化到array ptr
    ptr_3_b[0] = 5;
    assert(buf_3 == 5);

    const buf_4_a: i32 = -125;
    const buf_4_b: u32 = @bitCast(buf_4_a);
    assert(buf_4_b == 4294967171);

    const buf_5_a: [4]u8 = .{ 0b0000_0001, 0b0000_0010, 0b0000_0011, 0b0000_0100 };
    var buf_5_b: u32 = undefined;
    const ptr_5_a: *const [4]u8 = &buf_5_a;
    const ptr_5_b: *u32 = @ptrCast(@alignCast(@constCast(ptr_5_a)));
    buf_5_b = ptr_5_b.*;
    assert(buf_5_b == 67305985);
    assert(buf_5_b == 0b0000_0100_0000_0011_0000_0010_0000_0001);

    // 各种显式强制转换
    // @enumFromInt(integer: anytype)
    // @errorCast(value: anytype)
    // @floatCast(value: anytype)
    // @floatFromInt(int: anytype)
    // @intCast(int: anytype)
    // @intfrom____
    // @ptrFromInt(address: usize)
    // @ptrCast(value: anytype)
    // @truncate(integer: anytype)
}

test "2.2 memory management" {
    {
        // DebugAllocator
        // 在debug模式下使用这个分配器
        // 线程安全检查，安全检查，内存泄漏检查等特性，均可以手动配置是否开启
        var gpa = std.heap.DebugAllocator(.{}){};
        const allocator = gpa.allocator();

        defer {
            const deinit_status = gpa.deinit(); // 尝试进行 deinit 操作
            if (deinit_status == .leak) @panic("test fail"); // 检查是否发生内存泄漏
        }

        const bytes = try allocator.alloc(u8, 100); // 申请内存
        defer allocator.free(bytes); // 延后释放内存
    }

    {
        // SmpAllocator 转为ReleaseFast优化的分配器，启用多线程
        // 这个分配器是个单例，使用全局状态，整个过程只应实体化一个
        //
        // 设计思路：
        //
        // 1
        // 每个线程都有独立的freelist，当线程推出时，数据必须可回收。
        // 由于不知道线程合适退出，所以偶尔需要一个线程尝试回收其他线程的资源
        //
        // 2
        // 超过特定大小的内存分配会直接通过memory mapped（内存映射）实现，且不存储分配元数据。
        //
        // 3
        // 每个分配器操作都会通过线程局部变量检查线程标识符，去确定访问全局状态中的哪个元素，并尝试获取其锁。
        // 除非被另一个线程分配了同样的ID，否则，都应该成功
        // 如果发生竞争，线程会移动到下一个线程元数据槽位并重复尝试获取锁的过程
        //
        // 4
        // 通过将线程局部元数据组限制为与CPU数量相同的大小，确保了线程的创建与销毁
        // 他们会循环使用整个空闲列表集合
        //
        const allocator_smpA = std.heap.smp_allocator;
        const bytes_smpA = try allocator_smpA.alloc(u8, 100);
        defer allocator_smpA.free(bytes_smpA);
    }

    {
        // FixedBufferAllocator
        // 固定大小的内存缓冲区，无法扩容
        // 其本身不是线程安全的，但可以使用ThreadSafteAllocator进行包裹
        //

        var buffer: [1000]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buffer);

        const allocator = fba.allocator();
        const memory = try allocator.alloc(u8, 100);
        defer allocator.free(memory);
    }

    {
        // AreanaAllocator
        // 这个分配器的特点是可以多次请求内存，但无需每次使用完时进行free操作
        // 可以用deinit直接一次回收所有粉发出去的内存
        // 如果一个程序是一个命令行程序，或没有特别的循环模式
        // 例如web server或游戏事件循环之类的，推荐使用这个
        //

        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const allocator = gpa.allocator();

        defer {
            const deinit_status = gpa.deinit();
            if (deinit_status == .leak) @panic("test fail");
        }

        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();

        const arena_allocator = arena.allocator();

        _ = try arena_allocator.alloc(u8, 1);
        _ = try arena_allocator.alloc(u8, 10);
        _ = try arena_allocator.alloc(u8, 100);
    }

    {
        // c_allocator 与 C 的完全一样
        // 有一个变体是raw_c_allocator
        // 区别在于c_allowcator可能会调用alloc_aligned，而不是malloc
        const allocator = std.heap.c_allocator;
        const num = try allocator.alloc(u8, 1);
        defer allocator.free(num);
    }

    {
        // page_allocator
        // 最基本的分配器，仅仅支持了不同系统的分页申请调用
        // 每次执行分配时，都会向操作系统申请整个内存页面
        // 单个字节的分配可能会使剩下数千的字节无法使用
        // （现代系统页大小最小为4K，但有些还支持2M和1G的页）
        // 由于涉及系统调用，他的速度很慢，但是好处是线程安全并且无锁
        //

        const allocator = std.heap.page_allocator;
        const memory = try allocator.alloc(u8, 100);
        defer allocator.free(memory);
    }

    {
        // StackFallbackAllocator
        // 会尽可能使用stack上的内存，如果请求的内存超过了可用的栈空间
        // 会回退到事先制定好的分配器，即堆内存
        //

        var stack_alloc = std.heap.stackFallback(256 * @sizeOf(u8), std.heap.page_allocator);

        const stack_allocator = stack_alloc.get();
        const memory = try stack_allocator.alloc(u8, 100);
        defer stack_allocator.free(memory);
    }

    {
        // MemoryPool
        // 内存池--对象池，在预先分配的内存块中
        // 当程序需要创建新的对象时，会从池中取出一个已经分配好的内存块
        // 而不是直接从操作系统中申请
        // 当对象不再需要内存时，内存会返回到池中，而不肆释放回操作系统
        //
        // 通过减少使用系统调用，提高内存分配效率，同时减少内存碎片
        // 缺点是如果内存池设置地过大或过小，可能会导致内存的不足或浪费
        //

        var pool = std.heap.MemoryPool(u32).init(std.heap.page_allocator);
        defer pool.deinit();

        const nums1 = try pool.create();
        const nums2 = try pool.create();
        const nums3 = try pool.create();

        pool.destroy(nums1);

        const nums4 = try pool.create();

        _ = .{ nums2, nums3, nums4 };
    }

    // 可以自己实现Allocator的接口
    // 需要仔细阅读 std/mem.zig
    // 提供allocFn和resizeFn
    // 参考std/heap.zig和std.heap.DebugAllocator
}

test "2.3 comptime" {
    // 可以在函数的声明中使用
    // 例如fn add(comptime T: type, a: T, b:T) T {
    //      return a +| b;
    // }
    // 从而实现泛型函数
    //
    // comptime可以被使用在声明上
    // 任何发生运行时对变量的操作将会在编译时报错
    // 这个值必须在编译时可知
    comptime var i = 1 + 9;
    i = 10 * 2;

    const FUNC = struct {
        fn fibonacci(index: u32) u32 {
            if (index < 2) return index;
            return fibonacci(index - 1) + fibonacci(index - 2);
        }

        fn add_comptime(comptime T: type, comptime a: T, comptime b: T) T {
            return a + b;
        }

        fn List(comptime T: type) type {
            return struct {
                item: []T,
                len: usize,
            };
        }
    };

    // runtime 时再进行测试
    // try expect(FUNC.fibonacci(7) == 13);
    //
    // comptime期提起进行测试
    try comptime expect(FUNC.fibonacci(7) == 13);
    // 在编译器堆栈的嵌套层数最大是 1000，如果超过了这个值
    // 可以使用@setEvalBranchQuota来修改默认的堆栈嵌套

    // 在容器（container）级别（任何函数之外）
    // 所有表达式都是隐式的comptime表达式
    const value_0 = FUNC.add_comptime(u64, 25, 35);
    _ = value_0;

    // 使用comptime来生成数据结构，无需引入额外语法
    var buffer: [10]i32 = undefined;
    var list = FUNC.List(i32){
        .item = &buffer,
        .len = 0,
    };

    buffer = .{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 0 };
    list.len = 10;
    assert(list.item[9] == 0);

    const Node = struct {
        next: ?*@This(),
        name: []const u8,

        fn init(name: []const u8) @This() {
            return @This(){ .next = null, .name = name };
        }
    };

    var node_a = Node.init("Node a");

    const node_b = Node{
        .next = &node_a,
        .name = "Node b",
    };

    assert_u8str_eql(node_b.next.?.name, "Node a");
}

test "2.4 reflection" {
    // @TypeOf()内可以放多个变量，返回他们的公共可用转换类型
    assert(comptime_float == @TypeOf(2, 3.14));

    const FUNC = struct {
        // 无副作用
        fn foo_ptr_value_add_1(comptime T: type, ptr: *T) T {
            ptr.* += 1;
            return ptr.*;
        }

        // 获取Int位数
        fn IntTo_u8_Array(comptime T: type) type {
            const int_info = @typeInfo(T).int;
            const bits = int_info.bits;
            if (bits % 8 != 0) @compileError("bits of the type can not be devide by 8 exactly");
            return [bits / 8]u8;
        }

        // 构建新类型
        fn ExternAlignOne(comptime T: type) type {
            // 获取类型信息，并断言为Struct，将内存布局改为extern
            comptime var struct_info = @typeInfo(T).@"struct";
            struct_info.layout = .@"extern";

            // 复制字段信息，修改每个字段对齐为1，替换字段定义
            comptime var new_fields = struct_info.fields[0..struct_info.fields.len].*;
            inline for (&new_fields) |*f| f.alignment = 1;
            struct_info.fields = &new_fields;

            // 重新构造类型
            return @Type(.{ .@"struct" = struct_info });
        }

        // just a true bool
        fn plus_lower_multiply(a: u8, b: u8, c: u8) bool {
            return ((a + b + c) < (a * b * c));
        }
    };

    var data: u32 = 0;
    const type_0 = @TypeOf(FUNC.foo_ptr_value_add_1(u32, &data));
    try comptime expect(type_0 == u32);
    try expect(data == 0); // 在这里虽然检测了类型，但并不会执行@TypeOf()内的值
    // 开发调试 → assert，失败就立即崩溃。
    // 写测试 → expect，失败让测试框架报告。
    //

    const s_0 = struct {
        const s_s_0 = struct {
            a: u8,
            b: u8,
        };
    };
    const msg_0 = "test_zh_doc_2.test.2.4 reflection.s_0.s_s_0";
    assert_u8str_eql(@typeName(s_0.s_s_0), msg_0);

    const type_info_0 = @typeInfo(s_0.s_s_0);
    // 在这里需要使用inline，因为结构体的字段类型中的一个字段是comptime
    // 使得std.builtin.Type.StructField没有运行时大小
    // 从而不能在runtime时遍历数组，必须使用inline for在编译器计算
    inline for (type_info_0.@"struct".fields) |field| {
        assert(mem_euqal(u8, field.name, "a") or mem_euqal(u8, field.name, "b"));
        assert(field.type == u8);
    }

    // 使用反射从类型转换为其他数组
    const ITu8A = FUNC.IntTo_u8_Array;
    try std.testing.expectEqual([1]u8, ITu8A(u8));
    try std.testing.expectEqual([2]u8, ITu8A(u16));
    try std.testing.expectEqual([3]u8, ITu8A(u24));
    try std.testing.expectEqual([4]u8, ITu8A(u32));

    // 改变内存对齐
    const MyStruct = struct {
        a: u32,
        b: u32,
    };

    const NewType = FUNC.ExternAlignOne(MyStruct);
    try std.testing.expectEqual(4, @alignOf(MyStruct));
    try std.testing.expectEqual(1, @alignOf(NewType));

    // @hasDecl 在编译期计算
    const Rocket = struct {
        index: u16,

        pub const target_code = "New York";
        var hit_count: u32 = 0;
        // to modify this variable at runtime
        // it must be given an explicit fixed-size number type
    };

    assert(@hasDecl(Rocket, "target_code"));
    assert(@hasDecl(Rocket, "hit_count"));

    // @hasField
    assert(@hasField(Rocket, "index"));

    // @field
    assert(@field(Rocket, "hit_count") == 0);

    // @fieldParentPtr
    var R1 = Rocket{ .index = 16 };
    // 通过结构体中的某个字段的指针或取结构体的基指针
    assert(&R1 == @as(*Rocket, @fieldParentPtr("index", &R1.index)));

    // @call 调用一个函数，和直接用相同
    assert(@call(.auto, FUNC.plus_lower_multiply, .{ 2, 3, 4 }));

    const type_new_1 = @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &.{
                .{
                    .alignment = 8,
                    .name = "b",
                    .type = u64,
                    .is_comptime = false,
                    .default_value_ptr = null,
                },
                .{
                    .alignment = 8,
                    .name = "fc",
                    .type = f64,
                    .is_comptime = false,
                    .default_value_ptr = null,
                },
            },
            .decls = &.{},
            .is_tuple = false,
        },
    });

    const type_tried = type_new_1{
        .b = 10,
        .fc = 3.1415926,
    };
    assert(type_tried.b == 10);
}

test "2.5 asynchronous" {}

test "2.6 assmbly" {
    const number = 1;
    const arg1 = 2;
    const arg2 = 3;
    const arg3 = 4;

    const asm_value: usize = asm volatile (
        \\ add x0, x0, x1   // x0 = x0 + x1
        \\ add x0, x0, x2   // x0 = x0 + x2
        \\ add x0, x0, x3   // x0 = x0 + x3
        : [ret] "={x0}" (-> usize),
        : [number] "{x0}" (number),
          [arg1] "{x1}" (arg1),
          [arg2] "{x2}" (arg2),
          [arg3] "{x3}" (arg3),
        : .{ .x0 = true, .x9 = true });

    assert(asm_value == number + arg1 + arg2 + arg3);
}

test "2.7 atomic operation" {
    // 用于某个类型指针进行原子化的读取值
    // @atomicLoad(comptime T: type, ptr: *const T, comptime ordering: AtomicOrder)

    // 用于原子化的修改值并返回修改前的值
    // @atomicRmw(comptime T: type, ptr: *T, comptime op: AtomicRmwOp, operand: T, comptime ordering: AtomicOrder)

    // 用于对某个类型指针进行原子化的赋值
    // @atomicStore(comptime T: type, ptr: *T, value: T, comptime ordering: AtomicOrder)

    // 原子比较与交换操作，如果目标指针式给定值，赋值参数的新值，并返回null，否则仅返回读取值
    // @cmpxchgWeak(comptime T: type, ptr: *T, expected_value: T, new_value: T, success_order: AtomicOrder, fail_order: AtomicOrder)
    // @cmpxchgStrong(comptime T: type, ptr: *T, expected_value: T, new_value: T, success_order: AtomicOrder, fail_order: AtomicOrder)

    const RefCount = struct {
        count: std.atomic.Value(usize),
        dropFn: *const fn (*RefCount) void,

        const RefCount = @This();

        fn ref(rc: *RefCount) void {
            _ = rc.count.fetchAdd(1, .monotonic);
        }

        fn unref(rc: *RefCount) void {
            if (rc.count.fetchSub(1, .release) == 1) {
                _ = rc.count.load(.acquire);
                (rc.dropFn)(rc);
            }
        }

        fn noop(rc: *RefCount) void {
            _ = rc;
        }
    };

    var ref_count: RefCount = .{
        .count = std.atomic.Value(usize).init(4),
        .dropFn = RefCount.noop,
    };

    ref_count.ref();
    ref_count.unref();

    // Signals to the processor that the caller is inside a busy-wait spin-loop.
    // std.atomic.spinLoopHint();
}

test "2.8 ffi interactive with c language" {
    // zig的C交互并不是通过FFI或bindings实现
    // zig实现了一套C的编译器并且支持将C代码翻译为zig代码

    // C ABI(Application Binary Interface应用二进制接口)
    // c_char, c_short, c_int, c_long, c_longlong, c_longdouble
    // C的void类型，使用anyopaque(大小未知的类型)

    // C Header
    // 应当仅存在一个@cImport，防止编译器重复调用clang
    const c_func = @cImport({
        @cDefine("_NO_CRT_STDIO_INLINE", "1");
        @cInclude("stdio.h");
    });

    _ = c_func.printf("this msg is from c_func\n");

    // vcpkg C Lib导入
    // 增加include搜索目录
    // exe.addIncludepath(.{.cwd_relative = "PATH:\\PATH\\include"});
    // 链接C的标准库
    // exe.linkLibC();
    // 链接第三方库，gsl库
    // exe.linkSystemLibrary("gsl");

    // C Translation CLI
    // zig提供了一个命令行工具 zig translate-c
    // 可以将C代码翻译为zig的代码并输出
    // -I 制定include文件的搜索目录
    // -D 定义预处理宏
    // -cflags [flags] -- 将任意附加命令行参数传递给clang
    // -target zig的构建目标三元组，缺省则使用本机作为构建目标

    // 翻译错误
    // goto，使用位域(bitfields)的结构体，拼接(token-pasting)宏
    // zig会暂时简单处理一下以继续翻译任务
    //
    // 无法被正确翻译的C的struct和union会翻译为opaque{}
    // 包含opaque类型或者无法被翻译的函数会用extern标记为外部链接函数
    // 当全局变量，函数原型，宏等无法被转换或处理时，zig会使用@compileError

    // C Marco
    // 有些C的宏会在函数中被使用，翻译后可能会使宏失去作用，而函数保留其功能

    // C pointer
    // C的指针可以同时作为单项指针和多项指针使用
    // 所以，饮引入一种新类型[*c]T，
    // 1. 支持zig普通指针(*T和[*]T)的全部语法
    // 2. 可以强制转换为其他的任意指针类型
    // 3. 如果地址为0，在非freestanding(约等于裸机)目标上，会触发未定义行为
    // 4. 支持与整数进行强制转换
    // 5. 支持和整数进行比较
    // 6. 不支持zig的指针特性，例如align对齐，需要先转换为普通指针再进行操作

    // 可变参数的访问，可以使用@cVaStart, @cVaEnd, @cVaArg, @cVaCopy

    // zig提供了一个工具 glibc-abi-tool，收集了每个版本的glibc的。abilist文件的存储库
    // zig携带了40多个libc，但仍能保持50MB以下的大小
}

test "2.9 undefined operation" {
    // unreachable
    // 访问越界
    // 负数转换为无符号整数（可以使用bitcast解决）
    // 数据截断（一个u16的数大于u8最大的值，但还要往里塞的时候，包括浮点数转换为整数）
    // 各种数字相加相减时溢出（使用@addWithOverflow等，还有+%等环绕操作）
    // 左移，右移时出界
    // 除以0
    // 精确除法有余数
    // 尝试解开null，尝试解开union的error
    // 无效错误码 @errorFromInt
    // 无效枚举转换 @enumFromInt
    // 无效错误集合转换 @errorCast
    // 指针对齐错误（例如0x1就不适合4字节对齐）
    // 将允许地址为0的指针转换为地址不可为0的指针时（普通指针不允许）
}
