const std = @import("std");

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();
    // // const alloc = gpa.allocator();

    // const address = try std.net.Address.resolveIp("127.0.0.1", 65533);
    // var stream = try std.net.tcpConnectToAddress(address);
    // defer stream.close();

    // const request =
    //     \\GET /get HTTP/1.1
    //     \\Host: httpbin.org
    //     \\Connection: close
    //     \\
    // ;

    // try stream.writeAll(request);

    // var buffer: [4096]u8 = undefined;
    // var body = std.ArrayList(u8).initBuffer(buffer);
    // defer body.deinit(gpa);

    // while (true) {
    //     const bytes_read = stream.read(&buffer) catch break;
    //     if (bytes_read == 0) break;
    //     try body.appendSlice(buffer[0..bytes_read]);
    // }

    // std.debug.print("{s}\n", .{body.items});

    // Create a general purpose allocator
    //
    //
    // devide
    //
    //
    //
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();

    // // Create a HTTP client
    // var client = std.http.Client{ .allocator = gpa.allocator() };
    // defer client.deinit();

    // // Allocate a buffer for server headers
    // var buf: [4096]u8 = undefined;

    // // Start the HTTP request
    // const uri = try std.Uri.parse("https://www.google.com?q=zig");
    // var req = try client.open(.GET, uri, .{ .server_header_buffer = &buf });
    // defer req.deinit();

    // // Send the HTTP request headers
    // try req.send();
    // // Finish the body of a request
    // try req.finish();

    // // Waits for a response from the server and parses any headers that are sent
    // try req.wait();

    // std.debug.print("status={d}\n", .{req.response.status});

    // var vec = std.ArrayList(u32).empty;
    // vec.capacity = 100;

    // std.debug.print("{}", .{vec});

    const time_seed: u64 = @as(u64, @intCast(std.time.timestamp())) * 2;

    var xsr_engine = std.Random.Xoshiro256.init(time_seed);
    var vec: [100]f64 = undefined;

    for (vec[0..100]) |*i| {
        const value = @as(f64, @floatFromInt(xsr_engine.next()));
        const base = @as(f64, @floatFromInt(2 << 64 - 1));
        i.* = value / base;
    }
    std.debug.print("{any}", .{vec});
}
