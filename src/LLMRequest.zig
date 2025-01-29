const std = @import("std");
const http = std.http;
const Headers = std.http.Header;
const Allocator = std.mem.Allocator;
const FetchOptions = std.http.Client.FetchOptions;
const Request = std.http.Client.Request;
const Value = std.http.Client.Request;
const RequestTransfer = std.http.Client.RequestTransfer;
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
            .authorization = .{ .override = "Bearer [sk-36aee1a8c0024]" },
            .content_type = .{ .override = "application/json" },
        };

        var server_buffer: [512]u8 = undefined;
        const buffer_slice: []u8 = &server_buffer;
        var response_buffer: [1024]u8 = undefined;
        const response_slice: []u8 = &response_buffer;
        const write: []const u8 = input;
        var request_result = self.client.open(method, .{
            .scheme = "https",
            .host = .{ .raw = "api.deepseek.com" },
            .path = .{ .raw = "/chat/completions" },
        }, .{ .server_header_buffer = buffer_slice, .headers = headers, .keep_alive = false });
        if (request_result) |*request| {
            request.transfer_encoding = RequestTransfer.content_length;
            try request.send();
            try request.writeAll(write);
            try request.finish();
            try request.wait();
            const length = try request.readAll(response_slice);

            std.debug.print("{d}", .{length});

            for (response_buffer) |item| {
                std.debug.print("{c}", .{item});
            }
        } else |err| {
            std.debug.print("Failed to open request: {}\n", .{err});
            return err;
        }
        const resp: []const u8 = "hello";
        return resp;
    }
};
