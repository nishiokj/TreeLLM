const std = @import("std");
const http = std.http;
const Allocator = std.mem.Allocator;
const Request = std.http.Client.Request;
const Value = std.http.Client.Request;
const RequestTransfer = std.http.Client.RequestTransfer;
const Serializer = @import("Serializer.zig").Serializer;

const Types = @import("Types.zig");
const OpenAIError = error{
    BAD_REQUEST,
    UNAUTHORIZED,
    FORBIDDEN,
    NOT_FOUND,
    TOO_MANY_REQUESTS,
    INTERNAL_SERVER_ERROR,
    SERVICE_UNAVAILABLE,
    GATEWAY_TIMEOUT,
    UNKNOWN,
};

fn getError(status: std.http.Status) OpenAIError {
    const result = switch (status) {
        .bad_request => OpenAIError.BAD_REQUEST,
        .unauthorized => OpenAIError.UNAUTHORIZED,
        .forbidden => OpenAIError.FORBIDDEN,
        .not_found => OpenAIError.NOT_FOUND,
        .too_many_requests => OpenAIError.TOO_MANY_REQUESTS,
        .internal_server_error => OpenAIError.INTERNAL_SERVER_ERROR,
        .service_unavailable => OpenAIError.SERVICE_UNAVAILABLE,
        .gateway_timeout => OpenAIError.GATEWAY_TIMEOUT,
        else => OpenAIError.UNKNOWN,
    };
    return result;
}

pub const ChatClient = struct {

    // A generic allocator provided by the caller.
    allocator: Allocator,
    // An arena allocator used for internal buffer allocations.
    arena: *std.heap.ArenaAllocator,
    // The HTTP client that abstracts the TCP/TLS connection.
    headers: Request.Headers,
    /// Initializes a ChatClient with a caller-provided generic allocator.
    pub fn init(allocator: Allocator, api_key: []const u8) !ChatClient {
        var arena = try allocator.create(std.heap.ArenaAllocator);
        arena.* = std.heap.ArenaAllocator.init(allocator);
        const headers = try get_headers(arena.allocator(), api_key);

        return ChatClient{ .allocator = arena.allocator(), .arena = arena, .headers = headers };
    }

    /// Clean up resources held by ChatClient.
    pub fn deinit(self: *ChatClient) void {
        const alloc = self.arena.child_allocator;
        self.arena.deinit();
        alloc.destroy(self.arena);
    }

    /// Performs a chat request to OpenAI’s Chat Completion endpoint.
    /// The caller provides the prompt, model, and a system prompt.
    /// This method builds a JSON body (allocated from the single ArenaAllocator),
    /// creates an HTTP POST request using std.http.Client,
    /// writes the JSON payload, and then sends the request.
    pub fn get_headers(allocator: Allocator, api_key: []const u8) !Request.Headers {
        //allocate dynamically sized api key. then assign it to headers and
        const auth = try std.fmt.allocPrint(allocator, "Bearer {s}", .{api_key});
        const headers = Request.Headers{
            .content_type = Request.Headers.Value{ .override = "application/json" },
            .authorization = Request.Headers.Value{
                .override = auth,
            },
        };
        return headers;
    }

    pub fn reasoningChatRequest(
        self: *ChatClient,
        payload: Types.COTCompletionPayload,
    ) !Types.Completion {
        const body = try Serializer.serializeCOT(self.allocator, payload);
        const server_header_buffer: []u8 = try self.allocator.alloc(u8, 8 * 1024 * 4);
        var httpClient = http.Client{ .allocator = self.allocator };
        defer httpClient.deinit();
        const uri = std.Uri.parse("https://api.openai.com/v1/chat/completions") catch unreachable;
        var request = try httpClient.open(.POST, uri, .{ .server_header_buffer = server_header_buffer, .headers = self.headers });
        defer request.deinit();
        request.transfer_encoding = .{ .content_length = body.len };
        try request.send();
        try request.writeAll(body);
        try request.finish();
        try request.wait();
        const status = request.response.status;
        std.debug.print("body of request:{s}", .{request.response.reason});
        if (status == .ok) {
            const response = request.reader().readAllAlloc(self.allocator, 3276800) catch unreachable;
            const parsed = try std.json.parseFromSlice(Types.Completion, self.allocator, response, .{ .ignore_unknown_fields = true });
            return parsed.value;
        }
        return getError(status);
    }

    pub fn chatRequest(
        self: *ChatClient,
        payload: Types.CompletionPayload,
    ) !Types.Completion {
        const body = try std.json.stringifyAlloc(self.allocator, payload, .{ .whitespace = .indent_2 });
        const server_header_buffer: []u8 = try self.allocator.alloc(u8, 8 * 1024 * 4);
        var httpClient = http.Client{ .allocator = self.allocator };
        defer httpClient.deinit();
        const uri = std.Uri.parse("https://api.openai.com/v1/chat/completions") catch unreachable;
        var request = try httpClient.open(.POST, uri, .{ .server_header_buffer = server_header_buffer, .headers = self.headers });
        defer request.deinit();
        request.transfer_encoding = .{ .content_length = body.len };
        try request.send();
        try request.writeAll(body);
        try request.finish();
        try request.wait();
        const status = request.response.status;
        std.debug.print("body of request:{s}", .{request.response.reason});
        if (status == .ok) {
            const response = request.reader().readAllAlloc(self.allocator, 3276800) catch unreachable;
            const parsed = try std.json.parseFromSlice(Types.Completion, self.allocator, response, .{ .ignore_unknown_fields = true });
            return parsed.value;
        }
        return getError(status);
    }
};
