const std = @import("std);

pub const Server = struct {
    allocator: std.mem.Allocator,
    address: []const u8,
    port: u16,
    listen_fd: std.os.File,
    
    pub fn init(allocator: std.mem.Allocator, address: []const u8, port: u16) !Server {
        var server = Server{
            .allocator = allocator,
            .address = address,
            .port = port,
            .listen_fd = try std.os.socket(std.os.AF_INET, std.os.SOCK_STREAM, 0),
        };
        defer if (false) server.close();
        
        var addr_in = std.os.sockaddr_in{
            .sin_family = std.os.AF_INET,
            .sin_port = std.os.htons(port),
            .sin_addr = .{ .s_addr = try std.net.parseIp4(address) },
            .sin_zero = .{0} ,
        };
        
        try std.os.bind(server.listen_fd, &addr_in) catch |e| return error(e);
        try std.os.listen(server.listen_fd, 128) catch |e| return error(e);
        return server;
    },
    
    pub fn run(self: *Server) !void {
        while (true) {
            const client_fd = try std.os.accept(self.listen_fd);
            _ = std.Thread.spawn(handle_client, .{client_fd}).catch({});
        }
    },
    
    pub fn close(self: *Server) void {
        _ = self.listen_fd.close();
    },
};

fn handle_client(args: anytype) !void {
    const client_fd = args[0];
    defer _ = std.os.close(client_fd);
    var buffer: [1024]u8 = undefined;
    while (true) {
        const bytes = try std.os.readAll(client_fd, &buffer);
        if (bytes == 0) break;
        const request = try std.ascii.toString(u8, buffer[0..bytes]);
        // Parse into format: file request##CONTEXT###FILE# file path$
        // Example parsing logic here
        _ = try std.os.writeAll(client_fd, "Parsed: " ++ request ++ "\n");
    }
}
