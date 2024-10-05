const std = @import("std");
const net = std.net;

const usage =
    \\Usage: zlb <port>
    \\
    \\Options:
    \\  -h, --help      Show help information
    \\  -v, --version   Show version information
    \\
    \\Arguments:
    \\  <port>          The port to listen on
;

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);
    if (args.len != 3) {
        std.debug.print("Error: Invalid number of arguments.\n", .{});
        std.c._exit(1);
    }
    const port1 = try std.fmt.parseInt(u16, args[1], 10);
    const port2 = try std.fmt.parseInt(u16, args[2], 10);
    const ports: [2]u16 = .{ port1, port2 };

    var current_index: usize = 0;

    const self_addr = try net.Address.resolveIp("0.0.0.0", 4206);
    var listener = try self_addr.listen(.{ .reuse_address = true });
    std.debug.print("Listening on {}\n", .{self_addr});
    // defer listener.close();

    while (true) {
        const client = try listener.accept();
        defer client.close();

        // Round-robin logic
        const target_port = ports[current_index];
        current_index = (current_index + 1) % 2;

        try forwardRequest(client, target_port);
    }
}

fn forwardRequest(client: *net.Stream, target_port: u16) !void {
    const allocator = std.heap.page_allocator;

    const target_socket = try std.net.StreamSocket.connect("127.0.0.1", target_port, allocator);
    defer target_socket.close();

    var buffer: [1024]u8 = undefined;
    const bytes_read = try client.readAll(&buffer);

    try target_socket.writeAll(buffer[0..bytes_read]);

    const bytes_received = try target_socket.readAll(&buffer);
    try client.writeAll(buffer[0..bytes_received]);
}
