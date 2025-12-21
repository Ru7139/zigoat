const std = @import("std");

fn walk_zig_files_lines(folder_path: []const u8, allocator: std.mem.Allocator, total: *usize) !void {
    const dir = std.fs.cwd().openDir(folder_path, .{ .access_sub_paths = true, .iterate = true }) catch |err| {
        std.debug.print("can not open dir of [{s}]", .{folder_path});
        return err;
    };

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.path, ".zig")) continue;

        const zig_file = try dir.openFile(entry.path, .{ .mode = .read_only });
        defer zig_file.close();

        var lines_count: usize = 0;
        defer total.* += lines_count;

        const contents = try zig_file.readToEndAlloc(allocator, 10 * 1024 * 1024); // 10 MB
        defer allocator.free(contents);

        var it = std.mem.splitScalar(u8, contents, '\n');
        while (it.next()) |_| {
            lines_count += 1;
        }
    }
}

test "count_zig_files_lines" {
    const timer = std.time.microTimestamp();
    defer std.debug.print("count_zig_files_lines ---> Success ---> {}µs\n", .{std.time.microTimestamp() - timer});

    const allocator = std.heap.page_allocator;

    // const folder_path = "../../zigoat/widgets";
    const folder_path = "/Users/chenzhi/Desktop/Zig/zigoat/widgets";

    var total_lines: usize = 0;
    try walk_zig_files_lines(folder_path, allocator, &total_lines);

    std.debug.print("Total files lines in {s} ---> {}\n", .{ folder_path, total_lines });
}
