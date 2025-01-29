const std = @import("std");
const http = std.http;
const Headers = std.http.Header;
const Allocator = std.mem.Allocator;
const FetchOptions = std.http.Client.FetchOptions;
const Request = std.http.Client.Request;
const Value = std.http.Client.Request;
pub const GrokLLM = struct {
    allocator: Allocator,
    client: http.Client,

    pub fn init(allocator: Allocator) !GrokLLM {
        return GrokLLM{
            .allocator = allocator,
            .client = http.Client{ .allocator = allocator },
        };
    }

    pub fn deinit(self: *GrokLLM) void {
        self.client.deinit();
    }

    pub fn call(self: *GrokLLM, input: []const u8) ![]const u8 {
        // Hardcoded API key - replace with your actual key

        const method = http.Method.GET;
        const headers: Request.Headers = .{
            .authorization = .{ .override = "Bearer []" },
            .content_type = .{ .override = "application/json" },
        };

        var server_header_buffer = std.ArrayList(u8).init(self.allocator);
        defer server_header_buffer.deinit();

        var response_body = std.ArrayList(u8).init(self.allocator);
        defer response_body.deinit();
        var request = self.client.open(method, .{
            .scheme = "https",
            .host = .{ .raw = "api.deepseek.com" },
            .path = .{ .raw = "/chat/completions" },
        }, .{ .server_header_buffer = server_header_buffer, .headers = headers });
        try request.send();
        try request.writeAll(input);
        try request.finish();
        try request.wait();
        const length = try request.readAll(&response_body);
        std.debug.print("{d}", .{length});
        for (response_body.items) |item| {
            std.debug.print("{c}", .{item});
        }
        const resp: []const u8 = "hello";
        return resp;
    }
};
