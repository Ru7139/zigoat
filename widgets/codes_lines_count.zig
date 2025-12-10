const std = @import("std");

pub fn main() !void {
    const root_path = "../";

    const root_dir = std.fs.cwd().openDir(root_path, .{ .iterate = true }) catch |err| {
        std.debug.print("无法打开目录\n{s}: {any}\n", .{ root_path, err });
        return err;
    };

    var total_lines: usize = 0;
    try walkZigFiles(root_dir, std.heap.page_allocator, &total_lines);

    std.debug.print("Total lines in {s} files: {}\n", .{ root_path, total_lines });
}

fn walkZigFiles(dir: std.fs.Dir, allocator: std.mem.Allocator, total: *usize) !void {
    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.path, ".zig")) {
            const file = try dir.openFile(entry.path, .{});
            defer file.close();

            const contents = try file.readToEndAlloc(allocator, 10 * 1024 * 1024); // 10 MB
            defer allocator.free(contents);

            // Count lines: number of '\n' + 1 (if file not empty and doesn't end with \n)
            // But simpler: split by '\n' and count parts
            var count: usize = 0;
            var it = std.mem.splitScalar(u8, contents, '\n');
            while (it.next()) |_| {
                count += 1;
            }

            total.* += count;
        }
    }
}
