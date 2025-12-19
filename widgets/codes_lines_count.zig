const std = @import("std");

fn walk_zig_files_lines(folder_path: []const u8, allocator: std.mem.Allocator, total: *usize) !void {
    const dir = std.fs.cwd().openDir(folder_path, .{ .access_sub_paths = true, .iterate = true }) catch |err| {
        std.debug.print("can not open dir of [{s}]", .{folder_path});
        return err;
    };

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    // while (try walker.next()) |entry| {
    //     if (entry.kind == .file and std.mem.endsWith(u8, entry.path, ".zig")) {
    //         const file = try dir.openFile(entry.path, .{});
    //         defer file.close();

    //         const contents = try file.readToEndAlloc(allocator, 10 * 1024 * 1024); // 10 MB
    //         defer allocator.free(contents);

    //         var count: usize = 0;
    //         var it = std.mem.splitScalar(u8, contents, '\n');
    //         while (it.next()) |_| {
    //             count += 1;
    //         }

    //         total.* += count;
    //     } else continue;
    // }

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.path, ".zig")) continue;

        const zig_file = dir.openFile(entry.path, .{ .mode = .read_only }) catch |err| {
            std.debug.print("can not open .zig file at {s}", .{entry.path});
            return err;
        };
        defer zig_file.close();

        var line_count: usize = 0;
        defer total.* += line_count;

        // var line_buffer: [1024]u8 = undefined;
        // var buffered_reader = std.Io.fixedBufferStream(&line_buffer);
        // var line_reader = buffered_reader.read(dest: []u8);

        // while (true) {
        //     const line = line_reader.readUntilDelimiter('\n') catch |err| {
        //         if (err == error.EndOfStream) {
        //             line_count += 1;
        //             break;
        //         } else {
        //             std.debug.print("Warning: error reading file '{s}': {}\n", .{ entry.path, err });
        //             break;
        //         }
        //     };

        //     // 成功读到一行（以 \n 结尾）
        //     _ = line; // 我们不关心内容，只计数
        //     line_count += 1;
        // }
    }
}

test "count_zig_files_lines" {
    const timer = std.time.microTimestamp();
    defer std.debug.print("count_zig_files_lines ---> Success ---> {}µs\n", .{std.time.microTimestamp() - timer});

    const allocator = std.heap.page_allocator;

    const folder_path = "../../zigoat/widgets";
    var total_lines: usize = 0;
    try walk_zig_files_lines(folder_path, allocator, &total_lines);

    std.debug.print("Total files lines in {s} ---> {}\n", .{ folder_path, total_lines });
}
