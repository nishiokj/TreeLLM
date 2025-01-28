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
        var method: ?http.Method = null;
        method = http.Method.GET;
        const headers: Request.Headers = .{
            .authorization = .{ .override = "" },
            .content_type = .{ .override = "application/json" },
        };
        const fetch = .{
            .method = method,
            .location = .{ .url = "https://api.deepseek.com/chat/completions" },
            .headers = headers,
        };

        var req = try self.client.fetch(fetch);

        const json_input = try std.fmt.allocPrint(self.allocator, "{{\"prompt\":\"{s}\"}}", .{input});
        defer self.allocator.free(json_input);

        try req.transferEncoding(.chunked);
        try req.writeAll(json_input);

        try req.finish();
        try req.wait();

        const response = try req.reader().readAllAlloc(self.allocator, std.math.maxInt(usize));
        defer self.allocator.free(response);

        return response;
    }
};
