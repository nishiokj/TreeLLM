const std = @import("std");

const Allocator = std.mem.Allocator;
const File = std.fs.File;
const Stat = std.fs.File.Stat;
const ChatClient = @import("LLMRequest.zig").ChatClient;
const Types = @import("Types.zig");
pub const Model = enum { OPEN_AI_REASONING, OPEN_AI, GEMINI_FLASH, NONE };
pub const Error = error{
    INVALID_MODEL,
};
pub const FileNode = struct {
    parent: ?*FileNode,
    children: std.ArrayList(*FileNode), // For directories
    path: []const u8, // Full filesystem path
    is_dir: u8,
    content: ?[]u8, // Loaded file content (null = unloaded)
    content_allocator: *std.heap.ArenaAllocator, // Allocator for `content`
    allocator: Allocator,
    pub fn init(
        allocator: Allocator,
        parent: ?*FileNode,
        path: []const u8,
        is_dir: u8,
    ) !*FileNode {
        const self = try allocator.create(FileNode);
        const content_allocator = try allocator.create(std.heap.ArenaAllocator);
        content_allocator.* = std.heap.ArenaAllocator.init(allocator);
        self.* = .{
            .parent = parent,
            .children = std.ArrayList(*FileNode).init(content_allocator.allocator()),
            .path = try content_allocator.allocator().dupe(u8, path), // Owned copy of path
            .content = null,
            .content_allocator = content_allocator,
            .allocator = content_allocator.allocator(),
            .is_dir = is_dir,
        };
        return self;
    }

    pub fn deinit(self: *FileNode) void {
        // Free content if loaded
        if (self.content) |bytes| {
            self.allocator.free(bytes);
        }
        self.children.deinit();
        self.allocator.free(self.path);
        const alloc = self.content_allocator.child_allocator;
        self.content_allocator.deinit();

        alloc.destroy(self.content_allocator);
    }
    pub fn map_model(model: []const u8) Model {
        if (std.mem.eql(u8, model, "gpt-4o")) {
            return Model.OPEN_AI;
        }
        if (std.mem.eql(u8, model, "o1-mini")) {
            return Model.OPEN_AI_REASONING;
        }
        if (std.mem.eql(u8, model, "o3-mini")) {
            return Model.OPEN_AI_REASONING;
        }
        if (std.mem.eq(u8, model, "gemini")) {
            return Model.GEMINI_FLASH;
        }
        return Model.NONE;
    }

    pub fn invoke(self: *FileNode, input: []const u8, model: []const u8, api_key: []const u8) !void {
        var grok = try ChatClient.init(self.allocator);
        const model_type = map_model(model);
        var response: Types.Completion = undefined;
        switch (model_type) {
            Model.OPEN_AI_REASONING => {
                const content = .{ .type = "text", .text = input };
                var content_list = std.ArrayList(Types.Content).init(self.allocator);
                try content_list.append(content);
                const message = .{ .role = "user", .content = &content_list };
                var message_list = std.ArrayList(Types.COTMessage).init(self.allocator);
                try message_list.append(message);
                defer content_list.deinit();
                defer message_list.deinit();
                const payload = Types.COTCompletionPayload{
                    .model = model,
                    .messages = &message_list,
                };
                const uri = "https://api.openai.com/v1/chat/completions";
                response = try grok.reasoningChatRequest(payload, uri, api_key);
            },
            Model.OPEN_AI => {
                const system_message = .{
                    .role = "system",
                    .content = "Write clean, succinct code. Do not respond with words.",
                };
                const user_message = .{
                    .role = "user",
                    .content = input,
                };
                const uri = "https://api.openai.com/v1/chat/completions";
                var messages = [2]Types.Message{ system_message, user_message };
                const payload = Types.CompletionPayload{
                    .model = model,
                    .messages = &messages,
                };
                response = try grok.chatRequest(payload, uri, api_key);
            },
            Model.GEMINI_FLASH => {
                const user_message = .{
                    .role = "user",
                    .content = input,
                };
                var message = [1]Types.Message{user_message};
                const payload = Types.CompletionPayload{
                    .model = model,
                    .messages = &message,
                };
                const uri = "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions";
                response = try grok.chatRequest(payload, uri, api_key);
            },
            Model.NONE => {
                std.debug.print("Not a valid model {s}", .{model});
                return Error.INVALID_MODEL;
            },
        }
        for (response.choices) |choice| {
            std.debug.print("message {s}", .{choice.message.content});
        }
        defer grok.deinit();
    }
    // Inside FileNode:
    pub fn loadContent(self: *FileNode) !void {
        if (self.content != null) return; // Already loaded
        const fs = std.fs.cwd();
        const file = try fs.openFile(self.path, .{});
        defer file.close();

        // Read entire file into memory
        self.content = try file.readToEndAlloc(
            self.allocator,
            std.math.maxInt(usize),
        );
    }

    pub fn unloadContent(self: *FileNode) void {
        if (self.content) |bytes| {
            self.allocator.free(bytes);
            self.content = null;
        }
    }

    pub fn reloadContent(self: *FileNode) !void {
        self.unloadContent();
        try self.loadContent();
    }
};
